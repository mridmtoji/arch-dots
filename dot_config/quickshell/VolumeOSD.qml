import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets

Scope {
	id: root
	
	readonly property real maxVolume: 1.0
	
	// Bind the pipewire node so its volume will be tracked
	PwObjectTracker {
		objects: [ Pipewire.defaultAudioSink ]
	}
	
	Connections {
		target: Pipewire.defaultAudioSink?.audio ?? null
		function onVolumeChanged() {
			if (Pipewire.defaultAudioSink?.audio.volume > 1.0) {
				Pipewire.defaultAudioSink.audio.volume = 1.0;
			}
			root.shouldShowOsd = true;
			hideTimer.restart();
		}
	}
	
	property bool shouldShowOsd: false
	
	Timer {
		id: hideTimer
		interval: 1000
		onTriggered: root.shouldShowOsd = false
	}
	
	// The OSD window will be created and destroyed based on shouldShowOsd.
	// PanelWindow.visible could be set instead of using a loader, but using
	// a loader will reduce the memory overhead when the window isn't open.
	LazyLoader {
		active: root.shouldShowOsd
		
		PanelWindow {
			// Since the panel's screen is unset, it will be picked by the compositor
			// when the window is created. Most compositors pick the current active monitor.
			anchors.bottom: true
			margins.bottom: screen.height / 5
			exclusiveZone: 0
			implicitWidth: 300
			implicitHeight: 50
			color: "transparent"
			
			// An empty click mask prevents the window from blocking mouse events.
			mask: Region {}
			
			Rectangle {
				anchors.fill: parent
				radius: height / 2
				color: ColorTheme.background
				
				RowLayout {
					anchors {
						fill: parent
						leftMargin: 10
						rightMargin: 15
					}
					
					Text {
						Layout.preferredWidth: 25
						Layout.preferredHeight: 25
						text: "󰕾"
						font.family: "FontAwesome"
						font.pixelSize: 25
						color: ColorTheme.inverseSurface
						horizontalAlignment: Text.AlignHCenter
						verticalAlignment: Text.AlignVCenter
					}
					
					Rectangle {
						// Stretches to fill all left-over space
						Layout.fillWidth: true
						implicitHeight: 10
						radius: 20
						color: ColorTheme.primaryContainer
						clip: true  // CRITICAL: Prevents overflow
						
						Rectangle {
							anchors {
								left: parent.left
								top: parent.top
								bottom: parent.bottom
							}
							
							// Scale based on maxVolume (e.g., at 150% volume and 200% max = 75% bar)
							width: parent.width * Math.min(1.0, (Pipewire.defaultAudioSink?.audio.volume ?? 0) / root.maxVolume)
							radius: parent.radius
							color: ColorTheme.primaryFixedDim
							
							Behavior on width {
								NumberAnimation {
									duration: 100
									easing.type: Easing.OutQuad
								}
							}
						}
					}
					
					// Volume percentage display
					Text {
						Layout.preferredWidth: 50
						text: Math.round((Pipewire.defaultAudioSink?.audio.volume ?? 0) * 100) + "%"
						font.family: ColorTheme.systemFont
						font.pixelSize: 17
                        font.weight: Font.Medium
						color: ColorTheme.primary
						horizontalAlignment: Text.AlignRight
						verticalAlignment: Text.AlignVCenter
					}
				}
			}
		}
	}
}
