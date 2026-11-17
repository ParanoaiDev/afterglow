import QtQuick
import QtQuick.Effects

// Synced lyrics as big kinetic lines; unsynced lyrics scroll with the song.
Item {
    id: root
    property real u: 1
    property color accent: "white"
    readonly property var lyr: B.lyrics
    readonly property bool synced: lyr.status === "ok" && lyr.synced
    readonly property string current: synced && B.line >= 0 && B.line < lyr.lines.length ? lyr.lines[B.line].text : ""
    readonly property string previous: synced && B.line > 0 ? lyr.lines[B.line - 1].text : ""

    // ---- synced: two stacked lines, the new one punches in
    Item {
        id: syncedBox
        anchors.fill: parent
        visible: root.synced

        Text {
            id: prevLine
            width: parent.width
            anchors.bottom: curWrap.top
            anchors.bottomMargin: 10 * root.u
            text: root.previous.toUpperCase()
            color: Qt.rgba(1, 1, 1, 0.38)
            font.pixelSize: 30 * root.u
            font.weight: Font.Black
            font.italic: true
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        Item {
            id: curWrap
            width: parent.width
            height: curLine.height
            anchors.verticalCenter: parent.verticalCenter
            opacity: B.line >= 0 ? 1 : 0.35   // the first line, not sung yet
        Text {
            id: curLine
            width: parent.width
            text: (root.current || (B.line >= 0 ? "♪" : (root.synced && root.lyr.lines.length ? root.lyr.lines[0].text : ""))).toUpperCase()
            color: "white"
            font.pixelSize: 56 * root.u
            font.weight: Font.Black
            font.italic: true
            font.letterSpacing: 1 * root.u
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            transformOrigin: Item.Left
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: root.accent
                shadowBlur: 0.8
                blurMax: 32
                shadowOpacity: 0.85
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
        }
        }
        Connections {
            target: B
            function onLineChanged() { punch.restart() }
        }
        ParallelAnimation {
            id: punch
            NumberAnimation { target: curLine; property: "opacity"; from: 0; to: 1; duration: 260 }
            NumberAnimation { target: curLine; property: "scale"; from: 1.18; to: 1; duration: 420; easing.type: Easing.OutCubic }
            NumberAnimation { target: curLine; property: "font.letterSpacing"; from: 10 * root.u; to: 1 * root.u; duration: 520; easing.type: Easing.OutCubic }
            NumberAnimation { target: prevLine; property: "opacity"; from: 0.9; to: 1; duration: 300 }
        }
    }

    // ---- plain lyrics: a slow scroll following song progress
    ListView {
        id: plain
        anchors.fill: parent
        visible: root.lyr.status === "ok" && !root.lyr.synced
        model: visible ? root.lyr.lines : []
        interactive: false
        clip: true
        spacing: 6 * root.u
        delegate: Text {
            width: plain.width
            text: modelData.text
            color: Qt.rgba(1, 1, 1, 0.8)
            font.pixelSize: 22 * root.u
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
        }
        contentY: B.duration > 0 ? Math.max(0, (contentHeight - height * 0.5) * Math.min(1, B.position / B.duration)) - height * 0.25 : 0
        Behavior on contentY { NumberAnimation { duration: 900 } }
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: fadeMask
        }
    }
    Rectangle {
        id: fadeMask
        anchors.fill: plain
        visible: false
        layer.enabled: true
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.2; color: "white" }
            GradientStop { position: 0.8; color: "white" }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: B.track !== null && B.track !== undefined && (root.lyr.status === "none" || root.lyr.status === "loading")
        text: root.lyr.status === "loading" ? B.strings.loadingLyrics : B.strings.noLyrics
        color: Qt.rgba(1, 1, 1, 0.55)
        font.pixelSize: 18 * root.u
        font.weight: Font.DemiBold
    }
}
