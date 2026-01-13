import QtQuick
import Quickshell

Row {
    id: root
    spacing: 6
    
    Component.onCompleted: {
        console.log("Workspace widget loaded")
        console.log("Initial workspace count:", NiriService.workspaces.length)
    }
    
    Connections {
        target: NiriService
        
        function onWorkspacesUpdated() {
            console.log("Workspaces updated, count:", NiriService.workspaces.length)
        }
    }
    
    Repeater {
        model: NiriService.workspaces
        
        delegate: Rectangle {
            id: workspaceButton
            width: 40
            height: 32
            radius: 8
            
            property var workspace: modelData
            property bool isActive: workspace.is_active || false
            property bool isFocused: workspace.is_focused || false
            property bool isUrgent: workspace.is_urgent || false
            property int workspaceId: workspace.id || 0
            property int workspaceIdx: workspace.idx || 0
            property string workspaceName: workspace.name || ""
            property int windowCount: NiriService.getWindowCount(workspaceId)
            
            Component.onCompleted: {
                console.log("Created workspace pill:", workspaceIdx, "ID:", workspaceId, "focused:", isFocused)
            }
            
            color: {
                if (isFocused) return ColorTheme.primaryFixed
                if (isUrgent) return ColorTheme.errorContainer
                if (isActive) return ColorTheme.secondaryContainer
                if (windowCount > 0) return ColorTheme.surfaceContainerHigh
                return ColorTheme.surfaceContainer
            }
            
            Behavior on color { 
                ColorAnimation { 
                    duration: 150
                    easing.type: Easing.InOutQuad
                }
            }
            
            scale: isFocused ? 1.05 : 1.0
            
            Behavior on scale {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutBack
                }
            }
            
            Column {
                anchors.centerIn: parent
                spacing: 2
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: workspaceName !== "" ? workspaceName : workspaceIdx
                    
                    // Text color matches the background for readability
                    color: {
                        if (isFocused) return ColorTheme.onPrimary
                        if (isUrgent) return ColorTheme.onErrorContainer
                        if (isActive) return ColorTheme.onSecondaryContainer
                        return ColorTheme.secondary
                    }
                    
                    font.family: ColorTheme.systemFont
                    font.pixelSize: 14
                    font.weight: isFocused ? Font.Bold : Font.Medium
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                    
                    Behavior on font.weight {
                        NumberAnimation { duration: 100 }
                    }
                }
                
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2
                    visible: windowCount > 0
                    
                    Repeater {
                        model: Math.min(windowCount, 5)
                        
                        Rectangle {
                            width: 4
                            height: 4
                            radius: 2
                            
                            // Dot colors that match the text color
                            color: {
                                if (isFocused) return ColorTheme.onPrimaryContainer
                                if (isUrgent) return ColorTheme.onErrorContainer
                                if (isActive) return ColorTheme.onSecondaryContainer
                                return ColorTheme.onSurfaceVariant
                            }
                            
                            opacity: 0.8
                            
                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }
                }
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "+"
                    
                    color: {
                        if (isFocused) return ColorTheme.onPrimaryContainer
                        if (isUrgent) return ColorTheme.onErrorContainer
                        if (isActive) return ColorTheme.onSecondaryContainer
                        return ColorTheme.onSurfaceVariant
                    }
                    
                    font.pixelSize: 8
                    visible: windowCount > 5
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }
            }
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                
                onClicked: {
                    console.log("Switching to workspace:", workspaceIdx, "ID:", workspaceId)
                    NiriService.focusWorkspace(workspaceId)
                }
                
                onEntered: {
                    workspaceButton.opacity = 0.8
                }
                
                onExited: {
                    workspaceButton.opacity = 1.0
                }
            }
            
            Behavior on opacity {
                NumberAnimation {
                    duration: 100
                    easing.type: Easing.InOutQuad
                }
            }
            
            SequentialAnimation {
                running: isUrgent && !isFocused
                loops: Animation.Infinite
                
                NumberAnimation {
                    target: workspaceButton
                    property: "opacity"
                    from: 1.0
                    to: 0.5
                    duration: 600
                    easing.type: Easing.InOutQuad
                }
                
                NumberAnimation {
                    target: workspaceButton
                    property: "opacity"
                    from: 0.5
                    to: 1.0
                    duration: 600
                    easing.type: Easing.InOutQuad
                }
            }
        }
    }
    
    Rectangle {
        width: 60
        height: 32
        radius: 8
        color: ColorTheme.surfaceContainer
        visible: NiriService.workspaces.length === 0
        
        Text {
            anchors.centerIn: parent
            text: "No WS"
            color: ColorTheme.onSurface
            font.pixelSize: 10
        }
    }
}
