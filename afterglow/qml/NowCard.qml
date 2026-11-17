import QtQuick
import QtQuick.Effects

// The glass card with the cover art, title and artist.
Item {
    id: root
    property real u: 1
    property color accent: "white"
    readonly property var track: B.track
    width: 330 * u
    height: 420 * u

    property real floatY: 0
    SequentialAnimation on floatY {
        loops: Animation.Infinite
        NumberAnimation { to: -6; duration: 3400; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 3400; easing.type: Easing.InOutSine }
    }

    Item {
        id: body
        width: parent.width; height: parent.height
        y: root.floatY * root.u
        transformOrigin: Item.Center

        RectangularShadow {
            anchors.fill: frame
            radius: frame.radius
            blur: 40 * root.u
            spread: 0
            offset.y: 18 * root.u
            color: Qt.rgba(0, 0, 0, 0.55)
        }
        Rectangle {
            id: frame
            anchors.fill: parent
            radius: 30 * root.u
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.26) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.12) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.18) }
            }
            border.width: 1.5
            border.color: Qt.rgba(1, 1, 1, 0.35)
        }
        Rectangle {  // dark inner plate so the text reads on any video
            anchors.fill: parent
            anchors.margins: 7 * root.u
            radius: 24 * root.u
            color: Qt.rgba(0.05, 0.05, 0.07, 0.62)
        }
        RoundImage {
            id: art
            x: 16 * root.u; y: 16 * root.u
            width: parent.width - 32 * root.u
            height: width
            radius: 18 * root.u
            sourceWidth: 800
            source: B.cover
        }
        Text {
            id: title
            anchors { left: art.left; right: art.right; top: art.bottom; topMargin: 14 * root.u }
            text: root.track ? root.track.title : B.strings.notPlaying
            color: "white"
            font.pixelSize: 21 * root.u
            font.weight: Font.Bold
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            anchors { left: art.left; right: art.right; top: title.bottom; topMargin: 3 * root.u }
            text: root.track ? (root.track.album ? root.track.artist + " — " + root.track.album : root.track.artist) : B.strings.playSomething
            color: Qt.rgba(1, 1, 1, 0.66)
            font.pixelSize: 15 * root.u
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // pop the card when the song changes
    Connections {
        target: B
        function onTrackChanged() {
            if (root.track && root.track.id !== root._lastId) { root._lastId = root.track.id; pop.restart() }
        }
    }
    property string _lastId: ""
    SequentialAnimation {
        id: pop
        ParallelAnimation {
            NumberAnimation { target: body; property: "scale"; to: 0.92; duration: 140; easing.type: Easing.InQuad }
            NumberAnimation { target: body; property: "opacity"; to: 0.5; duration: 140 }
        }
        ParallelAnimation {
            NumberAnimation { target: body; property: "scale"; to: 1.0; duration: 520; easing.type: Easing.OutBack }
            NumberAnimation { target: body; property: "opacity"; to: 1.0; duration: 320 }
        }
    }
}
