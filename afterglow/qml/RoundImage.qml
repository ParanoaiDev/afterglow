import QtQuick
import QtQuick.Effects

// Image with rounded corners and a music-note placeholder while empty or loading.
Item {
    id: root
    property alias source: img.source
    property real radius: 12
    property int sourceWidth: 512
    readonly property bool ready: img.status === Image.Ready

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(1, 1, 1, 0.08)
        border.color: Qt.rgba(1, 1, 1, 0.10)
        visible: !root.ready
        Icon { anchors.centerIn: parent; width: parent.width * 0.32; height: width; name: "note"; opacity: 0.55 }
    }
    Image {
        id: img
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize.width: root.sourceWidth
        visible: false
        layer.enabled: true
        // YouTube has no 720p thumbnail for some videos; fall back to the small one
        onStatusChanged: if (status === Image.Error && String(source).indexOf("/hq720.jpg") > 0)
                             source = String(source).replace("/hq720.jpg", "/mqdefault.jpg")
    }
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: root.radius
        visible: false
        layer.enabled: true
        antialiasing: true
    }
    MultiEffect {
        anchors.fill: parent
        source: img
        visible: root.ready
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        opacity: root.ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }
}
