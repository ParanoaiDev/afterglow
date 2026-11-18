import QtQuick
import QtQuick.Effects

Item {
    id: root
    property real u: 1
    property color accent: "white"
    property Item backdrop
    signal serviceClicked()
    signal searchClicked()
    signal settingsClicked()
    readonly property var track: B.track
    width: 1040 * u
    height: 72 * u

    Glass { anchors.fill: parent; radius: height / 2; backdrop: root.backdrop }

    Row {
        id: left
        anchors { left: parent.left; leftMargin: 14 * root.u; verticalCenter: parent.verticalCenter }
        spacing: 2 * root.u
        Item {
            width: 44 * root.u; height: 44 * root.u
            anchors.verticalCenter: parent.verticalCenter
            Icon {
                anchors.centerIn: parent
                width: 26 * root.u; height: width
                name: root.track ? root.track.source : (B.source === "auto" ? "auto" : B.source)
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.serviceClicked() }
        }
        IconButton { icon: "prev"; size: 20 * root.u; anchors.verticalCenter: parent.verticalCenter; onClicked: B.prev() }
        IconButton {
            icon: B.paused || !root.track ? "play" : "pause"
            size: 26 * root.u
            anchors.verticalCenter: parent.verticalCenter
            onClicked: B.toggle()
            BusyRing { anchors.fill: parent; visible: B.loading; color: root.accent }
        }
        IconButton { icon: "next"; size: 20 * root.u; anchors.verticalCenter: parent.verticalCenter; onClicked: B.next() }
        IconButton {
            icon: S.data.repeat === "one" ? "repeat1" : "repeat"
            size: 18 * root.u
            anchors.verticalCenter: parent.verticalCenter
            color: S.data.repeat === "off" ? "white" : root.accent
            opacity: S.data.repeat === "off" ? 0.6 : 1
            onClicked: B.cycleRepeat()
        }
    }

    Rectangle {
        id: sep
        anchors { left: left.right; leftMargin: 14 * root.u; verticalCenter: parent.verticalCenter }
        width: 1; height: parent.height * 0.5
        color: Qt.rgba(1, 1, 1, 0.15)
    }

    RoundImage {
        id: mini
        anchors { left: sep.right; leftMargin: 16 * root.u; verticalCenter: parent.verticalCenter }
        width: 46 * root.u; height: width
        radius: 10 * root.u
        sourceWidth: 160
        source: B.cover
    }
    Item {
        id: info
        anchors { left: mini.right; leftMargin: 12 * root.u; right: right.left; rightMargin: 18 * root.u; top: mini.top; bottom: mini.bottom }
        Text {
            id: t1
            width: parent.width
            text: root.track ? root.track.title : B.strings.notPlaying
            color: "white"
            font.pixelSize: 15 * root.u
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            anchors.top: t1.bottom
            width: parent.width
            text: root.track ? root.track.artist + (root.track.album ? " — " + root.track.album : "") : B.strings.playSomething
            color: Qt.rgba(1, 1, 1, 0.6)
            font.pixelSize: 13 * root.u
            elide: Text.ElideRight
        }
        // progress, click or drag to seek
        Item {
            id: prog
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 12 * root.u
            readonly property real frac: B.duration > 0 ? Math.min(1, B.position / B.duration) : 0
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: (seekArea.containsMouse ? 5 : 3) * root.u
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.18)
                Rectangle {
                    width: parent.width * (seekArea.pressed ? seekArea.mouseX / prog.width : prog.frac)
                    height: parent.height
                    radius: height / 2
                    color: root.accent
                }
            }
            MouseArea {
                id: seekArea
                anchors.fill: parent
                anchors.topMargin: -6 * root.u
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !!root.track
                onReleased: (m) => B.seek(Math.max(0, Math.min(1, m.x / prog.width)) * B.duration)
            }
        }
    }

    Row {
        id: right
        anchors { right: parent.right; rightMargin: 16 * root.u; verticalCenter: parent.verticalCenter }
        spacing: 2 * root.u
        Text {
            anchors.verticalCenter: parent.verticalCenter
            rightPadding: 8 * root.u
            text: fmt(B.position) + " / " + fmt(B.duration)
            color: Qt.rgba(1, 1, 1, 0.55)
            font.pixelSize: 12 * root.u
            font.features: { "tnum": 1 }
            visible: !!root.track
            function fmt(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + ("0" + s % 60).slice(-2) }
        }
        IconButton {
            icon: "lyrics"; size: 19 * root.u; anchors.verticalCenter: parent.verticalCenter
            enabledLook: S.data.showLyrics
            onClicked: S.set("showLyrics", !S.data.showLyrics)
        }
        IconButton { icon: "mix"; size: 19 * root.u; anchors.verticalCenter: parent.verticalCenter; onClicked: B.startForYou() }
        IconButton { icon: "search"; size: 19 * root.u; anchors.verticalCenter: parent.verticalCenter; onClicked: root.searchClicked() }
        IconButton { icon: "settings"; size: 19 * root.u; anchors.verticalCenter: parent.verticalCenter; onClicked: root.settingsClicked() }
        IconButton {
            id: volBtn
            icon: S.data.volume > 0 ? "volume" : "mute"
            size: 19 * root.u
            anchors.verticalCenter: parent.verticalCenter
            property int lastVol: 70
            onClicked: { if (S.data.volume > 0) { lastVol = S.data.volume; B.setVolume(0) } else B.setVolume(lastVol) }
        }
        Item {
            width: 110 * root.u; height: 30 * root.u
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 4 * root.u; radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.18)
                Rectangle { width: parent.width * S.data.volume / 100; height: parent.height; radius: height / 2; color: "white" }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                function apply(x) { B.setVolume(Math.round(Math.max(0, Math.min(1, x / width)) * 100)) }
                onPressed: (m) => apply(m.x)
                onPositionChanged: (m) => { if (pressed) apply(m.x) }
                onWheel: (w) => B.setVolume(S.data.volume + (w.angleDelta.y > 0 ? 5 : -5))
            }
        }
        Rectangle { width: 1; height: 30 * root.u; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(1, 1, 1, 0.15) }
        IconButton { icon: "power"; size: 18 * root.u; anchors.verticalCenter: parent.verticalCenter; color: "#ff6b6b"; onClicked: B.quit() }
    }
}
