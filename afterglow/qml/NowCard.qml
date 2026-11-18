import QtQuick
import QtQuick.Effects

// The cover card: big artwork in a glass frame that glows in the accent color, plus quick actions.
Item {
    id: root
    property real u: 1
    property color accent: "white"
    readonly property var track: B.track
    width: 380 * u
    height: body.height + actions.height + 18 * u

    property real floatY: 0
    SequentialAnimation on floatY {
        loops: Animation.Infinite
        NumberAnimation { to: -6; duration: 3400; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 3400; easing.type: Easing.InOutSine }
    }

    Item {
        id: body
        width: parent.width
        height: 488 * root.u
        y: root.floatY * root.u
        transformOrigin: Item.Center

        RectangularShadow {   // colored halo
            anchors.fill: frame
            anchors.margins: 18 * root.u
            radius: frame.radius
            blur: 90 * root.u
            spread: 10 * root.u
            offset.y: 26 * root.u
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)
        }
        RectangularShadow {
            anchors.fill: frame
            radius: frame.radius
            blur: 36 * root.u
            offset.y: 14 * root.u
            color: Qt.rgba(0, 0, 0, 0.6)
        }
        Rectangle {
            id: frame
            anchors.fill: parent
            radius: 34 * root.u
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.30) }
                GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.10) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.20) }
            }
            border.width: 1.5
            border.color: Qt.rgba(1, 1, 1, 0.38)
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 7 * root.u
            radius: 28 * root.u
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0.05, 0.05, 0.07, 0.55) }
                GradientStop { position: 1; color: Qt.rgba(root.accent.r * 0.15, root.accent.g * 0.15, root.accent.b * 0.15, 0.82) }
            }
        }
        RoundImage {
            id: art
            x: 18 * root.u; y: 18 * root.u
            width: parent.width - 36 * root.u
            height: width
            radius: 20 * root.u
            sourceWidth: 900
            source: B.cover
        }
        Text {
            id: title
            anchors { left: art.left; right: art.right; top: art.bottom; topMargin: 16 * root.u }
            text: root.track ? root.track.title : B.strings.notPlaying
            color: "white"
            font.pixelSize: 24 * root.u
            font.weight: Font.Bold
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            anchors { left: art.left; right: art.right; top: title.bottom; topMargin: 4 * root.u }
            text: root.track ? (root.track.album ? root.track.artist + "  ·  " + root.track.album : root.track.artist) : B.strings.playSomething
            color: root.track ? Qt.lighter(root.accent, 1.3) : Qt.rgba(1, 1, 1, 0.6)
            font.pixelSize: 16 * root.u
            font.weight: Font.Medium
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // quick actions under the card
    Row {
        id: actions
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: body.bottom
        anchors.topMargin: 18 * root.u
        spacing: 10 * root.u
        visible: !!root.track
        height: 38 * root.u

        component Chip: Rectangle {
            id: chip
            property string icon
            property string label
            property bool on: false
            property color tint: "white"
            signal clicked()
            height: 38 * root.u
            width: (label ? lbl.implicitWidth + 18 * root.u : 0) + 38 * root.u
            radius: height / 2
            color: on ? Qt.rgba(tint.r, tint.g, tint.b, 0.25) : Qt.rgba(0, 0, 0, ma.containsMouse ? 0.6 : 0.42)
            border.color: on ? Qt.rgba(tint.r, tint.g, tint.b, 0.7) : Qt.rgba(1, 1, 1, 0.16)
            Behavior on color { ColorAnimation { duration: 150 } }
            Icon {
                id: ic
                x: 12 * root.u
                anchors.verticalCenter: parent.verticalCenter
                width: 16 * root.u; height: width
                name: chip.icon
                color: chip.on ? chip.tint : "white"
            }
            Text {
                id: lbl
                anchors { left: ic.right; leftMargin: 8 * root.u; verticalCenter: parent.verticalCenter }
                text: chip.label
                color: "white"
                font.pixelSize: 14 * root.u
                font.weight: Font.DemiBold
            }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
            scale: ma.pressed ? 0.94 : 1
            Behavior on scale { NumberAnimation { duration: 100 } }
        }

        Chip { icon: B.liked ? "heartFill" : "heart"; on: B.liked; tint: "#ff5c8a"; onClicked: B.toggleLike() }
        Chip { icon: "ban"; label: B.strings.dontSuggest; onClicked: B.banCurrent() }
        Chip {
            icon: "search"; label: B.strings.otherLyrics
            visible: S.data.showLyrics && B.lyrics.versions > 1
            onClicked: B.otherLyrics()
        }
    }

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
