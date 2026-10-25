import QtQuick
import "services"

// Skewed thumbnail strip above the panel. Hover = live preview through awww,
// click = set (and remember), Esc / click outside = restore. Subfolders of
// the wallpaper dir are tabs along the top (Wallpapers.folders).
Item {
    id: strip
    property bool open: false
    readonly property real wantedWidth: Math.max(list.contentWidth, tabs.implicitWidth + hint.implicitWidth + 24) + 90
    signal chosen()
    height: Theme.stripH
    opacity: open ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 200 } }

    HoverHandler { id: hover }
    readonly property bool hovered: hover.hovered

    // the cards lean: skewX(-lean) on the frame, +lean on what it holds, so
    // only the frame slants. skewPad is the width the counter-skewed picture
    // must overhang each side to still fill the slanted frame (tan·height).
    readonly property real lean: 14
    readonly property int skewPad: Math.ceil(Math.tan(lean * Math.PI / 180) * 62)
    function shear(deg) { return Qt.matrix4x4(1, Math.tan(deg * Math.PI / 180), 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1); }

    HudPanel {
        anchors.fill: parent
        cutTL: false; cutTR: true; cutBL: true; cutBR: false
        cut: 14
    }

    // folder tabs — one chip per subfolder (+ "misc" for loose files), with counts
    Row {
        id: tabs
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 4
        anchors.leftMargin: 22
        spacing: 2
        Repeater {
            model: Wallpapers.folders
            Chip {
                required property var modelData
                label: Wallpapers.folderLabel(modelData.name) + " " + modelData.count
                mini: true
                selected: modelData.name === Wallpapers.folder
                onClicked: Wallpapers.selectFolder(modelData.name)
            }
        }
        Rectangle { width: 1; height: 14; color: Theme.sel; anchors.verticalCenter: parent.verticalCenter }
        // accent follows the wallpaper (Theme.follow) — cyan/pink take the wallpaper's hues
        Chip {
            label: "◐ accent"
            mini: true
            selected: Theme.follow
            onClicked: Theme.toggleFollow()
        }
    }

    Text {
        id: hint
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 10
        anchors.rightMargin: 22
        text: ">hover previews< · <>click sets<>"
        color: Theme.dim2
        font.family: Theme.font
        font.pixelSize: 9
    }

    ListView {
        id: list
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 12
        orientation: ListView.Horizontal
        spacing: 26
        height: 66
        width: Math.min(contentWidth, strip.width - 60)
        clip: true
        model: Wallpapers.visibleFiles
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

            transform: Matrix4x4 { matrix: strip.shear(-strip.lean) }

            Item {
                anchors.fill: parent
                anchors.margins: 1
                clip: true
                Image {
                    x: -strip.skewPad
                    width: parent.width + 2 * strip.skewPad
                    height: parent.height
                    transform: Matrix4x4 { matrix: strip.shear(strip.lean) }
                    source: "file://" + Wallpapers.thumb(cardItem.modelData)
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
                text: cardItem.loading ? "loading…" : (Wallpapers.video(cardItem.modelData) ? "vid" : "gif")
                color: cardItem.loading ? Theme.pink : Theme.purple
                font.family: Theme.font
                font.pixelSize: 8
                transform: Matrix4x4 { matrix: strip.shear(strip.lean) }
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
                    Wallpapers.pick(cardItem.modelData);
                    strip.chosen();
                }
            }
        }
    }
}
