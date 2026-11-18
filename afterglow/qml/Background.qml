import QtQuick
import QtQuick.Effects
import QtMultimedia

Item {
    id: root
    clip: true
    readonly property string mode: S.data.background
    readonly property string videoSource: mode === "clip" ? (B.clip.path || "") : (mode === "video" ? B.fileUrl(S.data.backgroundPath) : "")
    readonly property bool videoShown: (mode === "clip" || mode === "video") && videoSource !== "" && mp.hasVideo
                                       && mp.playbackState !== MediaPlayer.StoppedState
    readonly property bool coverShown: mode === "cover" || (mode === "clip" && !videoShown)

    Rectangle { anchors.fill: parent; color: root.mode === "color" ? S.data.backgroundColor : "#07070a" }

    // blurred, oversized cover art (also the stand-in while a clip downloads)
    Image {
        id: cover
        anchors.centerIn: parent
        width: parent.width * 1.2; height: parent.height * 1.2
        source: B.cover
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 480
        asynchronous: true
        visible: false
        onStatusChanged: if (status === Image.Error && String(source).indexOf("/hq720.jpg") > 0)
                             source = String(source).replace("/hq720.jpg", "/mqdefault.jpg")
    }
    MultiEffect {
        anchors.fill: cover
        source: cover
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        saturation: 0.15
        brightness: -0.12
        opacity: root.coverShown && cover.status === Image.Ready ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 900; easing.type: Easing.InOutQuad } }
    }

    Image {
        anchors.fill: parent
        visible: root.mode === "image"
        source: root.mode === "image" ? B.fileUrl(S.data.backgroundPath) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    MediaPlayer {
        id: mp
        source: root.videoSource
        videoOutput: vo
        loops: (root.mode === "video" || !B.clip.synced) ? MediaPlayer.Infinite : 1
        onSourceChanged: if (source != "") { play() }
        onMediaStatusChanged: {
            if ((mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia) && root.mode === "clip" && B.clip.synced)
                position = B.position * 1000
        }
    }
    // Picture area of the clip without baked-in black bars (detected after download).
    readonly property var geom: (root.mode === "clip" && B.clip.geom && B.clip.geom.w) ? B.clip.geom : null
    readonly property real vw: geom ? geom.w : 16
    readonly property real vh: geom ? geom.h : 9
    readonly property real cx: geom ? geom.cx : 0
    readonly property real cy: geom ? geom.cy : 0
    readonly property real cw: geom ? geom.cw : vw
    readonly property real ch: geom ? geom.ch : vh
    // tall pictures are shown whole over a blurred copy of themselves; wide ones fill the screen
    readonly property bool tall: cw / ch < 1.2
    readonly property real k: tall ? Math.min(width / cw, height / ch) : Math.max(width / cw, height / ch)

    MultiEffect {  // blurred fill behind a tall clip
        anchors.centerIn: parent
        width: Math.max(root.width, root.height * root.cw / root.ch) * 1.15
        height: width * root.ch / root.cw
        visible: root.tall && root.videoShown
        source: videoBox
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        brightness: -0.15
    }
    Item {
        id: videoBox
        anchors.centerIn: parent
        width: root.geom ? root.cw * root.k : root.width
        height: root.geom ? root.ch * root.k : root.height
        clip: true
        opacity: root.videoShown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 1000; easing.type: Easing.InOutQuad } }
        layer.enabled: root.tall && root.videoShown
        VideoOutput {
            id: vo
            fillMode: root.geom ? VideoOutput.Stretch : VideoOutput.PreserveAspectCrop
            x: root.geom ? -root.cx * root.k : 0
            y: root.geom ? -root.cy * root.k : 0
            width: root.geom ? root.vw * root.k : parent.width
            height: root.geom ? root.vh * root.k : parent.height
        }
    }
    Connections {
        target: B
        function onPositionChanged() {
            if (root.mode === "clip" && B.clip.synced && mp.playbackState === MediaPlayer.PlayingState
                    && Math.abs(mp.position / 1000 - B.position) > 0.4)
                mp.position = B.position * 1000
        }
        function onStateChanged() {
            if (root.mode !== "clip" || root.videoSource === "") return
            if (B.paused) mp.pause(); else mp.play()
        }
    }

    // keep text readable over any background
    Rectangle { anchors.fill: parent; color: "black"; opacity: S.data.dim }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: parent.height * 0.42
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.55) }
        }
    }
    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: parent.width * 0.3
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.45) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
}
