import QtQuick

// One HUD island. Always visible at mini height on the bottom edge; `expanded`
// grows it to the full height while its content unfolds (the content items
// react to the same flag) and scales up slightly.
Item {
    id: island
    default property alias content: inner.data
    property bool expanded: false
    property real expandedWidth: implicitWidth     // predicted full width, set by Bar
    readonly property bool hovered: hover.hovered

    implicitWidth: inner.width * inner.scale + 2 * Theme.panelPad
    height: expanded ? Theme.panelH : Theme.miniH
    Behavior on height { NumberAnimation { duration: Theme.unfoldMs; easing.type: Easing.OutCubic } }

    HoverHandler { id: hover }
    HudPanel {
        anchors.fill: parent
        glow: island.expanded ? 1 : 0.7
        Behavior on glow { NumberAnimation { duration: Theme.unfoldMs } }
        sides: island.expanded ? 0 : 1
        Behavior on sides { NumberAnimation { duration: Theme.unfoldMs } }
    }

    Item {
        id: inner
        x: Theme.panelPad
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: Theme.panelH
        scale: island.expanded ? 1 : Theme.miniScale
        transformOrigin: Item.Left
        Behavior on scale { NumberAnimation { duration: Theme.unfoldMs; easing.type: Easing.OutCubic } }
    }
}
