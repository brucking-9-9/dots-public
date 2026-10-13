import QtQuick

// Right-click menu for a chip. `ops` are plain strings (pin/unpin/left/right/
// close/kill); Bar maps them to actions.
Item {
    id: menu
    property var ops: []
    property real anchorX: 0
    signal activated(string op)

    width: col.implicitWidth + 22
    height: col.implicitHeight + 12
    x: Math.max(Theme.sideMargin, Math.min(anchorX - width / 2, (parent ? parent.width : 0) - Theme.sideMargin - width))

    HudPanel {
        anchors.fill: parent
        cut: 8
        edge: Theme.purple
        scanlines: false
        glow: 8
    }

    Column {
        id: col
        anchors.centerIn: parent
        spacing: 1
        Repeater {
            model: menu.ops
            Text {
                required property string modelData
                text: modelData === "unpin" ? "unpin"
                    : modelData === "left" ? "◀ move"
                    : modelData === "right" ? "move ▶"
                    : modelData === "close" ? "close"
                    : modelData === "kill" ? "kill -9"
                    : "pin"
                readonly property bool danger: modelData === "kill"
                color: h.hovered ? (danger ? Theme.pink : Theme.cyan) : (danger ? Theme.dim2 : Theme.fg)
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                leftPadding: 6; rightPadding: 6; topPadding: 2; bottomPadding: 2
                HoverHandler { id: h }
                TapHandler { onTapped: menu.activated(modelData) }
            }
        }
    }
}
