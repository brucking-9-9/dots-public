import QtQuick
import "services"

// Skewed thumbnail strip above the panel. Hover = live preview through awww,
// click = set (and remember), Esc / click outside = restore.
Item {
    id: strip
    property bool open: false
    readonly property real wantedWidth: list.contentWidth + 90
    signal chosen()
    height: Theme.stripH
    opacity: open ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 200 } }

    HoverHandler { id: hover }
    readonly property bool hovered: hover.hovered

    HudPanel {
        anchors.fill: parent
        cutTL: false; cutTR: true; cutBL: true; cutBR: false
        cut: 14
    }

    Text {
        // anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        anchors.horizontalCenter: parent.horizontalCenter
        text: ">hover previews< · <>click sets<>"
        color: Theme.dim2
        font.family: Theme.font
        font.pixelSize: 9
    }

    ListView {
        id: list
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 4
        orientation: ListView.Horizontal
        spacing: 26
        height: 66
        width: Math.min(contentWidth, strip.width - 60)
        clip: true
        model: Wallpapers.files
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            id: cardItem
            required property string modelData
            readonly property bool hovered: hh.hovered
            readonly property bool current: modelData === Wallpapers.current
            readonly property bool loading: modelData === Wallpapers.busy
            width: 112
            height: 62
            y: hovered ? -4 : 0
            Behavior on y { NumberAnimation { duration: 150 } }

            // skewX(-14°) on the frame, counter-skew on the picture so only the frame leans
            transform: Matrix4x4 { matrix: Qt.matrix4x4(1, Math.tan(-14 * Math.PI / 180), 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }

            Item {
                anchors.fill: parent
                anchors.margins: 1
                clip: true
                Image {
                    x: -16
                    width: parent.width + 32
                    height: parent.height
                    transform: Matrix4x4 { matrix: Qt.matrix4x4(1, Math.tan(14 * Math.PI / 180), 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                    source: "file://" + cardItem.modelData
                    sourceSize: Qt.size(240, 140)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                }
            }
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 1
                border.color: cardItem.current ? Theme.yellow : (cardItem.hovered ? Theme.cyan : Theme.sel)
            }
            Rectangle {   // glow ring; pulses while awww is still loading this file
                anchors.fill: parent
                anchors.margins: -2
                color: "transparent"
                border.width: 2
                border.color: cardItem.loading ? Theme.pink : (cardItem.current ? Theme.yellow : Theme.cyan)
                opacity: cardItem.current || cardItem.hovered ? 0.35 : 0
                SequentialAnimation on opacity {
                    running: cardItem.loading
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.9; duration: 500 }
                    NumberAnimation { to: 0.2; duration: 500 }
                }
            }
            Text {   // animated files are not previewed on hover
                visible: Wallpapers.animated(cardItem.modelData)
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 4
                text: cardItem.loading ? "loading…" : "gif"
                color: cardItem.loading ? Theme.pink : Theme.purple
                font.family: Theme.font
                font.pixelSize: 8
                transform: Matrix4x4 { matrix: Qt.matrix4x4(1, Math.tan(14 * Math.PI / 180), 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
            }
            Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 10
                anchors.bottomMargin: 4
                width: nameTxt.implicitWidth + 8
                height: nameTxt.implicitHeight + 2
                color: Qt.rgba(0, 0, 0, 0.6)
                Text {
                    id: nameTxt
                    anchors.centerIn: parent
                    text: Wallpapers.name(cardItem.modelData)
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 9
                }
            }

            HoverHandler {
                id: hh
                onHoveredChanged: hovered ? Wallpapers.preview(cardItem.modelData) : Wallpapers.restoreSoon()
            }
            TapHandler {
                onTapped: {
                    Wallpapers.set(cardItem.modelData);
                    strip.chosen();
                }
            }
        }
    }
}
