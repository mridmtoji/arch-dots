pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var monitorStates: ({})

    function updateMonitorState(name, layout, occupied, active, urgent) {
        let newStates = Object.assign({}, root.monitorStates)
        newStates[name] = { "layout": layout, "occupied": occupied, "active": active, "urgent": urgent }
        root.monitorStates = newStates
    }

    function parseLine(line) {
        const parts = line.split(/[,\s]+/).filter(s => s !== "")
        
        // We only care about the summary line: [Monitor] "tags" [Active] [Occupied] [Urgent]
        // Example: "eDP-1 tags 3 2 0"
        if (parts.length === 5 && parts[1] === "tags") {
            const name = parts[0]
            
            // mmsg -t outputs two 'tags' lines: one with integers and one with binary strings.
            // We only want the one with integers (length will be short).
            if (parts[2].length < 9) {
                const active = parseInt(parts[2], 10) || 0
                const occupied = parseInt(parts[3], 10) || 0
                const urgent = parseInt(parts[4], 10) || 0
                
                updateMonitorState(name, "", occupied, active, urgent)
            }
        }
    }

    // --- HELPER FOR SCROLLING ---
    function getActiveIndex(monitorName) {
        const state = monitorStates[monitorName]
        if (!state) return 1
        for (let i = 0; i < 9; i++) {
            if ((state.active & (1 << i)) !== 0) return i + 1
        }
        return 1
    }

    function viewTag(index) {
        if (index < 1) index = 9
        if (index > 9) index = 1
        Quickshell.exec("mmsg", "-t", index.toString())
    }

    // Processes
    Process {
        command: ["mmsg", "-w"]; running: true
        stdout: SplitParser { onRead: (data) => root.parseLine(data) }
    }
    Process {
        command: ["mmsg", "-g", "-t"]; running: true
        stdout: SplitParser { onRead: (data) => root.parseLine(data) }
    }
}
