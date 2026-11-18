import QtQuick
import QtQuick.Effects

// The queue on the left: a glass panel with artwork, durations and a live "now playing" row.
Item {
    id: root
    property real u: 1
    property color accent: "white"
    property Item backdrop
    width: 430 * u

    function fmt(s) { s = Math.max(0, Math.floor(s || 0)); return Math.floor(s / 60) + ":" + ("0" + s % 60).slice(-2) }

    Glass { anchors.fill: parent; radius: 30 * root.u; backdrop: root.backdrop; tint: 0.38 }

    Item {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 22 * root.u }
        height: 58 * root.u
        Text {
            id: ttl
            text: B.queueTitle
            color: "white"
            font.pixelSize: 26 * root.u
            font.weight: Font.Bold
        }
        Text {
            anchors { top: ttl.bottom; topMargin: 2 * root.u }
            text: B.queue.length ? B.strings.tracksCount.replace("{0}", B.queue.length) + "  ·  " + B.sourceLabel : B.strings.nothingQueued
            color: Qt.rgba(1, 1, 1, 0.5)
            font.pixelSize: 13 * root.u
        }
        IconButton {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            icon: "mix"; size: 18 * root.u
            color: root.accent
            onClicked: B.startForYou()
        }
    }

    ListView {
        id: list
        anchors { top: head.bottom; topMargin: 10 * root.u; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 10 * root.u }
        model: B.queue
        currentIndex: B.queueIndex
        clip: true
        spacing: 4 * root.u
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 450
        preferredHighlightBegin: 0
        preferredHighlightEnd: height * 0.3
        highlightRangeMode: ListView.ApplyRange
        layer.enabled: true
        layer.effect: MultiEffect { maskEnabled: true; maskSource: fade }

        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool current: index === B.queueIndex
            readonly property bool past: index < B.queueIndex
            width: list.width
            height: 64 * root.u
            opacity: past ? 0.45 : 1

            Rectangle {
                anchors.fill: parent
                radius: 16 * root.u
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: row.current ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.42) : Qt.rgba(1, 1, 1, rowArea.containsMouse ? 0.09 : 0) }
                    GradientStop { position: 1; color: row.current ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.08) : Qt.rgba(1, 1, 1, rowArea.containsMouse ? 0.04 : 0) }
                }
                border.width: row.current ? 1 : 0
                border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)
            }
            RoundImage {
                id: thumb
                x: 8 * root.u
                anchors.verticalCenter: parent.verticalCenter
                width: 48 * root.u; height: width
                radius: 11 * root.u
                sourceWidth: 200
                source: row.modelData.thumb
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Qt.rgba(0, 0, 0, 0.45)
                    visible: row.current
                    Equalizer {
                        anchors.centerIn: parent
                        height: 16 * root.u
                        barWidth: 3 * root.u
                        color: root.accent
                        running: !B.paused
                    }
                }
            }
            Column {
                anchors { left: thumb.right; leftMargin: 13 * root.u; right: dur.left; rightMargin: 10 * root.u; verticalCenter: parent.verticalCenter }
                spacing: 2 * root.u
                Text {
                    width: parent.width
                    text: row.modelData.title
                    color: row.current ? Qt.lighter(root.accent, 1.35) : "white"
                    font.pixelSize: 15 * root.u
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: row.modelData.artist
                    color: Qt.rgba(1, 1, 1, 0.55)
                    font.pixelSize: 13 * root.u
                    elide: Text.ElideRight
                }
            }
            Text {
                id: dur
                anchors { right: parent.right; rightMargin: 14 * root.u; verticalCenter: parent.verticalCenter }
                text: root.fmt(row.modelData.duration)
                color: Qt.rgba(1, 1, 1, 0.4)
                font.pixelSize: 12 * root.u
                font.features: { "tnum": 1 }
            }
            MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: B.playQueue(row.index)
            }
        }
    }
    Rectangle {
        id: fade
        anchors.fill: list
        visible: false
        layer.enabled: true
        gradient: Gradient {
            GradientStop { position: 0; color: "white" }
            GradientStop { position: 0.88; color: "white" }
            GradientStop { position: 1; color: "transparent" }
        }
    }
}
