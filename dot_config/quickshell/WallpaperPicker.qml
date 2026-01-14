import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    // --- 1. LAYOUT & FOCUS CONFIGURATION ---
    
    // Use Overlay layer so it sits above normal windows
    WlrLayershell.layer: WlrLayershell.Layer.Overlay
    
    // Grab EXCLUSIVE focus so Vim keys work immediately
    WlrLayershell.keyboardFocus: WlrLayershell.KeyboardFocus.Exclusive

    // Anchor to Top-Left corner of the screen...
    anchors {
        top: true
        left: true
    }
    
    // ...and use margins to move it to the correct position (passed from Bar.qml)
    margins {
        left: popupX
        top: popupY
    }

    // Coordinates to be set by Bar.qml
    property int popupX: 0
    property int popupY: 0

    // Size
    width: 600
    height: 400
    
    color: "transparent"

    // --- State Management ---
    property string inputMode: "grid" 
    property string overlaySelection: "light"
    
    // Path storage
    property string homeDir: ""
    property string wallpaperDir: ""
    property string cacheDir: ""
    
    // Track known wallpapers for incremental updates
    property var knownPaths: ({})

    // Background
    Rectangle {
        id: bg
        anchors.fill: parent
        color: ColorTheme.background
        opacity: 0.95
        radius: 12
        border.color: ColorTheme.primary
        border.width: 1
        
        MouseArea {
            anchors.fill: parent
            onClicked: root.forceActiveFocus()
        }
    }

    // --- Initialization ---
    ListModel { id: wallpaperModel }

    Process {
        id: homeProc
        command: ["sh", "-c", "echo $HOME"]
        running: true
        stdout: SplitParser {
            onRead: text => {
                const h = text.trim()
                if (h !== "") {
                    root.homeDir = h
                    root.wallpaperDir = h + "/Pictures/Wallpapers"
                    root.cacheDir = h + "/.cache/quickshell_thumbs"
                    setupProc.running = true
                }
            }
        }
    }

    Process {
        id: setupProc
        running: false 
        command: ["mkdir", "-p", root.cacheDir]
        onExited: scanProc.running = true
    }

    Process {
        id: scanProc
        running: false
        command: ["find", root.wallpaperDir, "-type", "f", "(", "-iname", "*.jpg", "-o", "-iname", "*.png", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.webp", "-o", "-iname", "*.mp4", ")"]
        stdout: SplitParser {
            onRead: text => {
                if (text.trim() !== "") {
                    addWallpaper(text.trim())
                }
            }
        }
    }

    // Incremental rescan - only adds new files
    Process {
        id: incrementalScanProc
        running: false
        command: ["find", root.wallpaperDir, "-type", "f", "(", "-iname", "*.jpg", "-o", "-iname", "*.png", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.webp", "-o", "-iname", "*.mp4", ")"]
        
        property var foundPaths: ({})
        property var toRemove: []
        
        onRunningChanged: {
            if (running) {
                foundPaths = {}
                toRemove = []
            } else {
                // Remove deleted files
                for (let i = wallpaperModel.count - 1; i >= 0; i--) {
                    const path = wallpaperModel.get(i).filePath
                    if (!foundPaths[path]) {
                        wallpaperModel.remove(i)
                        delete root.knownPaths[path]
                    }
                }
            }
        }
        
        stdout: SplitParser {
            onRead: text => {
                const path = text.trim()
                if (path !== "") {
                    incrementalScanProc.foundPaths[path] = true
                    // Only add if it's new
                    if (!root.knownPaths[path]) {
                        addWallpaper(path)
                    }
                }
            }
        }
    }

    // Rescan function - uses incremental scan for speed
    function rescanWallpapers() {
        if (root.wallpaperDir !== "" && !incrementalScanProc.running) {
            incrementalScanProc.running = true
        }
    }

    function addWallpaper(path) {
        // Mark as known to avoid duplicates
        root.knownPaths[path] = true
        
        const isVideo = path.endsWith(".mp4");
        let thumb = path;
        
        if (isVideo) {
            const filename = path.split("/").pop();
            thumb = root.cacheDir + "/" + filename + ".png";
            
            const checkCmd = "test -f '" + thumb + "'";
            const genCmd = "ffmpeg -y -i '" + path + "' -vf 'scale=300:-1' -vframes 1 '" + thumb + "'";
            
            Qt.createQmlObject(`
                import Quickshell.Io
                Process {
                    command: ["sh", "-c", "${checkCmd}"]
                    running: true
                    onExited: (code) => {
                        if (code !== 0) {
                            Qt.createQmlObject(\`import Quickshell.Io; Process { command: ["sh", "-c", "${genCmd}"]; running: true }\`, root);
                        }
                    }
                }
            `, root);
        }

        wallpaperModel.append({
            "filePath": path,
            "thumbPath": thumb,
            "isVideo": isVideo
        });
    }

    // --- Apply Actions ---
    Process { id: applyProc }

    function applyVideo(path) {
        const cmd = `pkill mpvpaper; mpvpaper -o "no-audio loop" ALL "${path}" & ln -sf "${path}" ${root.homeDir}/.cache/current_wallpaper`;
        applyProc.command = ["sh", "-c", cmd];
        applyProc.running = true;
    }

    function applyImage(path, mode) {
        const cmd = `
            ln -sf "${path}" ${root.homeDir}/.cache/current_wallpaper;
            matugen -t scheme-rainbow image "${path}" --mode ${mode};
            pkill mpvpaper;
            awww img --transition-duration 1 "${path}";
        `;
        applyProc.command = ["sh", "-c", cmd];
        applyProc.running = true;
        root.visible = false;
        root.inputMode = "grid";
    }

    // --- Window Focus Management ---
    onVisibleChanged: {
        if (visible) {
            rescanWallpapers()
            grid.forceActiveFocus();
            grid.currentIndex = 0;
            root.inputMode = "grid";
        }
    }

    // Close Button
    Button {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        z: 10
        width: 24; height: 24
        background: Rectangle {
            color: parent.hovered ? "#ff5555" : "transparent"
            radius: 12
        }
        contentItem: Text { text: "✕"; color: parent.hovered ? "white" : ColorTheme.primary; anchors.centerIn: parent }
        onClicked: root.visible = false
    }

    // --- Grid UI with VIM Navigation ---
    GridView {
        id: grid
        anchors.fill: parent
        anchors.margins: 12
        anchors.topMargin: 32
        cellWidth: 140
        cellHeight: 100
        clip: true
        focus: true
        
        model: wallpaperModel
        highlightFollowsCurrentItem: true
        
        Keys.onPressed: (event) => {
            if (root.inputMode === "grid") {
                if (event.text === "h") { grid.moveCurrentIndexLeft(); event.accepted = true; }
                else if (event.text === "l") { grid.moveCurrentIndexRight(); event.accepted = true; }
                else if (event.text === "j") { grid.moveCurrentIndexDown(); event.accepted = true; }
                else if (event.text === "k") { grid.moveCurrentIndexUp(); event.accepted = true; }
                else if (event.text === "L") { 
                     const item = wallpaperModel.get(grid.currentIndex);
                     if (!item.isVideo) applyImage(item.filePath, "light");
                }
                else if (event.text === "D") { 
                     const item = wallpaperModel.get(grid.currentIndex);
                     if (!item.isVideo) applyImage(item.filePath, "dark");
                }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    const item = wallpaperModel.get(grid.currentIndex);
                    if (item.isVideo) {
                        applyVideo(item.filePath);
                    } else {
                        root.inputMode = "overlay";
                        root.overlaySelection = "light";
                    }
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Escape) {
                    root.visible = false;
                    event.accepted = true;
                }
            } 
            else if (root.inputMode === "overlay") {
                if (event.text === "h" || event.text === "l") {
                    root.overlaySelection = (root.overlaySelection === "light" ? "dark" : "light");
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    const item = wallpaperModel.get(grid.currentIndex);
                    applyImage(item.filePath, root.overlaySelection);
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Escape) {
                    root.inputMode = "grid";
                    event.accepted = true;
                }
            }
        }

        delegate: Item {
            width: grid.cellWidth
            height: grid.cellHeight
            
            readonly property bool isSelected: GridView.isCurrentItem || hoverHandler.hovered
            readonly property bool showOverlay: (hoverHandler.hovered && !model.isVideo) || 
                                              (GridView.isCurrentItem && root.inputMode === "overlay" && !model.isVideo)

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: 6
                color: "transparent"
                border.color: isSelected ? ColorTheme.primary : "transparent"
                border.width: isSelected ? 2 : 0
                clip: true

                Image {
                    anchors.fill: parent
                    source: "file://" + model.thumbPath
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                }

                Rectangle {
                    visible: model.isVideo
                    anchors.centerIn: parent
                    width: 30; height: 30; radius: 15
                    color: "#80000000"
                    Text { text: "▶"; color: "white"; anchors.centerIn: parent }
                }

                HoverHandler { 
                    id: hoverHandler 
                    onHoveredChanged: if (hovered) grid.currentIndex = index
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: model.isVideo
                    onClicked: {
                        grid.currentIndex = index
                        grid.forceActiveFocus()
                        applyVideo(model.filePath)
                    }
                }

                Rectangle {
                    visible: showOverlay
                    anchors.fill: parent
                    color: "#AA000000"

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        
                        Button {
                            id: btnLight
                            text: "Light"
                            property bool active: hovered || (root.inputMode === "overlay" && root.overlaySelection === "light")
                            background: Rectangle { 
                                color: parent.active ? "#FFFFFF" : "#DDDDDD" 
                                radius: 4; implicitWidth: 80; implicitHeight: 24 
                            }
                            contentItem: Text { text: parent.text; color: "black"; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 12 }
                            onClicked: applyImage(model.filePath, "light")
                        }
                        
                        Button {
                            id: btnDark
                            text: "Dark"
                            property bool active: hovered || (root.inputMode === "overlay" && root.overlaySelection === "dark")
                            background: Rectangle { 
                                color: parent.active ? "#555555" : "#333333" 
                                radius: 4; implicitWidth: 80; implicitHeight: 24 
                            }
                            contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 12 }
                            onClicked: applyImage(model.filePath, "dark")
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        onClicked: {
                             grid.currentIndex = index
                             grid.forceActiveFocus()
                             root.inputMode = "overlay"
                             root.overlaySelection = "light"
                        }
                    }
                }
            }
        }
        ScrollBar.vertical: ScrollBar { width: 4; active: true }
    }
}
