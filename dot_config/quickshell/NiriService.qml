pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    
    // Properties
    property string socketPath: Quickshell.env("NIRI_SOCKET") || ""
    property bool connected: false
    
    property var workspaces: []
    property var windows: []
    property int focusedWorkspaceId: -1
    property string focusedWindowId: ""
    property bool overviewActive: false
    
    property var keyboardLayouts: []
    property int currentKeyboardLayoutIndex: 0
    
    // Signals - renamed to avoid conflicts
    signal workspacesUpdated()
    signal windowsUpdated()
    signal workspaceActivated()
    signal windowFocusUpdated()
    
    // Event stream socket (for real-time updates)
    Socket {
        id: eventSocket
        path: root.socketPath
        connected: root.socketPath !== ""
        
        Component.onCompleted: {
            if (connected) {
                console.log("NiriService: Connected to event stream")
                send('"EventStream"')
                requestInitialState()
            }
        }
        
        onConnectedChanged: {
            if (connected) {
                root.connected = true
                console.log("NiriService: Event socket connected")
                send('"EventStream"')
                requestInitialState()
            } else {
                root.connected = false
                console.warn("NiriService: Event socket disconnected")
            }
        }
        
        parser: SplitParser {
            splitMarker: "\n"
            
            onRead: (data) => {
                try {
                    const event = JSON.parse(data)
                    handleNiriEvent(event)
                } catch (e) {
                    console.error("NiriService: Failed to parse event:", e, data)
                }
            }
        }
        
        onError: (error) => {
            console.error("NiriService: Event socket error:", error)
        }
    }
    
    // Command socket (for queries)
    Socket {
        id: commandSocket
        path: root.socketPath
        connected: root.socketPath !== ""
        
        parser: SplitParser {
            splitMarker: "\n"
            
            onRead: (data) => {
                try {
                    const response = JSON.parse(data)
                    handleNiriResponse(response)
                } catch (e) {
                    console.error("NiriService: Failed to parse response:", e, data)
                }
            }
        }
        
        onError: (error) => {
            console.error("NiriService: Command socket error:", error)
        }
    }
    
    // Request initial state
    function requestInitialState() {
        console.log("NiriService: Requesting initial state...")
        sendCommand("Workspaces")
        sendCommand("Windows")
    }
    
    // Send command via command socket
    function sendCommand(command) {
        if (!commandSocket.connected) {
            console.warn("NiriService: Cannot send command - not connected")
            return false
        }
        
        const request = JSON.stringify(command) + "\n"
        commandSocket.write(request)
        return true
    }
    
    // Send via event socket (for actions)
    function send(data) {
        if (!eventSocket.connected) {
            console.warn("NiriService: Cannot send - not connected")
            return false
        }
        
        const request = (typeof data === "string") ? data + "\n" : JSON.stringify(data) + "\n"
        eventSocket.write(request)
        return true
    }
    
    // Handle responses from command socket
    function handleNiriResponse(response) {
        if (response.Ok) {
            const result = response.Ok
            
            // Check if it's workspaces
            if (result.Workspaces) {
                handleWorkspacesData(result.Workspaces)
            }
            // Check if it's windows
            else if (result.Windows) {
                handleWindowsData(result.Windows)
            }
        } else if (response.Err) {
            console.error("NiriService: Error response:", response.Err)
        }
    }
    
    // Handle events from event stream
    function handleNiriEvent(event) {
        const eventType = Object.keys(event)[0]
        
        switch (eventType) {
        case 'WorkspacesChanged':
            handleWorkspacesData(event.WorkspacesChanged.workspaces)
            break
            
        case 'WorkspaceActivated':
            handleWorkspaceActivated(event.WorkspaceActivated)
            break
            
        case 'WindowsChanged':
            handleWindowsData(event.WindowsChanged.windows)
            break
            
        case 'WindowOpenedOrChanged':
            sendCommand("Windows") // Refresh window list
            break
            
        case 'WindowClosed':
            sendCommand("Windows") // Refresh window list
            break
            
        case 'WindowFocusChanged':
            focusedWindowId = event.WindowFocusChanged.id || ""
            windowFocusUpdated()
            break
            
        case 'OverviewOpenedOrClosed':
            overviewActive = event.OverviewOpenedOrClosed.is_open
            break
            
        case 'KeyboardLayoutsChanged':
            keyboardLayouts = event.KeyboardLayoutsChanged.keyboard_layouts.names
            currentKeyboardLayoutIndex = event.KeyboardLayoutsChanged.keyboard_layouts.current_idx
            break
            
        case 'KeyboardLayoutSwitched':
            currentKeyboardLayoutIndex = event.KeyboardLayoutSwitched.idx
            break
        }
    }
    
    // Handle workspaces data
    function handleWorkspacesData(workspacesData) {
        console.log("NiriService: Got", workspacesData.length, "workspaces")
        
        workspaces = workspacesData
        
        // Find focused workspace
        for (let i = 0; i < workspacesData.length; i++) {
            if (workspacesData[i].is_focused) {
                focusedWorkspaceId = workspacesData[i].id
                console.log("NiriService: Focused workspace:", focusedWorkspaceId)
                break
            }
        }
        
        workspacesUpdated()
    }
    
    // Handle workspace activation
    function handleWorkspaceActivated(data) {
        console.log("NiriService: Workspace activated:", data.id)
        focusedWorkspaceId = data.id
        sendCommand("Workspaces") // Refresh to get updated states
        workspaceActivated()
    }
    
    // Handle windows data
    function handleWindowsData(windowsData) {
        console.log("NiriService: Got", windowsData.length, "windows")
        windows = windowsData
        
        // Find focused window
        for (let i = 0; i < windowsData.length; i++) {
            if (windowsData[i].is_focused) {
                focusedWindowId = windowsData[i].id
                break
            }
        }
        
        windowsUpdated()
    }
    
    // Public API - Focus workspace by ID
    function focusWorkspace(workspaceId) {
        console.log("NiriService: Focusing workspace:", workspaceId)
        return send({
            "Action": {
                "FocusWorkspace": {
                    "reference": { "Id": workspaceId }
                }
            }
        })
    }
    
    // Focus workspace by index (1-based)
    function focusWorkspaceByIndex(index) {
        console.log("NiriService: Focusing workspace by index:", index)
        return send({
            "Action": {
                "FocusWorkspace": {
                    "reference": { "Index": index }
                }
            }
        })
    }
    
    // Focus window by ID
    function focusWindow(windowId) {
        console.log("NiriService: Focusing window:", windowId)
        return send({
            "Action": {
                "FocusWindow": {
                    "id": windowId
                }
            }
        })
    }
    
    // Close window by ID
    function closeWindow(windowId) {
        console.log("NiriService: Closing window:", windowId)
        return send({
            "Action": {
                "CloseWindow": {
                    "id": windowId
                }
            }
        })
    }
    
    // Toggle overview
    function toggleOverview() {
        return send({
            "Action": "ToggleOverview"
        })
    }
    
    // Move to workspace up/down
    function moveWorkspaceUp() {
        return send({ "Action": "FocusWorkspaceUp" })
    }
    
    function moveWorkspaceDown() {
        return send({ "Action": "FocusWorkspaceDown" })
    }
    
    // Quit Niri
    function quit() {
        return send({
            "Action": {
                "Quit": {
                    "skip_confirmation": true
                }
            }
        })
    }
    
    // Helper functions
    function getWindowCount(workspaceId) {
        return windows.filter(win => win.workspace_id === workspaceId).length
    }
    
    function isWorkspaceActive(workspaceId) {
        const workspace = workspaces.find(ws => ws.id === workspaceId)
        return workspace ? workspace.is_active : false
    }
    
    function isWorkspaceFocused(workspaceId) {
        return workspaceId === focusedWorkspaceId
    }
    
    function getWorkspacesForOutput(outputName) {
        return workspaces.filter(ws => ws.output === outputName)
    }
    
    function getCurrentKeyboardLayout() {
        if (currentKeyboardLayoutIndex >= 0 && currentKeyboardLayoutIndex < keyboardLayouts.length) {
            return keyboardLayouts[currentKeyboardLayoutIndex]
        }
        return ""
    }
    
    // Initialization
    Component.onCompleted: {
        console.log("NiriService: Initialized")
        console.log("NiriService: Socket path:", socketPath)
        
        if (socketPath === "") {
            console.warn("NiriService: NIRI_SOCKET environment variable not set!")
        }
    }
}
