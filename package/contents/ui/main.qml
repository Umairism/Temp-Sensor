import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors

PlasmoidItem {
    id: root

    property bool useFahrenheit: Plasmoid.configuration.useFahrenheit
    property int warningTemp: Plasmoid.configuration.warningTemp
    property int criticalTemp: Plasmoid.configuration.criticalTemp
    property int updateInterval: Plasmoid.configuration.updateInterval
    property bool showSensorPaths: Plasmoid.configuration.showSensorPaths
    property int maxSensors: Plasmoid.configuration.maxSensors

    // Discovered temperature sensors
    property var sensorList: []
    property real maxObservedTemp: 0

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground

    function formatTemp(celsius) {
        if (isNaN(celsius) || celsius === undefined || celsius === null) return "--"
            if (useFahrenheit) {
                return Math.round((celsius * 9 / 5) + 32) + "°F"
            }
            return Math.round(celsius) + "°C"
    }

    function tempColor(celsius) {
        if (isNaN(celsius)) return Kirigami.Theme.textColor
            if (celsius >= criticalTemp) return Kirigami.Theme.negativeTextColor
                if (celsius >= warningTemp) return Kirigami.Theme.neutralTextColor
                    if (celsius >= 50) return "#3daee9"
                        return Kirigami.Theme.positiveTextColor
    }

    function tempProgress(celsius) {
        if (isNaN(celsius)) return 0
            return Math.max(0, Math.min(1, celsius / 100.0))
    }

    // SensorTreeModel discovers all available ksystemstats sensors
    Sensors.SensorTreeModel {
        id: sensorTree
    }

    // Helper to scan SensorTreeModel for temperature sensors
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
                    var isExcluded = lowerId.indexOf("count") !== -1 ||
                    lowerId.indexOf("freq") !== -1 ||
                    lowerId.indexOf("usage") !== -1 ||
                    lowerName.indexOf("[group]") !== -1
                    var isTemp = lowerId.indexOf("temp") !== -1 ||
                    lowerId.indexOf("tctl") !== -1 ||
                    lowerId.indexOf("tdie") !== -1 ||
                    lowerName.indexOf("°c") !== -1 ||
                    lowerName.indexOf("temp") !== -1
                    if (!isExcluded && isTemp) {
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
        // Prioritize lmsensors/ entries first
        found.sort(function(a, b) {
            var aLm = a.id.indexOf("lmsensors/") === 0 ? 0 : 1
            var bLm = b.id.indexOf("lmsensors/") === 0 ? 0 : 1
            return aLm - bLm
        })
        if (found.length > maxSensors) {
            found = found.slice(0, maxSensors)
        }
        sensorList = found
    }

    Timer {
        id: discoveryTimer
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            scanSensors()
            if (sensorList.length > 0) {
                interval = 15000 // slow down once discovered
            }
        }
    }

    // Compact representation (for panels / system tray)
    compactRepresentation: MouseArea {
        id: compactMouse
        Layout.minimumWidth: compactRow.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.minimumHeight: Kirigami.Units.iconSizes.small
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

            PlasmaComponents.Label {
                text: formatTemp(root.maxObservedTemp)
                font.bold: true
                color: tempColor(root.maxObservedTemp)
            }
        }
    }

    // Full representation (desktop widget)
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

                PlasmaComponents.Label {
                    text: i18n("Thermal Monitor")
                    font.bold: true
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                }

                PlasmaComponents.Label {
                    text: sensorList.length > 0
                    ? i18np("%1 active sensor", "%1 active sensors", sensorList.length)
                    : i18n("Scanning lm_sensors...")
                    opacity: 0.7
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
            }

            PlasmaComponents.Label {
                text: formatTemp(root.maxObservedTemp)
                font.bold: true
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                color: tempColor(root.maxObservedTemp)
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        // Sensor List
        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: sensorListView
                model: root.sensorList
                spacing: Kirigami.Units.smallSpacing

                delegate: Item {
                    id: sensorDelegate
                    width: sensorListView.width
                    height: sensorCol.implicitHeight + Kirigami.Units.smallSpacing

                    Sensors.Sensor {
                        id: liveSensor
                        sensorId: modelData.id
                        updateRateLimit: root.updateInterval
                        onValueChanged: {
                            var v = Number(value)
                            if (!isNaN(v) && v > root.maxObservedTemp && v < 150) {
                                root.maxObservedTemp = v
                            }
                        }
                    }

                    property real currentTemp: Number(liveSensor.value)

                    ColumnLayout {
                        id: sensorCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true

                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: modelData.label
                                elide: Text.ElideRight
                                font.pointSize: Kirigami.Theme.smallFont.pointSize * 1.05
                            }

                            PlasmaComponents.Label {
                                text: formatTemp(sensorDelegate.currentTemp)
                                font.bold: true
                                color: tempColor(sensorDelegate.currentTemp)
                            }
                        }

                        // Progress bar gauge
                        Rectangle {
                            Layout.fillWidth: true
                            height: 6
                            radius: 3
                            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)

                            Rectangle {
                                width: parent.width * tempProgress(sensorDelegate.currentTemp)
                                height: parent.height
                                radius: 3
                                color: tempColor(sensorDelegate.currentTemp)

                                Behavior on width {
                                    NumberAnimation { duration: 300; easing.type: Easing.OutQuad }
                                }
                            }
                        }

                        PlasmaComponents.Label {
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
}
