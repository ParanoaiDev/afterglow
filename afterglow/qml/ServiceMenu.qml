import QtQuick

Item {
    id: root
    property real u: 1
    property Item backdrop
    signal picked()
    width: 290 * u
    height: col.height + 16 * u
    readonly property var items: [
        { key: "youtube", label: "YouTube", icon: "youtube" },
        { key: "soundcloud", label: "SoundCloud", icon: "soundcloud" },
        { key: "auto", label: B.strings.automatic, icon: "auto" }
    ]
    Glass { anchors.fill: parent; radius: 22 * root.u; backdrop: root.backdrop; tint: 0.55 }
    Column {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 * root.u }
        Repeater {
            model: root.items
            delegate: Item {
                required property var modelData
                width: col.width
                height: 46 * root.u
                readonly property bool sel: B.source === modelData.key
                Rectangle {
                    anchors.fill: parent
                    radius: 14 * root.u
                    color: Qt.rgba(1, 1, 1, sel ? 0.16 : (ma.containsMouse ? 0.09 : 0))
                }
                Icon { id: ic; x: 12 * root.u; anchors.verticalCenter: parent.verticalCenter; width: 24 * root.u; height: width; name: modelData.icon }
                Text {
                    anchors { left: ic.right; leftMargin: 12 * root.u; verticalCenter: parent.verticalCenter }
                    text: modelData.label
                    color: "white"
                    font.pixelSize: 16 * root.u
                    font.weight: Font.DemiBold
                }
                Icon { visible: sel; anchors { right: parent.right; rightMargin: 14 * root.u; verticalCenter: parent.verticalCenter } width: 16 * root.u; height: width; name: "check" }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { B.setSource(modelData.key); root.picked() } }
            }
        }
    }
}
