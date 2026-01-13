import QtQuick
import Quickshell
import Quickshell.Services.UPower

Item {
    id: root
    implicitWidth: batteryRect.width
    implicitHeight: batteryRect.height
    width: implicitWidth
    height: implicitHeight

    readonly property bool hasBattery: UPower.displayDevice !== null && UPower.displayDevice !== undefined
    readonly property real batPercentage: UPower.displayDevice ? UPower.displayDevice.percentage : 0
    readonly property bool batCharging: UPower.displayDevice ? UPower.displayDevice.state === UPowerDeviceState.Charging : false

    readonly property var batIcons: [
        "󰁹", "󰂂", "󰂁", "󰂀", "󰁿", "󰁾", 
        "󰁽", "󰁼", "󰁻", "󰁺", "󰂃"
    ]

    readonly property string batIcon: {
        const index = 10 - Math.round(batPercentage * 10)
        return batIcons[Math.min(index, 10)]
    }

    property int chargeIconIndex: 0
    readonly property string chargeIcon: batIcons[10 - chargeIconIndex]

    readonly property color batteryColor: {
        if (batCharging) return ColorTheme.primary
        if (batPercentage < 0.15) return ColorTheme.error  // Critical
        if (batPercentage < 0.30) return ColorTheme.secondary  // Low
        return ColorTheme.primary  // Normal
    }

    visible: hasBattery

    Rectangle {
        id: batteryRect
        width: Math.min(batteryRow.implicitWidth + 16, 120)
        height: 36
        radius: 8
        color: ColorTheme.surfaceContainerHigh
        clip: true

        Row {
            id: batteryRow
            anchors.centerIn: parent
            spacing: 8

            Text {
                color: root.batteryColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                text: batCharging ? chargeIcon : batIcon

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            Text {
                color: root.batteryColor
                font.family: ColorTheme.systemFont
                font.pixelSize: 16
                font.weight: Font.Medium
                text: Math.round(batPercentage * 100) + "%"

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            onEntered: {
                batteryRect.color = ColorTheme.primaryContainer
            }

            onExited: {
                batteryRect.color = ColorTheme.surfaceContainerHigh
            }

            onClicked: {
                console.log("Battery clicked!")
                console.log("Percentage:", Math.round(batPercentage * 100) + "%")
                console.log("State:", batCharging ? "Charging" : "Discharging")
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.InOutQuad
            }
        }
    }

    Timer {
        interval: 600
        repeat: true
        running: batCharging
        onTriggered: {
            chargeIconIndex = (chargeIconIndex + 1) % 10
        }
    }

    Component.onCompleted: {
        console.log("BatteryWidget loaded")
        console.log("Has battery:", hasBattery)
        if (hasBattery) {
            console.log("Battery percentage:", Math.round(batPercentage * 100) + "%")
        }
    }
}
