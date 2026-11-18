import QtQuick
import QtQuick.Effects

Item {
    id: root
    property color color: "white"
    property real u: 1
    property date now: new Date()
    width: Math.max(timeText.implicitWidth, dateText.implicitWidth)
    height: dateText.implicitHeight + timeText.implicitHeight * 0.86

    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    Text {
        id: dateText
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.now.toLocaleDateString(Qt.locale(B.language === "ru" ? "ru_RU" : "en_US"), "dddd, d MMMM")
        color: root.color
        font.pixelSize: 26 * root.u
        font.weight: Font.DemiBold
        font.letterSpacing: 0.5 * root.u
        layer.enabled: true
        layer.effect: MultiEffect {   // readable over bright videos
            shadowEnabled: true
            shadowColor: "black"
            shadowBlur: 0.6
            shadowOpacity: 0.8
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 1
        }
    }
    Text {
        id: timeText
        anchors.horizontalCenter: parent.horizontalCenter
        y: dateText.implicitHeight - implicitHeight * 0.1
        text: S.data.clock24 ? Qt.formatTime(root.now, "H:mm") : Qt.formatTime(root.now, "h:mm")
        color: root.color
        font.family: "Oswald"
        font.weight: Font.ExtraLight
        font.variableAxes: { "wght": 220 }
        font.pixelSize: 330 * root.u
        font.letterSpacing: 2 * root.u
        renderType: Text.CurveRendering
        layer.enabled: true
        layer.samples: 4
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.color
            shadowBlur: 1.0
            blurMax: 40
            shadowOpacity: 0.6
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
    }
}
