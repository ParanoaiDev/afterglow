import QtQuick
import QtQuick.Effects

Item {
    id: root
    property string name
    property color color: "white"
    readonly property bool tinted: !Qt.colorEqual(color, "white")
    implicitWidth: 24; implicitHeight: 24
    Image {
        id: img
        anchors.fill: parent
        source: root.name ? Qt.resolvedUrl("../assets/icons/" + root.name + ".svg") : ""
        sourceSize: Qt.size(Math.max(16, root.width * 2), Math.max(16, root.height * 2))
        smooth: true
        visible: !root.tinted
    }
    MultiEffect {
        anchors.fill: parent
        source: img
        visible: root.tinted
        colorization: 1.0
        colorizationColor: root.color
        brightness: root.color.hslLightness < 0.2 ? -1.0 : 0.0
    }
}
