import QtQuick
import QtQuick.Controls.Basic

Item {
    id: root
    property real u: 1
    property color accent: "white"
    property Item backdrop
    signal closeRequested()
    readonly property var cfg: S.data
    readonly property var st: B.strings
    width: 780 * u
    height: Math.min(parent ? parent.height - 120 * u : 900 * u, 960 * u)

    // ---- small controls -------------------------------------------------
    component Section: Text {
        color: Qt.rgba(1, 1, 1, 0.5)
        font.pixelSize: 13 * root.u
        font.weight: Font.Bold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1.2 * root.u
        topPadding: 10 * root.u
    }
    component Toggle: Item {
        id: tg
        property string label
        property string key
        width: parent ? parent.width : 300
        height: 40 * root.u
        readonly property bool on: !!root.cfg[key]
        Text { anchors.verticalCenter: parent.verticalCenter; text: tg.label; color: "white"; font.pixelSize: 16 * root.u }
        Rectangle {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 48 * root.u; height: 28 * root.u; radius: height / 2
            color: tg.on ? root.accent : Qt.rgba(1, 1, 1, 0.18)
            Behavior on color { ColorAnimation { duration: 150 } }
            Rectangle {
                width: parent.height - 6 * root.u; height: width; radius: width / 2
                y: 3 * root.u
                x: tg.on ? parent.width - width - 3 * root.u : 3 * root.u
                color: tg.on ? "#16161b" : "white"
                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: S.set(tg.key, !tg.on) }
    }
    component Segments: Item {
        id: sg
        property string label
        property string key
        property var options: []   // [{value, text}]
        width: parent ? parent.width : 300
        height: (label ? 30 * root.u : 0) + 40 * root.u
        Text { visible: !!sg.label; text: sg.label; color: "white"; font.pixelSize: 16 * root.u }
        Flow {
            y: sg.label ? 30 * root.u : 0
            width: parent.width
            spacing: 6 * root.u
            Repeater {
                model: sg.options
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool sel: root.cfg[sg.key] === modelData.value
                    width: lbl.implicitWidth + 28 * root.u
                    height: 36 * root.u
                    radius: height / 2
                    color: sel ? root.accent : Qt.rgba(1, 1, 1, segMa.containsMouse ? 0.14 : 0.08)
                    Text {
                        id: lbl
                        anchors.centerIn: parent
                        text: modelData.text
                        color: sel ? "#111" : "white"
                        font.pixelSize: 14 * root.u
                        font.weight: Font.DemiBold
                    }
                    MouseArea { id: segMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: S.set(sg.key, modelData.value) }
                }
            }
        }
    }
    component Slide: Item {
        id: sl
        property string label
        property string key
        property real from: 0
        property real to: 1
        width: parent ? parent.width : 300
        height: 44 * root.u
        readonly property real frac: (root.cfg[key] - from) / (to - from)
        Text { anchors.verticalCenter: parent.verticalCenter; text: sl.label; color: "white"; font.pixelSize: 16 * root.u }
        Item {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 260 * root.u; height: 28 * root.u
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 4 * root.u; radius: 2 * root.u
                color: Qt.rgba(1, 1, 1, 0.18)
                Rectangle { width: parent.width * sl.frac; height: parent.height; radius: parent.radius; color: root.accent }
            }
            Rectangle {
                x: parent.width * sl.frac - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 18 * root.u; height: width; radius: width / 2; color: "white"
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                function apply(x) { S.set(sl.key, Math.round((sl.from + Math.max(0, Math.min(1, x / width)) * (sl.to - sl.from)) * 100) / 100) }
                onPressed: (m) => apply(m.x)
                onPositionChanged: (m) => { if (pressed) apply(m.x) }
            }
        }
    }
    component Pill: Rectangle {
        id: pl
        property string text
        signal clicked()
        width: pt.implicitWidth + 28 * root.u
        height: 36 * root.u
        radius: height / 2
        color: Qt.rgba(1, 1, 1, pma.containsMouse ? 0.16 : 0.09)
        Text { id: pt; anchors.centerIn: parent; text: pl.text; color: "white"; font.pixelSize: 14 * root.u; font.weight: Font.DemiBold }
        MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pl.clicked() }
    }

    // ---- panel ----------------------------------------------------------
    Glass { anchors.fill: parent; radius: 32 * root.u; backdrop: root.backdrop; tint: 0.68 }
    MouseArea { anchors.fill: parent }  // swallow clicks

    Text {
        id: title
        x: 32 * root.u; y: 26 * root.u
        text: root.st.settings
        color: "white"
        font.pixelSize: 28 * root.u
        font.weight: Font.Bold
    }
    IconButton { anchors { right: parent.right; rightMargin: 20 * root.u; verticalCenter: title.verticalCenter } icon: "close"; size: 18 * root.u; onClicked: root.closeRequested() }

    Flickable {
        id: flick
        anchors { left: parent.left; right: parent.right; top: title.bottom; bottom: parent.bottom; margins: 32 * root.u; topMargin: 12 * root.u; bottomMargin: 20 * root.u }
        contentHeight: col.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
            id: col
            width: flick.width - 14 * root.u
            spacing: 6 * root.u

            Section { text: root.st.background }
            Segments {
                key: "background"
                options: [
                    { value: "clip", text: root.st.bgClip },
                    { value: "cover", text: root.st.bgCover },
                    { value: "image", text: root.st.bgImage },
                    { value: "video", text: root.st.bgVideo },
                    { value: "color", text: root.st.bgColor }
                ]
            }
            Row {
                visible: root.cfg.background === "image" || root.cfg.background === "video"
                spacing: 10 * root.u
                Pill {
                    text: root.st.choose
                    onClicked: {
                        var p = B.pickFile(root.cfg.background)
                        if (p) S.set("backgroundPath", p)
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 520 * root.u
                    text: root.cfg.backgroundPath
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font.pixelSize: 13 * root.u
                    elide: Text.ElideMiddle
                }
            }
            Row {
                visible: root.cfg.background === "color"
                spacing: 8 * root.u
                Repeater {
                    model: ["#0d0d12", "#1a0f1f", "#0b1a1f", "#1f140b", "#101a0b", "#202024"]
                    delegate: Rectangle {
                        required property string modelData
                        width: 36 * root.u; height: width; radius: width / 2
                        color: modelData
                        border.width: root.cfg.backgroundColor === modelData ? 3 : 1
                        border.color: root.cfg.backgroundColor === modelData ? root.accent : Qt.rgba(1, 1, 1, 0.3)
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: S.set("backgroundColor", modelData) }
                    }
                }
            }
            Segments {
                visible: root.cfg.background === "clip"
                label: root.st.clipQuality
                key: "clipQuality"
                options: [{ value: 720, text: "720p" }, { value: 1080, text: "1080p" }, { value: 1440, text: "1440p" }]
            }
            Slide { label: root.st.dim; key: "dim"; from: 0; to: 0.8 }

            Section { text: root.st.accent }
            Segments {
                key: "accentMode"
                options: [{ value: "auto", text: root.st.accentAuto }, { value: "fixed", text: root.st.accentFixed }]
            }
            Row {
                visible: root.cfg.accentMode === "fixed"
                spacing: 8 * root.u
                Repeater {
                    model: ["#ff4f8b", "#ff5a36", "#ffb020", "#b6ff3c", "#3cffb4", "#3cc8ff", "#6b5cff", "#d65cff", "#ffffff"]
                    delegate: Rectangle {
                        required property string modelData
                        width: 36 * root.u; height: width; radius: width / 2
                        color: modelData
                        border.width: root.cfg.accentColor === modelData ? 3 : 0
                        border.color: "white"
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: S.set("accentColor", modelData) }
                    }
                }
            }

            Section { text: root.st.show }
            Toggle { label: root.st.clock; key: "showClock" }
            Toggle { label: root.st.clock24; key: "clock24"; visible: root.cfg.showClock }
            Toggle { label: root.st.card; key: "showCard" }
            Toggle { label: root.st.lyrics; key: "showLyrics" }
            Toggle { label: root.st.queue; key: "showQueue" }
            Toggle { label: root.st.glow; key: "showGlow" }
            Slide { label: root.st.glowStrength; key: "glowStrength"; from: 0.1; to: 1; visible: root.cfg.showGlow }

            Section { text: root.st.source }
            Segments {
                key: "source"
                options: [{ value: "auto", text: root.st.automatic }, { value: "youtube", text: "YouTube" }, { value: "soundcloud", text: "SoundCloud" }]
            }
            Segments {
                label: root.st.signIn
                key: "signIn"
                options: [
                    { value: "auto", text: root.st.auto }, { value: "firefox", text: "Firefox" }, { value: "chrome", text: "Chrome" },
                    { value: "chromium", text: "Chromium" }, { value: "brave", text: "Brave" }, { value: "off", text: root.st.off }
                ]
            }
            Row {
                spacing: 10 * root.u
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10 * root.u; height: width; radius: width / 2
                    color: B.account ? "#4ade80" : "#f87171"
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: B.account ? root.st.signedInAs.replace("{0}", B.account.charAt(0).toUpperCase() + B.account.slice(1)) : root.st.notSignedIn
                    color: "white"
                    font.pixelSize: 15 * root.u
                }
                Pill { text: root.st.checkAgain; onClicked: B.checkSignIn() }
            }
            Toggle { label: root.st.autoplay; key: "autoplay" }
            Text {
                width: parent.width
                text: root.st.signInHint
                color: Qt.rgba(1, 1, 1, 0.5)
                font.pixelSize: 13 * root.u
                wrapMode: Text.WordWrap
            }

            Section { text: root.st.language }
            Segments {
                key: "language"
                options: [{ value: "auto", text: root.st.automatic }, { value: "ru", text: "Русский" }, { value: "en", text: "English" }]
            }
            Toggle { label: root.st.autostart; key: "autostart" }
            Item { width: 1; height: 10 * root.u }
            Row {
                spacing: 10 * root.u
                Pill { text: root.st.reset; onClicked: S.reset() }
                Pill { text: root.st.quit; onClicked: B.quit() }
            }
            Item { width: 1; height: 10 * root.u }
        }
    }
}
