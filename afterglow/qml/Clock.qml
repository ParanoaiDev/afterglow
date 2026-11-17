import QtQuick
import QtQuick.Effects

Item {
    id: root
    property color color: "white"
    property real u: 1
    property date now: new Date()
    readonly property real stretch: 1.42
    width: Math.max(timeText.width, dateText.width)
    height: dateText.height + timeText.height * stretch - timeText.height * 0.12

    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    Text {
        id: dateText
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.now.toLocaleDateString(Qt.locale(B.language === "ru" ? "ru_RU" : "en_US"), "ddd, d MMM")
        color: root.color
        font.pixelSize: 24 * root.u
        font.weight: Font.DemiBold
        font.letterSpacing: 0.5 * root.u
    }
    Text {
        id: timeText
        anchors.horizontalCenter: parent.horizontalCenter
        y: dateText.height - height * 0.14
        text: S.data.clock24 ? Qt.formatTime(root.now, "H:mm") : Qt.formatTime(root.now, "h:mm")
        color: root.color
        font.family: "Inter Display"
        font.weight: Font.Thin
        font.pixelSize: 250 * root.u
        font.letterSpacing: -6 * root.u
        transform: Scale { yScale: root.stretch; origin.y: 0 }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.color
            shadowBlur: 1.0
            blurMax: 48
            shadowOpacity: 0.55
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
    }
}
