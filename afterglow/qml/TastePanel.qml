import QtQuick
import QtQuick.Controls.Basic

// "What do you listen to?": pick the artists the For You picker starts from.
Item {
    id: root
    property real u: 1
    property color accent: "white"
    property Item backdrop
    signal closeRequested()
    property var chosen: []
    width: 820 * u
    height: col.height + 70 * u

    function reload() { chosen = B.tasteSeeds.slice(0); field.text = ""; B.suggestArtists("") }
    function add(name) {
        if (chosen.map(n => n.toLowerCase()).indexOf(name.toLowerCase()) < 0) chosen = chosen.concat([name])
        field.text = ""
        B.suggestArtists("")
        field.forceActiveFocus()
    }
    function remove(name) { chosen = chosen.filter(n => n !== name) }

    Glass { anchors.fill: parent; radius: 34 * root.u; backdrop: root.backdrop; tint: 0.7 }
    MouseArea { anchors.fill: parent }
    IconButton { anchors { right: parent.right; top: parent.top; margins: 18 * root.u } icon: "close"; size: 18 * root.u; onClicked: root.closeRequested() }

    Column {
        id: col
        x: 40 * root.u; y: 36 * root.u
        width: parent.width - 80 * root.u
        spacing: 16 * root.u

        Text { text: B.strings.tasteTitle; color: "white"; font.pixelSize: 34 * root.u; font.weight: Font.Bold }
        Text {
            width: parent.width
            text: B.strings.tasteText
            color: Qt.rgba(1, 1, 1, 0.7)
            font.pixelSize: 16 * root.u
            wrapMode: Text.WordWrap
            lineHeight: 1.15
        }

        Rectangle {
            width: parent.width
            height: 54 * root.u
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.08)
            border.color: field.activeFocus ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.8) : Qt.rgba(1, 1, 1, 0.14)
            Icon { id: mag; x: 20 * root.u; anchors.verticalCenter: parent.verticalCenter; width: 20 * root.u; height: width; name: "search"; opacity: 0.8 }
            TextField {
                id: field
                anchors { left: mag.right; leftMargin: 10 * root.u; right: parent.right; rightMargin: 20 * root.u; verticalCenter: parent.verticalCenter }
                placeholderText: B.strings.tasteSearch
                placeholderTextColor: Qt.rgba(1, 1, 1, 0.4)
                color: "white"
                font.pixelSize: 18 * root.u
                background: null
                onTextEdited: deb.restart()
                onAccepted: if (text.trim().length > 1) root.add(text.trim())
                Keys.onEscapePressed: root.closeRequested()
            }
            Timer { id: deb; interval: 400; onTriggered: B.suggestArtists(field.text) }
        }

        // suggestions as avatars
        Flow {
            width: parent.width
            spacing: 14 * root.u
            visible: B.artistSuggestions.length > 0
            Repeater {
                model: B.artistSuggestions
                delegate: Item {
                    required property var modelData
                    width: 104 * root.u; height: 132 * root.u
                    RoundImage { id: av; width: 84 * root.u; height: width; anchors.horizontalCenter: parent.horizontalCenter; radius: width / 2; sourceWidth: 200; source: modelData.thumb
                        Rectangle {
                            anchors { right: parent.right; bottom: parent.bottom }
                            width: 26 * root.u; height: width; radius: width / 2
                            color: root.accent
                            Icon { anchors.centerIn: parent; width: 14 * root.u; height: width; name: "plus"; color: "#111" }
                        }
                    }
                    Text {
                        anchors { top: av.bottom; topMargin: 6 * root.u; left: parent.left; right: parent.right }
                        text: modelData.name; color: "white"; font.pixelSize: 13 * root.u; font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.add(modelData.name) }
                }
            }
        }

        Text {
            visible: root.chosen.length > 0
            text: B.strings.tasteChosen
            color: Qt.rgba(1, 1, 1, 0.5)
            font.pixelSize: 13 * root.u
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.2 * root.u
        }
        Flow {
            width: parent.width
            spacing: 8 * root.u
            Repeater {
                model: root.chosen
                delegate: Rectangle {
                    required property string modelData
                    height: 40 * root.u
                    width: nm.implicitWidth + 56 * root.u
                    radius: height / 2
                    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
                    border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.6)
                    Text { id: nm; x: 18 * root.u; anchors.verticalCenter: parent.verticalCenter; text: modelData; color: "white"; font.pixelSize: 15 * root.u; font.weight: Font.DemiBold }
                    Icon {
                        anchors { right: parent.right; rightMargin: 14 * root.u; verticalCenter: parent.verticalCenter }
                        width: 12 * root.u; height: width; name: "close"; opacity: 0.8
                        MouseArea { anchors.fill: parent; anchors.margins: -8 * root.u; cursorShape: Qt.PointingHandCursor; onClicked: root.remove(modelData) }
                    }
                }
            }
        }

        Item {
            width: parent.width; height: 40 * root.u
            Text { anchors.verticalCenter: parent.verticalCenter; text: B.strings.noRussian; color: "white"; font.pixelSize: 16 * root.u }
            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 48 * root.u; height: 28 * root.u; radius: height / 2
                color: S.data.noRussian ? root.accent : Qt.rgba(1, 1, 1, 0.18)
                Rectangle {
                    width: parent.height - 6 * root.u; height: width; radius: width / 2; y: 3 * root.u
                    x: S.data.noRussian ? parent.width - width - 3 * root.u : 3 * root.u
                    color: S.data.noRussian ? "#16161b" : "white"
                    Behavior on x { NumberAnimation { duration: 150 } }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: S.set("noRussian", !S.data.noRussian) }
            }
        }

        Rectangle {
            width: startTxt.implicitWidth + 48 * root.u
            height: 50 * root.u
            radius: height / 2
            color: root.chosen.length ? root.accent : Qt.rgba(1, 1, 1, 0.12)
            opacity: root.chosen.length ? 1 : 0.6
            Text { id: startTxt; anchors.centerIn: parent; text: B.strings.tasteStart; color: root.chosen.length ? "#111" : "white"; font.pixelSize: 17 * root.u; font.weight: Font.Bold }
            MouseArea {
                anchors.fill: parent
                enabled: root.chosen.length > 0
                cursorShape: Qt.PointingHandCursor
                onClicked: { B.setSeeds(root.chosen); B.startForYou(); root.closeRequested() }
            }
        }
    }
}
