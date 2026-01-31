import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property var output
    focusable: true
    visible: true
    // --- 1. LAYOUT & FOCUS CONFIGURATION ---
    anchors {
        top: true
        left: true
    }
    margins {
        left: popupX
        top: popupY
    }

    property int popupX: 0
    property int popupY: 0

    implicitWidth: 600
    implicitHeight: 400
    
    color: "transparent"

    // --- State Management ---
    property string inputMode: "grid" 
    property string overlaySelection: "light"
    
    property string homeDir: ""
    property string wallpaperDir: ""
    property string cacheDir: ""
    
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
        command: ["find", root.wallpaperDir, "-type", "f", "(", "-iname", "*.jpg", "-o", "-iname", "*.png", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.webp", "-o", "-iname", "*.gif", "-o", "-iname", "*.mp4", ")"]
        stdout: SplitParser {
            onRead: text => {
                if (text.trim() !== "") {
                    addWallpaper(text.trim())
                }
            }
        }
    }

    // Incremental rescan
    Process {
        id: incrementalScanProc
        running: false
        command: ["find", root.wallpaperDir, "-type", "f", "(", "-iname", "*.jpg", "-o", "-iname", "*.png", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.webp", "-o", "-iname", "*.gif", "-o", "-iname", "*.mp4", ")"]
        
        property var foundPaths: ({})
        property var toRemove: []
        
        onRunningChanged: {
            if (running) {
                foundPaths = {}
                toRemove = []
            } else {
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
                    if (!root.knownPaths[path]) {
                        addWallpaper(path)
                    }
                }
            }
        }
    }

    function rescanWallpapers() {
        if (root.wallpaperDir !== "" && !incrementalScanProc.running) {
            incrementalScanProc.running = true
        }
    }

    function addWallpaper(path) {
        root.knownPaths[path] = true
        
        const isMp4 = path.endsWith(".mp4");
        const isGif = path.endsWith(".gif");
        const isVideo = isMp4 || isGif; // Used for UI badges/logic
        
        // For images, thumb is the path itself. For videos/GIFs, it's a generated PNG.
        let thumb = path;
        
        if (isVideo) {
            const filename = path.split("/").pop();
            thumb = root.cacheDir + "/" + filename + ".png";
            
            const checkCmd = "test -f '" + thumb + "'";
            // Generate thumb: Works for both MP4 and GIF
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
            "isVideo": isVideo,
            "isGif": isGif,
            "isMp4": isMp4
        });
    }

    // --- Apply Actions ---
    Process { id: applyProc }

    // ONLY for MP4 videos now (using mpvpaper)
    function applyVideo(path) {
        if (applyProc.running) applyProc.interrupt();
        
        // Added --panscan=1.0 to ensure video fills the screen (crop)
        const cmd = `pkill mpvpaper; sleep 0.2; nohup mpvpaper -o "no-audio --loop --panscan=1.0" '*' "${path}" > /dev/null 2>&1 & ln -sf "${path}" ${root.homeDir}/.cache/current_wallpaper`;
        
        applyProc.command = ["sh", "-c", cmd];
        applyProc.running = true;
        root.visible = false;
        root.inputMode = "grid";
    }

    // Used for Images AND GIFs (using awww + matugen)
    function applyImage(path, mode, thumbPath) {
        if (applyProc.running) applyProc.interrupt();
        
        // 1. Matugen: Uses the THUMBNAIL (static png) for color generation.
        //    This is faster and safer than passing a GIF to matugen.
        // 2. awww: Uses --resize crop to ensure the GIF/Image covers the screen.
        
        const cmd = `
            ln -sf "${path}" ${root.homeDir}/.cache/current_wallpaper;
            matugen -t scheme-rainbow image "${thumbPath}" --mode ${mode};
            pkill mpvpaper;
            awww img --transition-duration 1 --resize crop "${path}";
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

    // --- Grid UI ---
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
                if (event.text === "h" || event.key === Qt.Key_Left) { 
                    grid.moveCurrentIndexLeft(); event.accepted = true; 
                }
                else if (event.text === "l" || event.key === Qt.Key_Right) { 
                    grid.moveCurrentIndexRight(); event.accepted = true; 
                }
                else if (event.text === "j" || event.key === Qt.Key_Down) { 
                    grid.moveCurrentIndexDown(); event.accepted = true; 
                }
                else if (event.text === "k" || event.key === Qt.Key_Up) { 
                    grid.moveCurrentIndexUp(); event.accepted = true; 
                }
                else if (event.text === "L") { 
                     const item = wallpaperModel.get(grid.currentIndex);
                     // Allow quick apply for GIFs too (treated as images)
                     if (!item.isMp4) applyImage(item.filePath, "light", item.thumbPath);
                     event.accepted = true;
                }
                else if (event.text === "D") { 
                     const item = wallpaperModel.get(grid.currentIndex);
                     if (!item.isMp4) applyImage(item.filePath, "dark", item.thumbPath);
                     event.accepted = true;
                }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (grid.currentIndex >= 0 && grid.currentIndex < wallpaperModel.count) {
                        const item = wallpaperModel.get(grid.currentIndex);
                        // MP4 -> Video Player
                        if (item && item.isMp4) {
                            applyVideo(item.filePath);
                        } 
                        // GIF or Image -> Overlay (Matugen Selection)
                        else if (item) {
                            root.inputMode = "overlay";
                            root.overlaySelection = "light";
                        }
                    }
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Escape) {
                    root.visible = false;
                    event.accepted = true;
                }
            } 
            else if (root.inputMode === "overlay") {
                if (event.text === "h" || event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                    root.overlaySelection = (root.overlaySelection === "light" ? "dark" : "light");
                    event.accepted = true;
                }
                else if (event.text === "l" || event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                    root.overlaySelection = (root.overlaySelection === "light" ? "dark" : "light");
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    const item = wallpaperModel.get(grid.currentIndex);
                    // Apply using the generated thumbnail for matugen safety
                    applyImage(item.filePath, root.overlaySelection, item.thumbPath);
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
                
                // Use precise index checking for robustness
                readonly property bool isSelected: index === grid.currentIndex || hoverHandler.hovered
                
                readonly property bool showOverlay: (hoverHandler.hovered && !model.isMp4) || 
                                                  (GridView.isCurrentItem && root.inputMode === "overlay" && !model.isMp4)

                // 1. Container (Background only)
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 6
                    color: "transparent"
                    clip: true // Keep clip here

                    // 2. The Image (Draws first)
                    Image {
                        anchors.fill: parent
                        source: "file://" + model.thumbPath
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }

                    // 3. The Border (Draws ON TOP of the image)
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        radius: 6
                        border.color: isSelected ? ColorTheme.primary : "transparent"
                        border.width: isSelected ? 3 : 0 // Increased width slightly for visibility
                    }

                    // 4. Video Indicator
                    Rectangle {
                        visible: model.isVideo
                        anchors.centerIn: parent
                        width: 36; height: 36; radius: 18
                        color: "#CC000000"
                        Text { 
                            text: model.isGif ? "GIF" : "▶"
                            color: "white"
                            font.bold: true
                            font.pixelSize: model.isGif ? 10 : 14
                            anchors.centerIn: parent 
                        }
                    }

                    // Logic Handlers
                    HoverHandler { 
                        id: hoverHandler 
                        onHoveredChanged: if (hovered) grid.currentIndex = index
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            grid.currentIndex = index
                            grid.forceActiveFocus()
                            if (model.isMp4) {
                                applyVideo(model.filePath)
                            } else {
                                root.inputMode = "overlay"
                                root.overlaySelection = "light"
                            }
                        }
                    }

                    // 5. The Interaction Overlay
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
                                onClicked: applyImage(model.filePath, "light", model.thumbPath)
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
                                onClicked: applyImage(model.filePath, "dark", model.thumbPath)
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
