import QtQuick
import QtQuick.Effects

// "Continue Playing": the queue on the left edge.
Item {
    id: root
    property real u: 1
    property color accent: "white"
    width: 390 * u

    Row {
        id: header
        spacing: 6 * root.u
        Text {
            text: B.queueTitle
            color: "white"
            font.pixelSize: 19 * root.u
            font.weight: Font.Bold
        }
        Icon { name: "chevron"; width: 16 * root.u; height: width; anchors.verticalCenter: parent.verticalCenter; opacity: 0.7 }
    }
    Text {
        id: sub
        anchors.top: header.bottom
        anchors.topMargin: 2 * root.u
        text: B.queue.length ? B.strings.onSource.replace("{0}", B.sourceLabel) : B.strings.nothingQueued
        color: Qt.rgba(1, 1, 1, 0.55)
        font.pixelSize: 13 * root.u
    }

    ListView {
        id: list
        anchors { top: sub.bottom; topMargin: 14 * root.u; left: parent.left; right: parent.right; bottom: parent.bottom }
        model: B.queue
        currentIndex: B.queueIndex
        clip: true
        spacing: 2 * root.u
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 400
        preferredHighlightBegin: height * 0.2
        preferredHighlightEnd: height * 0.4
        highlightRangeMode: ListView.ApplyRange
        layer.enabled: true
        layer.effect: MultiEffect { maskEnabled: true; maskSource: fade }

        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool current: index === B.queueIndex
            width: list.width
            height: 58 * root.u
            Rectangle {
                anchors.fill: parent
                radius: 14 * root.u
                color: row.current ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.88)
                                   : Qt.rgba(1, 1, 1, rowArea.containsMouse ? 0.10 : 0)
                Behavior on color { ColorAnimation { duration: 250 } }
            }
            RoundImage {
                id: thumb
                x: 8 * root.u
                anchors.verticalCenter: parent.verticalCenter
                width: 42 * root.u; height: width
                radius: 9 * root.u
                sourceWidth: 160
                source: row.modelData.thumb
            }
            Column {
                anchors { left: thumb.right; leftMargin: 12 * root.u; right: parent.right; rightMargin: 10 * root.u; verticalCenter: parent.verticalCenter }
                spacing: 1 * root.u
                Text {
                    width: parent.width
                    text: row.modelData.title
                    color: row.current ? "#111" : "white"
                    font.pixelSize: 15 * root.u
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: row.modelData.artist
                    color: row.current ? Qt.rgba(0, 0, 0, 0.65) : Qt.rgba(1, 1, 1, 0.55)
                    font.pixelSize: 13 * root.u
                    elide: Text.ElideRight
                }
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
            GradientStop { position: 0.85; color: "white" }
            GradientStop { position: 1; color: "transparent" }
        }
    }
}
