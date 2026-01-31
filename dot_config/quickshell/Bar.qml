import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root
    
    property var screen 
    property bool wallPickerVisible: false

    // 1. IPC Listener (The FIFO toggle logic)
    Process {
        id: ipcListener
        command: ["sh", "-c", "rm -f /tmp/qs_wallpaper_toggle; mkfifo /tmp/qs_wallpaper_toggle; tail -f /tmp/qs_wallpaper_toggle"]
        running: true
        stdout: SplitParser {
            onRead: root.wallPickerVisible = !root.wallPickerVisible
        }
    }

    // 2. THE MAIN BAR WINDOW
    PanelWindow {
        id: panel
        screen: root.screen

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: 36
        color: typeof ColorTheme !== 'undefined' ? ColorTheme.background : "#1e1e2e"

        // LEFT: Workspaces
        WorkspaceWW {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            output: root.screen
        }

        // CENTER: Clock (Toggles Picker)
        Item {
            id: clockContainer
            anchors.horizontalCenter: parent.horizontalCenter
            height: parent.height
            width: 100

            ClockWidget {
                id: clockWidget
                anchors.centerIn: parent
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.wallPickerVisible = !root.wallPickerVisible
            }
        }

        // RIGHT: System Info
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            NetworkWidget { } 
            BatteryWidget { }
        }
    }

    // 3. THE FLOATING PICKER WINDOW (Below the clock, centered horizontally)
    WallpaperPicker {
        id: pickerPopup
        output: root.screen
        visible: root.wallPickerVisible
        
        // Position below the bar, centered horizontally
        popupX: (root.screen.width - 600) / 2   // Horizontally centered (600 is the picker width)
        popupY: 20
    }
}
