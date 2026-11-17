import QtQuick

Item {
    id: root
    property string icon
    property real size: 22
    property color color: "white"
    property bool active: false
    property bool enabledLook: true
    signal clicked()
    implicitWidth: size * 2; implicitHeight: size * 2
    opacity: enabledLook ? 1 : 0.35
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Qt.rgba(1, 1, 1, area.pressed ? 0.22 : (area.containsMouse ? 0.12 : (root.active ? 0.10 : 0)))
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    Icon {
        anchors.centerIn: parent
        width: root.size; height: root.size
        name: root.icon
        color: root.color
        scale: area.pressed ? 0.88 : 1
        Behavior on scale { NumberAnimation { duration: 110 } }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
