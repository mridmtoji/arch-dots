import QtQuick
import Quickshell

Rectangle {
    id: root
    
    implicitWidth: clock.width + 20
    implicitHeight: 36
    radius: 10
    color: ColorTheme.surfaceContainerHigh

    Text {
        id: clock
        anchors.centerIn: parent
        
        color: ColorTheme.primary
        font.family: ColorTheme.systemFont
        font.pixelSize: 16
        font.weight: Font.Medium
        
        text: {
            const date = systemClock.date
            Qt.formatDateTime(date, "MMM dd × hh:mm")
        }
        
        SystemClock {
            id: systemClock
            precision: SystemClock.Minutes
        }
    }
}
