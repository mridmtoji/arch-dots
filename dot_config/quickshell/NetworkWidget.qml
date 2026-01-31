import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    implicitWidth: contentRow.implicitWidth + 24
    implicitHeight: 36
    radius: 8
    
    // FIX: Bind color to MouseArea state directly.
    color: netMouseArea.containsMouse 
           ? (ColorTheme.primaryContainer || "#424242") 
           : (ColorTheme.surfaceContainerHigh || "#2C2C2C")

    property string connectionType: "disconnected" 
    property string ssid: ""
    property int signalStrength: 0

    readonly property string icon: {
        if (connectionType === "ethernet") return "󰈀"
        if (connectionType === "disconnected") return "󰤮"
        
        if (signalStrength >= 80) return "󰤨"
        if (signalStrength >= 60) return "󰤥"
        if (signalStrength >= 40) return "󰤢"
        if (signalStrength >= 20) return "󰤟"
        return "󰤯"
    }

    readonly property color statusColor: {
        if (connectionType === "disconnected") return (ColorTheme.error || "#CF6679")
        if (connectionType === "ethernet") return (ColorTheme.tertiaryFixed || "#00BFA5")
        
        if (signalStrength >= 50) return (ColorTheme.primary || "#6200EE")
        if (signalStrength >= 30) return (ColorTheme.secondary || "#03DAC6")
        return (ColorTheme.on_error || "#CF6679")
    }
    
    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: fetchProc.running = true
    }

    Process {
        id: fetchProc
        
        command: ["sh", "-c", `
            if nmcli -t -f TYPE,STATE device | grep -q "ethernet:connected"; then
                echo "ethernet"
                exit
            fi
            
            # Get active wifi info. Format: yes:signal:ssid
            WIFI_INFO=\$(nmcli -t -f ACTIVE,SIGNAL,SSID device wifi | grep "^yes")
            
            if [ -n "\$WIFI_INFO" ]; then
                # Remove the "yes:" prefix using shell expansion
                echo "wifi:\${WIFI_INFO#yes:}"
            else
                echo "disconnected"
            fi
        `]

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (!line) return;

                if (line === "ethernet") {
                    root.connectionType = "ethernet";
                    root.signalStrength = 100;
                    root.ssid = "Wired";
                } else if (line.startsWith("wifi:")) {
                    root.connectionType = "wifi";
                    
                    const parts = line.split(":");
                    if (parts.length >= 3) {
                        root.signalStrength = parseInt(parts[1]) || 0;
                        root.ssid = parts.slice(2).join(":");
                    }
                } else {
                    root.connectionType = "disconnected";
                    root.signalStrength = 0;
                    root.ssid = "";
                }
            }
        }
    }

    // --- UI Layout ---
    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 8

        Text {
            text: root.icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 18
            color: root.statusColor
            anchors.verticalCenter: parent.verticalCenter
            
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    // --- Interaction ---
    MouseArea {
        id: netMouseArea
        anchors.fill: parent
        hoverEnabled: true
        
        onEntered: {
            // Manual color assignment removed to keep binding active
            console.log("Current Network: " + root.ssid)
        }
        
        onClicked: nmtuiOpen.running = true
    }

    Behavior on color { ColorAnimation { duration: 150 } }

    // REMOVED: The faulty Connections object.
    
    Process {
        id: nmtuiOpen
        command: ["foot", "-e", "nmtui"]
    }
}
