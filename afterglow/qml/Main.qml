import QtQuick
import QtQuick.Window

// Development / fallback mode: an ordinary window.
Window {
    id: win
    visible: true
    color: "black"
    title: "Afterglow"
    width: ForcedSize ? parseInt(ForcedSize.split("x")[0]) : 1600
    height: ForcedSize ? parseInt(ForcedSize.split("x")[1]) : 900
    function openSettings() { scene.settingsOpen = true }
    Scene { id: scene; anchors.fill: parent }
}
