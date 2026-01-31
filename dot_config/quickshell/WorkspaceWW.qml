import QtQuick
import Quickshell

Rectangle {
    id: root
    required property var output
    
    implicitHeight: 34
    implicitWidth: row.width + 12
    radius: 10
    color: ColorTheme.surfaceContainer // Background of the pill container

    property var state: MangoService.monitorStates[output.name] || {active: 0, occupied: 0, urgent: 0}

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: 9
            delegate: Rectangle {
                property int mask: 1 << index
                property bool isActive: (root.state.active & mask) !== 0
                property bool hasWindows: (root.state.occupied & mask) !== 0
                property bool isUrgent: (root.state.urgent & mask) !== 0

                width: isActive ? 32 : (hasWindows ? 12 : 6)
                height: 6
                radius: 3
                anchors.verticalCenter: parent.verticalCenter
                
                // Colors based on your Hyprland logic
                color: {
                    if (isActive) return ColorTheme.primary
                    if (isUrgent) return ColorTheme.error
                    if (hasWindows) return ColorTheme.primaryContainer
                    return ColorTheme.outlineVariant // Truly empty color
                }

                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                Behavior on color { ColorAnimation { duration: 150 } }

                MouseArea {
                    anchors.fill: parent
                    onClicked: MangoService.viewTag(index + 1)
                }
            }
        }
    }

    // Scroll to change workspaces (like your reference code)
    MouseArea {
        anchors.fill: parent
        onWheel: (event) => {
            let current = 1;
            for (let i = 0; i < 9; i++) {
                if (root.state.active & (1 << i)) current = i + 1;
            }
            if (event.angleDelta.y > 0) MangoService.viewTag(current - 1)
            else MangoService.viewTag(current + 1)
        }
    }
}
