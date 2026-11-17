import QtQuick

// Neon light around the screen edge in the accent color, slowly breathing.
Item {
    id: root
    property color color: "white"
    property real strength: 0.8
    property real depth: 64
    property real breathe: 1
    SequentialAnimation on breathe {
        loops: Animation.Infinite
        NumberAnimation { to: 0.7; duration: 2800; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 2800; easing.type: Easing.InOutSine }
    }
    opacity: strength * breathe
    readonly property color c0: Qt.rgba(color.r, color.g, color.b, 0.9)
    readonly property color c1: Qt.rgba(color.r, color.g, color.b, 0.28)
    readonly property color c2: Qt.rgba(color.r, color.g, color.b, 0)

    component Edge: Rectangle {
        property bool horizontal: false
        property bool flip: false
        gradient: Gradient {
            orientation: horizontal ? Gradient.Horizontal : Gradient.Vertical
            GradientStop { position: flip ? 1.0 : 0.0; color: root.c0 }
            GradientStop { position: flip ? 0.82 : 0.18; color: root.c1 }
            GradientStop { position: flip ? 0.0 : 1.0; color: root.c2 }
        }
    }
    Edge { anchors { left: parent.left; right: parent.right; top: parent.top } height: root.depth }
    Edge { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: root.depth; flip: true }
    Edge { anchors { top: parent.top; bottom: parent.bottom; left: parent.left } width: root.depth; horizontal: true }
    Edge { anchors { top: parent.top; bottom: parent.bottom; right: parent.right } width: root.depth; horizontal: true; flip: true }
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: Math.max(2, root.depth * 0.05)
        border.color: Qt.lighter(root.color, 1.25)
    }
}
