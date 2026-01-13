pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root



    // Colors JSON file
    FileView {
        id: jsonFile
        path: Qt.resolvedUrl("quickshell-colors.json")
        blockLoading: true
        watchChanges: true
        onFileChanged: {
            console.log("Colors file changed, reloading...")
            reloadTimer.restart()
        }
    }


    // Debounce wallpaper changes
    Timer {
        id: wallpaperTimer
        interval: 50
        onTriggered: generateColors()
    }

    // Debounce color reload
    Timer {
        id: reloadTimer
        interval: 200  // Increased delay to ensure matugen finishes
        onTriggered: {
            jsonFile.reload()
            console.log("Colors reloaded!")
            colorsChanged()
        }
    }

    // Parse colors from FileView
    property var colors: {
        const text = jsonFile.text()
        if (!text?.trim()) {
            console.warn("Colors file is empty!")
            return {}
        }

        try {
            const data = JSON.parse(text)
            return data?.colors ?? {}
        } catch (e) {
            console.error("Failed to parse colors:", e)
            return {}
        }
    }

    // Matugen process (for auto-generation when wallpaper changes)
    Process {
        id: matugenProcess
        onExited: {
            console.log("Matugen finished, reloading colors...")
            reloadTimer.restart()
        }
    }

    // Generate colors from wallpaper
    function generateColors() {
        wallpaperFile.reload()
        const path = wallpaperFile.text()?.trim()

        if (!path) {
            console.log("No wallpaper path found")
            return
        }

        const cleanPath = path.replace("file://", "")
        const mode = isDarkMode ? "dark" : "light"

        console.log("Generating colors from:", cleanPath, "mode:", mode)
        matugenProcess.command = ["/bin/sh", "-c", 
            `matugen image "${cleanPath}" -m "${mode}"`]
        matugenProcess.running = true
    }


    property string systemFont: "GeistMono Nerd Font"

    // Color properties with fallbacks
    property color background: colors.background 
    property color surface: colors.surface 
    property color surfaceBright: colors.surface_bright 
    property color surfaceContainer: colors.surface_container 
    property color surfaceContainerLow: colors.surface_container_low 
    property color surfaceContainerHigh: colors.surface_container_high 
    property color surfaceContainerHighest: colors.surface_container_highest 
    property color surfaceDim: colors.surface_dim 
    
    property color primary: colors.primary 
    property color primaryContainer: colors.primary_container 
    property color primaryFixed: colors.primary_fixed 
    property color primaryFixedDim: colors.primary_fixed_dim 
    
    property color secondary: colors.secondary 
    property color secondaryContainer: colors.secondary_container 
    property color secondaryFixed: colors.secondary_fixed 
    property color secondaryFixedDim: colors.secondary_fixed_dim 
    
    property color tertiary: colors.tertiary 
    property color tertiaryContainer: colors.tertiary_container 
    property color tertiaryFixed: colors.tertiary_fixed 
    property color tertiaryFixedDim: colors.tertiary_fixed_dim 
    
    property color error: colors.error 
    property color errorContainer: colors.error_container 
    
    property color onBackground: colors.on_background 
    property color onSurface: colors.on_surface 
    property color onSurfaceVariant: colors.on_surface_variant 
    property color onPrimary: colors.on_primary 
    property color onPrimaryContainer: colors.on_primary_container 
    property color onPrimaryFixed: colors.on_primary_fixed 
    property color onPrimaryFixedVariant: colors.on_primary_fixed_variant 
    property color onSecondary: colors.on_secondary 
    property color onSecondaryContainer: colors.on_secondary_container 
    property color onSecondaryFixed: colors.on_secondary_fixed 
    property color onSecondaryFixedVariant: colors.on_secondary_fixed_variant 
    property color onTertiary: colors.on_tertiary 
    property color onTertiaryContainer: colors.on_tertiary_container 
    property color onTertiaryFixed: colors.on_tertiary_fixed 
    property color onTertiaryFixedVariant: colors.on_tertiary_fixed_variant 
    property color onError: colors.on_error 
    property color onErrorContainer: colors.on_error_container 
    
    property color outline: colors.outline 
    property color outlineVariant: colors.outline_variant 
    property color inverseSurface: colors.inverse_surface 
    property color inverseOnSurface: colors.inverse_on_surface 
    property color inversePrimary: colors.inverse_primary 
    property color scrim: colors.scrim 
    property color shadow: colors.shadow 
}
