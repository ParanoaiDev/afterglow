import QtQuick
import QtQuick.Window
import org.kde.layershell 1.0 as LayerShell

// The real thing: a full-screen surface on the desktop layer, under every window and above the wallpaper.
Window {
    id: win
    visible: true
    color: "black"
    title: "Afterglow"
    width: Screen.width
    height: Screen.height
    LayerShell.Window.scope: "afterglow"
    LayerShell.Window.layer: LayerShell.Window.LayerBottom
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
    function openSettings() { scene.settingsOpen = true }
    Scene { id: scene; anchors.fill: parent }
}
