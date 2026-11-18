import QtQuick

// Three bouncing bars for the track that is playing now.
Row {
    id: root
    property color color: "white"
    property bool running: true
    property real barWidth: 3
    spacing: barWidth * 0.8
    height: 14
    Repeater {
        model: 3
        delegate: Rectangle {
            id: bar
            required property int index
            width: root.barWidth
            radius: width / 2
            color: root.color
            anchors.bottom: parent.bottom
            height: root.height * 0.35
            SequentialAnimation on height {
                running: root.running && root.visible
                loops: Animation.Infinite
                NumberAnimation { to: root.height * (0.9 - bar.index * 0.12); duration: 260 + bar.index * 90; easing.type: Easing.InOutSine }
                NumberAnimation { to: root.height * 0.25; duration: 300 + bar.index * 70; easing.type: Easing.InOutSine }
            }
        }
    }
}
