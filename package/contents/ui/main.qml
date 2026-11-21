//
// Thermal Monitor Pro — a Plasma 6 plasmoid for live CPU / GPU / NVMe /
// motherboard temperatures, backed by ksystemstats (org.kde.ksysguard.sensors).
//
// SPDX-License-Identifier: GPL-3.0-or-later
//
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    // ------------------------------------------------------------------
    // Configuration (see contents/config/main.xml)
    // ------------------------------------------------------------------
    property bool useFahrenheit: Plasmoid.configuration.useFahrenheit
    property int warningTemp: Plasmoid.configuration.warningTemp
    property int criticalTemp: Plasmoid.configuration.criticalTemp
    property int updateInterval: Plasmoid.configuration.updateInterval
    property bool showSensorPaths: Plasmoid.configuration.showSensorPaths
    property int maxSensors: Plasmoid.configuration.maxSensors
    // Semicolon separated list of sensor IDs to show. Empty = automatic.
    property string enabledSensors: Plasmoid.configuration.enabledSensors
    property bool notifyCritical: Plasmoid.configuration.notifyCritical

    // ------------------------------------------------------------------
    // Runtime state
    // ------------------------------------------------------------------
    // Sensors selected for display: [{ id, label }]. Kept stable between
    // discovery passes (reassigned only when the set actually changes) so
    // the live Sensors objects and their history survive re-scans.
    property var sensorList: []
    // sensorId -> last known temperature in °C
    property var valueMap: ({})
    // sensorId -> true while that sensor is at/above the critical threshold
    property var alertedSensors: ({})
    // Hottest *current* reading across the shown sensors; NaN when unknown
    property real maxObservedTemp: NaN
    // Set once a notification attempt fails (e.g. gdbus missing) so we stop
    // spamming failing commands on every sample.
    property bool notificationsUnavailable: false

    // Use the full dashboard everywhere except in edge panels.
    // (plasmawindowed, useful for testing, reports FormFactor.Application.)
    preferredRepresentation: (Plasmoid.formFactor === PlasmaCore.Types.Horizontal
                              || Plasmoid.formFactor === PlasmaCore.Types.Vertical)
        ? compactRepresentation
        : fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground
    // tooltip properties live directly on PlasmoidItem (not on the Plasmoid
    // attached object) since Plasma 6
    toolTipMainText: i18n("Thermal Monitor Pro")
    toolTipSubText: root.hottestLabel()

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------
    function hottestLabel() {
        return isNaN(root.maxObservedTemp)
            ? i18n("No temperature readings yet")
            : i18n("Hottest sensor: %1", formatTemp(root.maxObservedTemp))
    }

    function formatTemp(celsius) {
        if (celsius === undefined || celsius === null || isNaN(celsius)) {
            return "--"
        }
        if (useFahrenheit) {
            return Math.round(celsius * 9 / 5 + 32) + "°F"
        }
        return Math.round(celsius) + "°C"
    }

    function tempColor(celsius) {
        if (isNaN(celsius)) {
            return Kirigami.Theme.textColor
        }
        if (celsius >= criticalTemp) {
            return Kirigami.Theme.negativeTextColor
        }
        if (celsius >= warningTemp) {
            return Kirigami.Theme.neutralTextColor
        }
        return Kirigami.Theme.positiveTextColor
    }

    function tempProgress(celsius) {
        if (isNaN(celsius)) {
            return 0
        }
        // Gauge fills across the physical 0–100 °C range.
        return Math.max(0, Math.min(1, celsius / 100.0))
    }

    function parseEnabledSensors() {
        var raw = root.enabledSensors
        if (!raw) {
            return []
        }
        var out = []
        var parts = raw.split(";")
        for (var i = 0; i < parts.length; i++) {
            var id = parts[i].trim()
            if (id.length > 0 && out.indexOf(id) === -1) {
                out.push(id)
            }
        }
        return out
    }

    function refreshMaxTemp() {
        var max = NaN
        for (var i = 0; i < sensorList.length; i++) {
            var v = valueMap[sensorList[i].id]
            if (v === undefined || isNaN(v)) {
                continue
            }
            if (isNaN(max) || v > max) {
                max = v
            }
        }
        root.maxObservedTemp = max
    }

    function sendNotification(summary, body) {
        if (root.notificationsUnavailable) {
            return
        }
        // Strip characters that would break shell quoting; gdbus argument
        // values are wrapped in single quotes.
        var clean = function (s) { return String(s).replace(/['"\\$`]/g, "") }
        var cmd = "gdbus call --session"
            + " --dest org.freedesktop.Notifications"
            + " --object-path /org/freedesktop/Notifications"
            + " --method org.freedesktop.Notifications.Notify"
            + " 'Thermal Monitor Pro' 0 'thermometer'"
            + " '" + clean(summary) + "'"
            + " '" + clean(body) + "'"
            + " '[]' '{}' 10000"
        notifySource.connectSource(cmd)
    }

    function maybeNotifyCritical(id, label, celsius) {
        if (!root.notifyCritical || root.notificationsUnavailable) {
            return
        }
        var critical = root.criticalTemp
        var clearAt = critical - 5 // hysteresis: re-arm only after cooling down
        if (celsius >= critical) {
            if (!root.alertedSensors[id]) {
                root.alertedSensors[id] = true
                sendNotification(
                    i18n("%1 is at critical temperature", label),
                    i18n("Sensor reports %1°C (critical threshold: %2°C).",
                         Math.round(celsius), critical))
            }
        } else if (celsius < clearAt) {
            root.alertedSensors[id] = false
        }
    }

    function updateSensorValue(id, rawValue, label) {
        var v = Number(rawValue)
        if (isNaN(v) || v > 150 || v < -50) {
            delete root.valueMap[id]
        } else {
            root.valueMap[id] = v
            maybeNotifyCritical(id, label, v)
        }
        refreshMaxTemp()
    }

    function sensorListEquals(a, b) {
        if (a.length !== b.length) {
            return true
        }
        for (var i = 0; i < a.length; i++) {
            if (a[i].id !== b[i].id) {
                return true
            }
        }
        return false
    }

    // SensorTreeModel exposes the full ksystemstats sensor tree; walk it and
    // keep the leaves that look like temperatures.
    Sensors.SensorTreeModel {
        id: sensorTree
    }

    function scanSensors() {
        var found = []
        function walk(parentIndex, prefix) {
            var rows = parentIndex ? sensorTree.rowCount(parentIndex) : sensorTree.rowCount()
            for (var r = 0; r < rows; r++) {
                var idx = parentIndex ? sensorTree.index(r, 0, parentIndex) : sensorTree.index(r, 0)
                var name = sensorTree.data(idx, Qt.DisplayRole) || ""
                var sensorId = sensorTree.data(idx, Sensors.SensorTreeModel.SensorId) || ""

                if (sensorId && !sensorTree.hasChildren(idx) && (
                    sensorId.indexOf("lmsensors/") === 0 ||
                    sensorId.indexOf("cpu/") === 0 ||
                    sensorId.indexOf("gpu/") === 0 ||
                    sensorId.indexOf("disk/") === 0
                )) {
                    var lowerId = sensorId.toLowerCase()
                    var lowerName = name.toLowerCase()
                    var excluded = lowerId.indexOf("count") !== -1 ||
                        lowerId.indexOf("freq") !== -1 ||
                        lowerId.indexOf("usage") !== -1 ||
                        lowerId.indexOf("percent") !== -1 ||
                        lowerName.indexOf("[group]") !== -1
                    var isTemp = lowerId.indexOf("temp") !== -1 ||
                        lowerId.indexOf("tctl") !== -1 ||
                        lowerId.indexOf("tdie") !== -1 ||
                        lowerName.indexOf("°c") !== -1 ||
                        lowerName.indexOf("temp") !== -1
                    if (!excluded && isTemp) {
                        found.push({
                            id: sensorId,
                            label: prefix ? (prefix + " · " + name) : name
                        })
                    }
                }
                if (sensorTree.hasChildren(idx)) {
                    walk(idx, name)
                }
            }
        }
        walk(null, "")

        // Prefer explicit user selection (in the user's chosen order)…
        var wanted = parseEnabledSensors()
        if (wanted.length > 0) {
            var byId = {}
            for (var i = 0; i < found.length; i++) {
                byId[found[i].id] = found[i]
            }
            var selected = []
            for (var j = 0; j < wanted.length; j++) {
                if (byId[wanted[j]]) {
                    selected.push(byId[wanted[j]])
                }
            }
            found = selected
        } else {
            // …otherwise show all discovered sensors, lmsensors first,
            // capped at maxSensors.
            found.sort(function(a, b) {
                var aLm = a.id.indexOf("lmsensors/") === 0 ? 0 : 1
                var bLm = b.id.indexOf("lmsensors/") === 0 ? 0 : 1
                return aLm - bLm
            })
            if (found.length > root.maxSensors) {
                found = found.slice(0, root.maxSensors)
            }
        }

        // Reassign only on real change so delegates (and their live Sensor
        // objects) are not needlessly recreated on every re-scan.
        if (sensorListEquals(root.sensorList, found)) {
            var keep = {}
            for (var k = 0; k < found.length; k++) {
                keep[found[k].id] = true
            }
            for (var id in root.valueMap) {
                if (!keep[id]) {
                    delete root.valueMap[id]
                }
            }
            for (var alertId in root.alertedSensors) {
                if (!keep[alertId]) {
                    delete root.alertedSensors[alertId]
                }
            }
            root.sensorList = found
            refreshMaxTemp()
        }
    }

    Timer {
        id: discoveryTimer
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.scanSensors()
            if (root.sensorList.length > 0) {
                interval = 15000 // slow down once discovery succeeds
            }
        }
    }

    // Desktop notifications are emitted through the session bus via gdbus
    // (part of GLib, present on virtually all Linux desktops). If gdbus is
    // unavailable the first attempt fails and further attempts are skipped.
    Plasma5Support.DataSource {
        id: notifySource
        engine: "executable"
        onNewData: function(sourceName, data) {
            var code = 0
            if (data["exit code"] !== undefined) {
                code = data["exit code"]
            } else if (data["exitCode"] !== undefined) {
                code = data["exitCode"]
            }
            if (code !== 0 && !root.notificationsUnavailable) {
                root.notificationsUnavailable = true
                console.warn("Thermal Monitor Pro: desktop notification failed"
                    + " (gdbus exit code " + code + ");"
                    + " notifications disabled for this session.")
            }
            disconnectSource(sourceName)
        }
    }

    // ------------------------------------------------------------------
    // Compact representation (panel)
    // ------------------------------------------------------------------
    compactRepresentation: MouseArea {
        id: compactMouse
        Layout.minimumWidth: compactRow.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.minimumHeight: Kirigami.Units.iconSizes.small
        Accessible.name: Plasmoid.toolTipMainText
        Accessible.description: root.hottestLabel()
        onClicked: root.expanded = !root.expanded

        RowLayout {
            id: compactRow
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: "sensors-temperature-symbolic"
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }

            QQC2.Label {
                text: root.formatTemp(root.maxObservedTemp)
                font.bold: true
                color: root.tempColor(root.maxObservedTemp)
            }
        }
    }

    // ------------------------------------------------------------------
    // Full representation (desktop / popup)
    // ------------------------------------------------------------------
    component EmptyState: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        Item { Layout.fillHeight: true }

        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            source: "sensors-temperature-symbolic"
            Layout.preferredWidth: Kirigami.Units.iconSizes.huge
            Layout.preferredHeight: Kirigami.Units.iconSizes.huge
            opacity: 0.4
        }

        QQC2.Label {
            Layout.alignment: Qt.AlignHCenter
            text: i18n("No temperature sensors found")
            font.bold: true
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
        }

        QQC2.Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 18
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            opacity: 0.75
            text: i18n("ksystemstats reports no temperature sensors on this machine. "
                + "Make sure lm_sensors is installed and detects your chips "
                + "(run 'sudo sensors-detect'), then restart your session. "
                + "Some virtual machines and ARM boards expose no thermal sensors at all.")
        }

        Item { Layout.fillHeight: true }
    }

    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 16
        Layout.minimumHeight: Kirigami.Units.gridUnit * 14
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.preferredHeight: Kirigami.Units.gridUnit * 22
        spacing: Kirigami.Units.smallSpacing

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: "sensors-temperature-symbolic"
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                QQC2.Label {
                    text: i18n("Thermal Monitor")
                    font.bold: true
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                }

                QQC2.Label {
                    text: root.sensorList.length > 0
                        ? i18np("%1 active sensor", "%1 active sensors", root.sensorList.length)
                        : i18n("Scanning for sensors…")
                    opacity: 0.7
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
            }

            QQC2.Label {
                text: root.formatTemp(root.maxObservedTemp)
                font.bold: true
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                color: root.tempColor(root.maxObservedTemp)
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        // Body: either the sensor list or an actionable empty state
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            EmptyState {
                anchors.fill: parent
                visible: root.sensorList.length === 0
            }

            QQC2.ScrollView {
                anchors.fill: parent
                visible: root.sensorList.length > 0
                clip: true

                ListView {
                    id: sensorListView
                    model: root.sensorList
                    spacing: Kirigami.Units.smallSpacing

                    delegate: Item {
                        id: sensorDelegate
                        width: sensorListView.width
                        height: sensorCol.implicitHeight + Kirigami.Units.smallSpacing

                        Accessible.name: modelData.label + " " + root.formatTemp(sensorDelegate.currentTemp)

                        Sensors.Sensor {
                            id: liveSensor
                            sensorId: modelData.id
                            updateRateLimit: root.updateInterval
                            onValueChanged: root.updateSensorValue(modelData.id, liveSensor.value, modelData.label)
                        }

                        property real currentTemp: Number(liveSensor.value)

                        ColumnLayout {
                            id: sensorCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: 3

                            RowLayout {
                                Layout.fillWidth: true

                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: modelData.label
                                    elide: Text.ElideRight
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 1.05
                                }

                                QQC2.Label {
                                    text: root.formatTemp(sensorDelegate.currentTemp)
                                    font.bold: true
                                    color: root.tempColor(sensorDelegate.currentTemp)
                                }
                            }

                            // Progress bar gauge
                            Rectangle {
                                Layout.fillWidth: true
                                height: 6
                                radius: 3
                                color: Qt.rgba(Kirigami.Theme.textColor.r,
                                               Kirigami.Theme.textColor.g,
                                               Kirigami.Theme.textColor.b,
                                               0.12)

                                Rectangle {
                                    width: parent.width * root.tempProgress(sensorDelegate.currentTemp)
                                    height: parent.height
                                    radius: 3
                                    color: root.tempColor(sensorDelegate.currentTemp)

                                    Behavior on width {
                                        NumberAnimation { duration: 300; easing.type: Easing.OutQuad }
                                    }
                                }
                            }

                            QQC2.Label {
                                visible: root.showSensorPaths
                                text: modelData.id
                                opacity: 0.5
                                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }

        // Footer: data source attribution
        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Source: ksystemstats (lm_sensors / kcoretemp)")
            opacity: 0.4
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
            horizontalAlignment: Text.AlignRight
        }
    }
}
