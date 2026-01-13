import Quickshell
import Quickshell.Io
import QtQuick 

Scope {
    id: root

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: 36
            color: ColorTheme.background

            // --- KEYBIND LISTENER ---
            Process {
                id: ipcListener
                command: ["sh", "-c", "rm -f /tmp/qs_wallpaper_toggle; mkfifo /tmp/qs_wallpaper_toggle; tail -f /tmp/qs_wallpaper_toggle"]
                running: true
                stdout: SplitParser {
                    onRead: {
                        wallPicker.visible = !wallPicker.visible
                        if (wallPicker.visible) wallPicker.forceActiveFocus()
                    }
                }
            }
            // ------------------------
    
            WorkspaceWidget {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
            }

            // --- CENTER CLOCK ---
            Item {
                id: centerContainer
                anchors.centerIn: parent
                height: parent.height
                width: clockWidget.width + 20 

                ClockWidget {
                    id: clockWidget
                    anchors.centerIn: parent
                }

                MouseArea {
                    id: clockHover
                    anchors.fill: parent
                    hoverEnabled: true
                    
                    onEntered: if (!wallPicker.visible) wallPicker.visible = true
                    onClicked: wallPicker.visible = !wallPicker.visible
                }
            }
            
            // --- WALLPAPER PICKER ---
            WallpaperPicker {
                id: wallPicker
                visible: false
                
                // 1. Assign the screen (Required for PanelWindow)
                screen: panel.screen 

                // 2. Calculate Position (Replaces anchor.window/rect)
                // Center the picker relative to the Bar
                popupX: (panel.width / 2) - (width / 2)
                
                // Place it directly below the bar
                popupY: panel.height
            }
            // ------------------------

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 1

                NetworkWidget {
                    anchors.verticalCenter: parent.verticalCenter
                }

                BatteryWidget {
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
