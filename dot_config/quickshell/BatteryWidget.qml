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
        if (batCharging) return (ColorTheme.primary || "#6200EE")
        if (batPercentage < 0.15) return (ColorTheme.error || "#CF6679")
        if (batPercentage < 0.30) return (ColorTheme.secondary || "#03DAC6")
        return (ColorTheme.primary || "#6200EE")
    }

    visible: hasBattery

    Rectangle {
        id: batteryRect
        width: Math.min(batteryRow.implicitWidth + 16, 120)
        height: 36
        radius: 8
        clip: true
        
        // FIX: Bind color to MouseArea state directly. 
        // This preserves the link to ColorTheme automatically.
        color: batMouseArea.containsMouse 
               ? (ColorTheme.primaryContainer || "#424242") 
               : (ColorTheme.surfaceContainerHigh || "#2C2C2C")

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
                font.family: ColorTheme.systemFont || "monospace"
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
            id: batMouseArea
            anchors.fill: parent
            hoverEnabled: true

            // Removed manual color assignments here to preserve bindings

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

    // REMOVED: The faulty Connections object.
    // The binding on `color` above handles updates automatically.

    Component.onCompleted: {
        console.log("BatteryWidget loaded")
        console.log("Has battery:", hasBattery)
        if (hasBattery) {
            console.log("Battery percentage:", Math.round(batPercentage * 100) + "%")
        }
    }
}
