import QtQuick
import "services"

// Vertical launcher results, rising above the apps island while the prompt
// has text. Index 0 is the top row (Down/Tab walk downwards); hover moves
// the selection, click launches, right-click asks to pin.
Item {
    id: list
    property bool open: false
    property var results: []
    property int selected: 0
    signal activated(int index)
    signal pinRequested(var entry, Item row)
    signal hoverSelected(int index)

    readonly property bool hovered: hover.hovered
    readonly property int rowH: 24
    width: Math.max(220, Math.min(Theme.launcherMaxW, measure.implicitWidth + 60))
    Column {   // widest row at full length (the rows themselves stretch to the list)
        id: measure
        visible: false
        Repeater {
            model: list.results
            Text { required property var modelData
                   text: modelData.name + "  " + (modelData.genericName || "")
                   font.family: Theme.font; font.pixelSize: Theme.fontSize }
        }
    }
    height: col.implicitHeight + 20
    opacity: open ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 180 } }
    HoverHandler { id: hover }

    HudPanel {
        anchors.fill: parent
        cutTL: true; cutTR: true; cutBL: false; cutBR: false
        cut: 10
        edge: Theme.cyan
        glow: 4
    }

    Column {
        id: col
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 10
        spacing: 0

        Repeater {
            model: list.results
            Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool sel: index === list.selected
                width: list.width - 20
                height: list.rowH
                implicitWidth: line.implicitWidth + 16

                Rectangle {   // selection bar
                    anchors.fill: parent
                    color: Theme.sel
                    opacity: row.sel ? 0.55 : 0
                    Behavior on opacity { NumberAnimation { duration: 90 } }
                }
                Rectangle {   // neon tick on the selected row
                    width: 2; height: parent.height - 6
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.cyan
                    visible: row.sel
                }
                Row {
                    id: line
                    anchors.verticalCenter: parent.verticalCenter
                    x: 10
                    spacing: 8
                    NeonText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.name
                        color: row.sel ? Theme.cyan : Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        glow: row.sel ? 0.8 : 0
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: text.length > 0
                        text: row.modelData.genericName || ""
                        color: Theme.dim2
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 2
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 200)
                    }
                    Text {   // already pinned
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Pins.isPinned(Apps.appId(row.modelData))
                        text: "⚲"
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 3
                    }
                }
                HoverHandler { onHoveredChanged: if (hovered) list.hoverSelected(row.index) }
                TapHandler { acceptedButtons: Qt.LeftButton; onTapped: list.activated(row.index) }
                TapHandler { acceptedButtons: Qt.RightButton; onTapped: list.pinRequested(row.modelData, row) }
            }
        }
    }
}
