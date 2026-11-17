import QtQuick
import QtQuick.Controls.Basic

Item {
    id: root
    property real u: 1
    property color accent: "white"
    property Item backdrop
    signal closeRequested()
    readonly property var res: B.search
    width: 940 * u
    height: 600 * u
    function focusField() { field.forceActiveFocus(); field.selectAll() }

    Glass { anchors.fill: parent; radius: 30 * root.u; backdrop: root.backdrop; tint: 0.58 }

    Flickable {
        id: flick
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: fieldBox.top; margins: 24 * root.u; bottomMargin: 12 * root.u }
        contentHeight: content.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
            id: content
            width: flick.width
            spacing: 14 * root.u

            Text {
                visible: !root.res.query
                text: B.strings.search
                color: Qt.rgba(1, 1, 1, 0.45)
                font.pixelSize: 18 * root.u
            }
            Text {
                visible: root.res.loading && root.res.tracks.length === 0
                text: B.strings.searching
                color: Qt.rgba(1, 1, 1, 0.6)
                font.pixelSize: 18 * root.u
            }
            Text {
                visible: !!root.res.query && !root.res.loading && root.res.tracks.length === 0 && root.res.artists.length === 0
                text: root.res.error || B.strings.noResults
                color: Qt.rgba(1, 1, 1, 0.6)
                font.pixelSize: 18 * root.u
                width: parent.width
                wrapMode: Text.WordWrap
            }

            // --- Top results: big covers
            Text {
                visible: root.res.tracks.length > 0
                text: B.strings.topResults
                color: "white"; font.pixelSize: 20 * root.u; font.weight: Font.Bold
            }
            Row {
                spacing: 16 * root.u
                visible: root.res.tracks.length > 0
                Repeater {
                    model: root.res.tracks.slice(0, 6)
                    delegate: Item {
                        required property var modelData
                        width: 132 * root.u; height: 186 * root.u
                        RoundImage {
                            id: cov
                            width: parent.width; height: width
                            radius: 14 * root.u
                            sourceWidth: 320
                            source: modelData.thumb
                            scale: ma.containsMouse ? 1.04 : 1
                            Behavior on scale { NumberAnimation { duration: 140 } }
                            Icon { x: 6 * root.u; y: 6 * root.u; width: 18 * root.u; height: width; name: modelData.source }
                        }
                        Text {
                            id: tt
                            anchors { top: cov.bottom; topMargin: 7 * root.u; left: parent.left; right: parent.right }
                            text: modelData.title
                            color: "white"; font.pixelSize: 14 * root.u; font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            anchors { top: tt.bottom; left: parent.left; right: parent.right }
                            text: (modelData.kind === "video" ? B.strings.video : B.strings.song) + " · " + modelData.artist
                            color: Qt.rgba(1, 1, 1, 0.55); font.pixelSize: 12 * root.u
                            elide: Text.ElideRight
                        }
                        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { B.playResult(modelData); root.closeRequested() } }
                    }
                }
            }

            // --- Artists
            Text {
                visible: root.res.artists.length > 0
                text: B.strings.artists
                color: "white"; font.pixelSize: 20 * root.u; font.weight: Font.Bold
            }
            Row {
                spacing: 22 * root.u
                visible: root.res.artists.length > 0
                Repeater {
                    model: root.res.artists.slice(0, 6)
                    delegate: Item {
                        required property var modelData
                        width: 100 * root.u; height: 128 * root.u
                        RoundImage { id: av; width: 92 * root.u; height: width; anchors.horizontalCenter: parent.horizontalCenter; radius: width / 2; sourceWidth: 200; source: modelData.thumb }
                        Text {
                            anchors { top: av.bottom; topMargin: 6 * root.u; left: parent.left; right: parent.right }
                            text: modelData.name
                            color: "white"; font.pixelSize: 13 * root.u; font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { field.text = modelData.name; B.openArtist(modelData) } }
                    }
                }
            }

            // --- the rest as a list
            Text {
                visible: root.res.tracks.length > 6
                text: B.strings.songs
                color: "white"; font.pixelSize: 20 * root.u; font.weight: Font.Bold
            }
            Grid {
                columns: 2
                columnSpacing: 12 * root.u
                rowSpacing: 4 * root.u
                visible: root.res.tracks.length > 6
                Repeater {
                    model: root.res.tracks.slice(6)
                    delegate: Item {
                        required property var modelData
                        width: (content.width - 12 * root.u) / 2
                        height: 56 * root.u
                        Rectangle { anchors.fill: parent; radius: 12 * root.u; color: Qt.rgba(1, 1, 1, rowMa.containsMouse ? 0.09 : 0) }
                        RoundImage { id: th; x: 6 * root.u; anchors.verticalCenter: parent.verticalCenter; width: 44 * root.u; height: width; radius: 8 * root.u; sourceWidth: 160; source: modelData.thumb }
                        Column {
                            anchors { left: th.right; leftMargin: 10 * root.u; right: srcIc.left; rightMargin: 8 * root.u; verticalCenter: parent.verticalCenter }
                            Text { width: parent.width; text: modelData.title; color: "white"; font.pixelSize: 14 * root.u; font.weight: Font.DemiBold; elide: Text.ElideRight }
                            Text { width: parent.width; text: modelData.artist; color: Qt.rgba(1, 1, 1, 0.55); font.pixelSize: 12 * root.u; elide: Text.ElideRight }
                        }
                        Icon { id: srcIc; anchors { right: parent.right; rightMargin: 10 * root.u; verticalCenter: parent.verticalCenter } width: 16 * root.u; height: width; name: modelData.source; opacity: 0.8 }
                        MouseArea { id: rowMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { B.playResult(modelData); root.closeRequested() } }
                    }
                }
            }
        }
    }

    Rectangle {
        id: fieldBox
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 16 * root.u }
        height: 52 * root.u
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.08)
        border.color: field.activeFocus ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.7) : Qt.rgba(1, 1, 1, 0.12)
        Icon { id: mag; x: 18 * root.u; anchors.verticalCenter: parent.verticalCenter; width: 20 * root.u; height: width; name: "search"; opacity: 0.8 }
        TextField {
            id: field
            anchors { left: mag.right; leftMargin: 10 * root.u; right: busy.left; rightMargin: 8 * root.u; verticalCenter: parent.verticalCenter }
            placeholderText: B.strings.search
            placeholderTextColor: Qt.rgba(1, 1, 1, 0.4)
            color: "white"
            font.pixelSize: 18 * root.u
            background: null
            selectByMouse: true
            onTextEdited: debounce.restart()
            onAccepted: { debounce.stop(); B.doSearch(text) }
            Keys.onEscapePressed: root.closeRequested()
        }
        BusyRing { id: busy; anchors { right: parent.right; rightMargin: 18 * root.u; verticalCenter: parent.verticalCenter } width: 22 * root.u; height: width; visible: root.res.loading; color: root.accent }
    }
    Timer { id: debounce; interval: 450; onTriggered: B.doSearch(field.text) }
}
