import QtQuick
import QtQuick.Effects

// Frosted panel: blurs whatever part of the backdrop sits behind it, then tints it.
Item {
    id: g
    property real radius: 24
    property Item backdrop: null
    property real tint: 0.42
    property bool blurBehind: true

    ShaderEffectSource {
        id: src
        sourceItem: g.backdrop
        visible: false
        live: true
        hideSource: false
        sourceRect: {
            g.x; g.y; g.width; g.height; g.parent && g.parent.x; g.parent && g.parent.y;
            if (!g.backdrop) return Qt.rect(0, 0, 0, 0)
            var p = g.mapToItem(g.backdrop, 0, 0)
            return Qt.rect(p.x, p.y, g.width, g.height)
        }
    }
    Item {
        id: blurBox
        anchors.fill: parent
        visible: false
        layer.enabled: g.blurBehind && !!g.backdrop
        MultiEffect {
            anchors.fill: parent
            source: src
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            saturation: 0.25
        }
    }
    Rectangle { id: mask; anchors.fill: parent; radius: g.radius; visible: false; layer.enabled: true; antialiasing: true }
    MultiEffect {
        anchors.fill: parent
        visible: g.blurBehind && !!g.backdrop
        source: blurBox
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
    Rectangle {
        anchors.fill: parent
        radius: g.radius
        color: Qt.rgba(0.06, 0.06, 0.08, g.tint)
        border.color: Qt.rgba(1, 1, 1, 0.14)
        border.width: 1
        antialiasing: true
    }
    Rectangle {  // soft top sheen
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
        height: Math.min(parent.height * 0.5, 60)
        radius: g.radius
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.07) }
            GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
        }
    }
}
