//
// Thermal Monitor Pro — configuration page
//
// SPDX-License-Identifier: GPL-3.0-or-later
//
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.ksysguard.sensors as Sensors

KCM.SimpleKCM {
    id: root

    property alias cfg_useFahrenheit: useFahrenheitCheck.checked
    property alias cfg_warningTemp: warningTempSpin.value
    property alias cfg_criticalTemp: criticalTempSpin.value
    property alias cfg_updateInterval: updateIntervalSpin.value
    property alias cfg_showSensorPaths: showSensorPathsCheck.checked
    property alias cfg_maxSensors: maxSensorsSpin.value
    property alias cfg_notifyCritical: notifyCriticalCheck.checked
    // Semicolon separated sensor IDs. Empty string = show all discovered.
    property alias cfg_enabledSensors: selectionField.text

    // ksystemstats sensor tree, used to offer the sensors actually present
    Sensors.SensorTreeModel {
        id: sensorTree
    }

    ListModel {
        id: discoveredSensors
    }

    function findTemperatureSensors() {
        var found = []
        function walk(parentIndex, prefix) {
            var rows = parentIndex ? sensorTree.rowCount(parentIndex) : sensorTree.rowCount()
            for (var r = 0; r < rows; r++) {
                var idx = parentIndex
                    ? sensorTree.index(r, 0, parentIndex)
                    : sensorTree.index(r, 0)
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
        return found
    }

    function selectionIds() {
        var out = []
        var raw = selectionField.text
        if (!raw) {
            return out
        }
        var parts = raw.split(";")
        for (var i = 0; i < parts.length; i++) {
            var id = parts[i].trim()
            if (id.length > 0 && out.indexOf(id) === -1) {
                out.push(id)
            }
        }
        return out
    }

    function toggleSensor(sensorId, enabled) {
        var ids = selectionIds()
        var idx = ids.indexOf(sensorId)
        if (enabled && idx === -1) {
            ids.push(sensorId)
        } else if (!enabled && idx !== -1) {
            ids.splice(idx, 1)
        }
        selectionField.text = ids.join(";")
    }

    function isSelected(sensorId) {
        return selectionIds().indexOf(sensorId) !== -1
    }

    function reloadDiscoveredSensors() {
        discoveredSensors.clear()
        var found = findTemperatureSensors()
        for (var i = 0; i < found.length; i++) {
            discoveredSensors.append(found[i])
        }
        sensorListEmpty.text = (found.length === 0)
            ? i18n("No temperature sensors detected. Install lm_sensors and run 'sudo sensors-detect', then relog.")
            : ""
    }

    Component.onCompleted: reloadDiscoveredSensors()

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: useFahrenheitCheck
            Kirigami.FormData.label: i18n("Temperature Unit:")
            text: i18n("Display in Fahrenheit (°F)")
        }

        QQC2.SpinBox {
            id: warningTempSpin
            Kirigami.FormData.label: i18n("Warning Threshold (°C):")
            from: 40
            to: 100
            stepSize: 1
        }

        QQC2.SpinBox {
            id: criticalTempSpin
            Kirigami.FormData.label: i18n("Critical Threshold (°C):")
            from: 50
            to: 115
            stepSize: 1
        }

        QQC2.SpinBox {
            id: updateIntervalSpin
            Kirigami.FormData.label: i18n("Refresh Interval (ms):")
            from: 500
            to: 10000
            stepSize: 500
        }

        QQC2.SpinBox {
            id: maxSensorsSpin
            Kirigami.FormData.label: i18n("Max Sensors (automatic mode):")
            from: 1
            to: 32
            stepSize: 1
        }

        QQC2.CheckBox {
            id: showSensorPathsCheck
            Kirigami.FormData.label: i18n("Details:")
            text: i18n("Show raw sensor IDs")
        }

        QQC2.CheckBox {
            id: notifyCriticalCheck
            Kirigami.FormData.label: i18n("Notifications:")
            text: i18n("Notify when a sensor reaches the critical temperature")
        }
    }

    // Sensor selection — hidden field serializes the choice into the config
    QQC2.TextField {
        id: selectionField
        visible: false
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true

            QQC2.Label {
                text: i18n("Sensors to show")
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            QQC2.Button {
                text: i18n("Reset to automatic")
                icon.name: "edit-undo"
                onClicked: selectionField.text = ""
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.7
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            text: i18n("Tick the sensors to display, in the order shown. "
                + "When nothing is ticked the widget shows every detected sensor "
                + "(up to “Max Sensors”). Changes apply the next time the widget loads.")
        }

        QQC2.Frame {
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            clip: true

            QQC2.ScrollView {
                anchors.fill: parent
                clip: true

                ListView {
                    id: sensorPicker
                    model: discoveredSensors
                    spacing: 2

                    delegate: QQC2.CheckBox {
                        required property string id
                        required property string label

                        text: label
                        checked: root.isSelected(id)
                        onToggled: root.toggleSensor(id, checked)

                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.text: id
                    }
                }
            }
        }

        QQC2.Label {
            id: sensorListEmpty
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.negativeTextColor
            visible: text.length > 0
        }
    }
}
