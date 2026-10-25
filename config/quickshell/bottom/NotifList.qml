import QtQuick
import "services"

// ✉ dropdown: open notifications first (chips = actions, [x] dismisses), then
// the history (dim, with the time; tap re-shows it as a popup). Left click on
// an open row dismisses it, right click on any row goes to its window. [clear]
// wipes both. Lives inside the 300 px bar surface, so six rows and a "+N more".
Item {
    id: list
    property bool open: false
    width: 380
    height: col.implicitHeight + 24
    opacity: open ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 180 } }
    readonly property bool hovered: hover.hovered
    HoverHandler { id: hover }

    readonly property var rows: Notif.live.concat(Notif.history).slice(0, 6)

    function clock(t) {
        const d = new Date(t);
        return (d.getHours() < 10 ? "0" : "") + d.getHours() + ":" + (d.getMinutes() < 10 ? "0" : "") + d.getMinutes();
    }

    HudPanel {
        anchors.fill: parent
        cutTL: true; cutTR: false; cutBL: false; cutBR: true
        cut: 10
        edge: Theme.pink
        glow: 12
    }

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 6

        Item {
            width: parent.width
            height: 16
            Text {
                anchors.left: parent.left
                text: Notif.live.length + " open · " + Notif.history.length + " past"
                      + (Notif.dnd ? " · dnd" : "") + (Notif.silent ? " · muted" : "")
                color: Theme.pink
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
                font.letterSpacing: 1
            }
            Text {
                anchors.right: parent.right
                text: "[clear]"
                color: da.hovered ? Theme.fg : Theme.dim2
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
                HoverHandler { id: da }
                TapHandler { onTapped: Notif.clear() }
            }
        }

        Repeater {
            model: list.rows
            Item {
                id: row
                required property var modelData
                readonly property var e: modelData
                readonly property bool isLive: !!e.n
                width: col.width
                height: rowTxt.implicitHeight
                HoverHandler { id: rh }
                TapHandler { acceptedButtons: Qt.LeftButton; onTapped: row.isLive ? Notif.dismiss(row.e) : Notif.restore(row.e) }
                TapHandler { acceptedButtons: Qt.RightButton; onTapped: Notif.goTo(row.e) }
                Column {
                    id: rowTxt
                    anchors.left: parent.left
                    anchors.right: rowEnd.left
                    anchors.rightMargin: 8
                    spacing: 1
                    Text {
                        width: parent.width
                        text: (row.e.app ? row.e.app + " · " : "") + row.e.summary
                        textFormat: Text.PlainText
                        color: row.isLive ? (row.e.urgency === 2 ? Theme.yellow : Theme.fg) : (rh.hovered ? Theme.fg : Theme.dim2)
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        visible: row.e.body.length > 0
                        text: row.e.body
                        textFormat: Text.StyledText
                        color: row.isLive ? Theme.dim2 : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 2
                        elide: Text.ElideRight
                    }
                    Row {
                        visible: row.isLive && row.e.actions.length > 0
                        spacing: 8
                        Repeater {
                            model: row.e.actions
                            Text {
                                id: act
                                required property var modelData
                                text: "[" + act.modelData.text + "]"
                                color: ah.hovered ? Theme.fg : Theme.pink
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 1
                                HoverHandler { id: ah }
                                TapHandler { onTapped: Notif.invoke(row.e, act.modelData.id) }
                            }
                        }
                    }
                }
                Text {   // [x] on an open row, the time on a past one
                    id: rowEnd
                    anchors.right: parent.right
                    anchors.top: parent.top
                    text: row.isLive ? "[x]" : list.clock(row.e.time)
                    color: row.isLive ? (xh.hovered ? Theme.pink : Theme.dim2) : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                    HoverHandler { id: xh; enabled: row.isLive }
                    TapHandler { enabled: row.isLive; onTapped: Notif.dismiss(row.e) }
                }
            }
        }

        Text {
            visible: Notif.pending > 6
            text: "+" + (Notif.pending - 6) + " more"
            color: Theme.dim2
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }
        Text {
            visible: Notif.pending === 0
            text: "nothing pending"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }
    }
}
