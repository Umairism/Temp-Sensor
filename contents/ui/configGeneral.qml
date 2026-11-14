import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_useFahrenheit: useFahrenheitCheck.checked
    property alias cfg_warningTemp: warningTempSpin.value
    property alias cfg_criticalTemp: criticalTempSpin.value
    property alias cfg_updateInterval: updateIntervalSpin.value
    property alias cfg_showSensorPaths: showSensorPathsCheck.checked
    property alias cfg_maxSensors: maxSensorsSpin.value

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
            Kirigami.FormData.label: i18n("Max Sensors Displayed:")
            from: 1
            to: 32
            stepSize: 1
        }

        QQC2.CheckBox {
            id: showSensorPathsCheck
            Kirigami.FormData.label: i18n("Details:")
            text: i18n("Show raw sensor IDs")
        }
    }
}
