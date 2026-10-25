import QtQuick
import Quickshell
import "services"

// Right-click menu popup for the top bar (waybar's `menu` css): tooltip-bg,
// radius 10, bold fg rows, highlight on hover. Rows come from TopUi: a static
// list, or a tray item's DBus menu (QsMenuOpener; separators, check marks,
// submenus with a ‹ back row). Closes on a pick or once the pointer has been
// away from it for a moment.
PopupWindow {
    id: menu
    anchor.item: TopUi.menuItem
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 4
    // map only once the rows have settled: a DBus menu fills in after the
    // handle is set (and a submenu swaps the rows), and an xdg popup keeps the
    // size it was mapped with — so hide, let the rows land, show again
    property bool ready: false
    onRowsChanged: { ready = false; settle.restart(); }
    Timer { id: settle; interval: 80; onTriggered: menu.ready = true }
    visible: TopUi.menuItem !== null && ready && rows.length > 0
    color: "transparent"
    implicitWidth: col.width + 8
    implicitHeight: col.height + 8
    onVisibleChanged: if (visible) leave.restart()

    QsMenuOpener { id: opener; menu: TopUi.menuHandle }
    readonly property var rows: {
        if (TopUi.menuHandle === null) return TopUi.menuEntries;
        const out = opener.children.values.map(e => ({
            label: (e.checkState === Qt.Checked ? "\u{2713} " : "") + e.text + (e.hasChildren ? "  \u{203A}" : ""),
            enabled: e.enabled, separator: e.isSeparator, sub: e.hasChildren ? e : null,
            run: () => e.triggered()
        }));
        return TopUi.menuStack.length ? [{ label: "\u{2039} back", back: true }].concat(out) : out;
    }

    // widest label decides the row width (childrenRect would loop on the rows' own width)
    FontMetrics { id: fm; font.family: Theme.font; font.pixelSize: Theme.topFontSize; font.weight: Font.Bold }
    readonly property real rowW: rows.reduce((w, e) => Math.max(w, e.separator ? 0 : fm.advanceWidth(e.label)), 0) + 24

    Rectangle { anchors.fill: parent; radius: 10; color: Theme.moduleBg }
    HoverHandler { onHoveredChanged: hovered ? leave.stop() : leave.restart() }
    Timer { id: leave; interval: 1500; onTriggered: TopUi.closeMenu() }

    Column {
        id: col
        x: 4; y: 4
        Repeater {
            model: menu.rows
            delegate: Rectangle {
                id: rowItem
                required property var modelData
                readonly property bool sep: modelData.separator === true
                readonly property bool off: modelData.enabled === false
                width: menu.rowW
                height: sep ? 7 : t.implicitHeight + 6
                radius: 10
                color: !sep && !off && h.hovered ? Theme.sel : "transparent"
                Rectangle { visible: rowItem.sep; anchors.centerIn: parent; width: parent.width - 16; height: 1; color: Theme.dim }
                TopText {
                    id: t
                    visible: !rowItem.sep
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: 12; rightPadding: 12
                    text: rowItem.sep ? "" : rowItem.modelData.label
                    color: rowItem.off ? Theme.dim : Theme.fg
                }
                HoverHandler { id: h; enabled: !rowItem.sep && !rowItem.off }
                TapHandler {
                    enabled: !rowItem.sep && !rowItem.off
                    onTapped: {
                        const e = rowItem.modelData;
                        if (e.back) TopUi.popMenu();
                        else if (e.sub) TopUi.pushMenu(e.sub);
                        else { TopUi.closeMenu(); e.run(); }
                    }
                }
            }
        }
    }
}
