import QtQuick

Item {
    id: root
    property real u: 1
    property Item backdrop
    width: Math.min(label.implicitWidth + 48 * u, 900 * u)
    height: label.implicitHeight + 24 * u
    opacity: 0
    visible: opacity > 0
    function show(text) { label.text = text; anim.restart() }
    Glass { anchors.fill: parent; radius: height / 2; backdrop: root.backdrop; tint: 0.6 }
    Text {
        id: label
        anchors.centerIn: parent
        width: Math.min(implicitWidth, 850 * root.u)
        color: "white"
        font.pixelSize: 16 * root.u
        font.weight: Font.Medium
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }
    SequentialAnimation {
        id: anim
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: 200 }
        PauseAnimation { duration: 6000 }
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 500 }
    }
    MouseArea { anchors.fill: parent; onClicked: { anim.stop(); root.opacity = 0 } }
}
