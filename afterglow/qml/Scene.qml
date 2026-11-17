import QtQuick

Item {
    id: scene
    readonly property real u: Math.max(0.5, Math.min(width / 2560, height / 1440))
    readonly property var cfg: S.data
    property color accent: B.accent
    Behavior on accent { ColorAnimation { duration: 1200 } }

    property bool searchOpen: false
    property bool settingsOpen: false
    property bool serviceOpen: false
    readonly property bool anyPopup: searchOpen || settingsOpen || serviceOpen
    function closePopups() { searchOpen = false; settingsOpen = false; serviceOpen = false; keys.forceActiveFocus() }
    function openSearch() { serviceOpen = false; settingsOpen = false; searchOpen = true; search.focusField() }

    Background { id: bg; anchors.fill: parent }

    EdgeGlow {
        anchors.fill: parent
        visible: scene.cfg.showGlow
        color: scene.accent
        strength: scene.cfg.glowStrength
        depth: 70 * scene.u
    }

    // background clicks close popups
    MouseArea { anchors.fill: parent; enabled: scene.anyPopup; onClicked: scene.closePopups() }

    Clock {
        id: clock
        visible: scene.cfg.showClock
        u: scene.u
        color: scene.accent
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: 120 * scene.u
        y: parent.height * 0.07
    }

    QueueList {
        visible: scene.cfg.showQueue
        u: scene.u
        accent: scene.accent
        x: 56 * scene.u
        y: parent.height * 0.2
        height: parent.height * 0.56
    }

    NowCard {
        id: card
        visible: scene.cfg.showCard
        u: scene.u
        accent: scene.accent
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -60 * scene.u
        y: parent.height * 0.42
    }
    Rectangle {  // "Other lyrics" chip under the card
        visible: scene.cfg.showCard && scene.cfg.showLyrics && B.lyrics.versions > 1
        anchors { horizontalCenter: card.horizontalCenter; top: card.bottom; topMargin: 14 * scene.u }
        width: olRow.width + 26 * scene.u; height: 32 * scene.u; radius: height / 2
        color: Qt.rgba(0, 0, 0, olMa.containsMouse ? 0.55 : 0.4)
        border.color: Qt.rgba(1, 1, 1, 0.18)
        Row {
            id: olRow
            anchors.centerIn: parent
            spacing: 6 * scene.u
            Icon { name: "search"; width: 14 * scene.u; height: width; anchors.verticalCenter: parent.verticalCenter }
            Text { text: B.strings.otherLyrics; color: "white"; font.pixelSize: 13 * scene.u; font.weight: Font.DemiBold }
        }
        MouseArea { id: olMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: B.otherLyrics() }
    }

    LyricsView {
        visible: scene.cfg.showLyrics
        u: scene.u
        accent: scene.accent
        x: scene.cfg.showCard ? card.x + card.width + 60 * scene.u : parent.width * 0.3
        y: card.y + 20 * scene.u
        width: Math.min(parent.width - x - 120 * scene.u, 760 * scene.u)
        height: card.height - 40 * scene.u
    }

    PlayerBar {
        id: bar
        u: scene.u
        accent: scene.accent
        backdrop: bg
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - height - 46 * scene.u
        onServiceClicked: { scene.searchOpen = false; scene.settingsOpen = false; scene.serviceOpen = !scene.serviceOpen }
        onSearchClicked: scene.searchOpen ? scene.closePopups() : scene.openSearch()
        onSettingsClicked: { scene.searchOpen = false; scene.serviceOpen = false; scene.settingsOpen = !scene.settingsOpen }
    }

    SearchPanel {
        id: search
        u: scene.u
        accent: scene.accent
        backdrop: bg
        anchors.horizontalCenter: parent.horizontalCenter
        y: bar.y - height - 16 * scene.u + (scene.searchOpen ? 0 : 30 * scene.u)
        opacity: scene.searchOpen ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        onCloseRequested: scene.closePopups()
    }

    ServiceMenu {
        u: scene.u
        backdrop: bg
        x: bar.x + 6 * scene.u
        y: bar.y - height - 12 * scene.u
        opacity: scene.serviceOpen ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
        onPicked: scene.serviceOpen = false
    }

    Rectangle {  // dim behind settings
        anchors.fill: parent
        color: "black"
        opacity: scene.settingsOpen ? 0.35 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        MouseArea { anchors.fill: parent; onClicked: scene.closePopups() }
    }
    SettingsPanel {
        u: scene.u
        accent: scene.accent
        backdrop: bg
        anchors.centerIn: parent
        opacity: scene.settingsOpen ? 1 : 0
        scale: scene.settingsOpen ? 1 : 0.96
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        onCloseRequested: scene.closePopups()
    }

    Toast {
        id: toast
        u: scene.u
        backdrop: bg
        anchors.horizontalCenter: parent.horizontalCenter
        y: 40 * scene.u
    }

    Connections {
        target: B
        function onToastRequested(text) { toast.show(text) }
        function onOpenSearchRequested() { scene.openSearch() }
    }

    // keyboard: space play/pause, Ctrl+F or / search, arrows seek/volume, Esc closes
    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Escape) { scene.closePopups(); e.accepted = true }
            else if (e.key === Qt.Key_Space) { B.toggle(); e.accepted = true }
            else if (e.key === Qt.Key_Slash || (e.key === Qt.Key_F && (e.modifiers & Qt.ControlModifier))) { scene.openSearch(); e.accepted = true }
            else if (e.key === Qt.Key_Right) { B.seek(B.position + 5); e.accepted = true }
            else if (e.key === Qt.Key_Left) { B.seek(B.position - 5); e.accepted = true }
            else if (e.key === Qt.Key_Up) { B.setVolume(S.data.volume + 5); e.accepted = true }
            else if (e.key === Qt.Key_Down) { B.setVolume(S.data.volume - 5); e.accepted = true }
            else if (e.key === Qt.Key_N) { B.next(); e.accepted = true }
            else if (e.key === Qt.Key_P) { B.prev(); e.accepted = true }
        }
    }
}
