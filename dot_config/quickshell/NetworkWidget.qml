import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    implicitWidth: contentRow.implicitWidth + 24
    implicitHeight: 36
    radius: 8
    color: ColorTheme.surfaceContainerHigh || "#2C2C2C"

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
        
        // NOTICE: All '$' signs are escaped with '\' (e.g., \$, \${}) 
        // so QML doesn't try to interpret them.
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
                    // parts[0] is "wifi", parts[1] is signal
                    if (parts.length >= 3) {
                        root.signalStrength = parseInt(parts[1]) || 0;
                        // Join the rest back in case SSID had a colon
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
        anchors.fill: parent
        hoverEnabled: true
        
        onEntered: {
            root.color = ColorTheme.primaryContainer || "#424242"
            console.log("Current Network: " + root.ssid)
        }
        onExited: {
            root.color = ColorTheme.surfaceContainerHigh || "#2C2C2C"
        }
        onClicked: nmtuiOpen.running = true
    }

    Behavior on color { ColorAnimation { duration: 150 } }

    // Force refresh when ColorTheme changes
    Connections {
        target: ColorTheme
        function onChanged() {
            root.color = ColorTheme.surfaceContainerHigh || "#2C2C2C"
        }
    }

    Process {
        id: nmtuiOpen
        command: ["foot", "-e", "nmtui"]
    }
}
