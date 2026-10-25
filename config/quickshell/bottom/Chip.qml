import QtQuick

// A text chip in the launcher row. `number` is 1..9 (0 = none), `running`
// adds the ● dot, `current` paints it yellow (focused window), `dim` is for
// transient chips (running but not pinned).
Item {
    id: chip
    property string label: ""
    property int number: 0
    property bool running: false
    property bool current: false
    property bool dim: false
    property bool selected: false
    property bool mini: false          // no number / dot, used in the minimized island
    property bool shown: true          // false → folds to zero width
    property bool disabled: false      // greyed, ignores hover and clicks
    signal clicked()
    signal rightClicked()

    readonly property bool hovered: hover.hovered

    implicitWidth: row.implicitWidth + 12
    implicitHeight: 22
    width: shown ? implicitWidth : 0
    opacity: shown ? 1 : 0
    // leave the Row entirely once folded so its spacing is not kept either
    visible: shown || opacity > 0.01
    clip: true
    Behavior on width { NumberAnimation { duration: Theme.unfoldMs; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: Theme.unfoldMs } }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: !chip.disabled && (chip.hovered || chip.selected) ? Theme.cyan : "transparent"
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 3
        Text {
            visible: chip.number > 0 && !chip.mini
            text: chip.number + ":"
            color: Theme.sel
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }
        NeonText {
            anchors.verticalCenter: parent.verticalCenter
            text: chip.label
            color: chip.disabled ? Theme.sel
                 : chip.hovered || chip.selected ? Theme.cyan
                 : chip.current ? Theme.yellow
                 : chip.running ? Theme.fg
                 : chip.dim ? Theme.dim : Theme.dim2
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            glow: chip.disabled ? 0 : chip.hovered || chip.selected ? 0.9 : chip.current ? 0.6 : 0
        }
        Item {
            visible: chip.running && !chip.mini
            anchors.verticalCenter: parent.verticalCenter
            width: 5; height: 5
            Rectangle { anchors.centerIn: parent; width: 13; height: 13; radius: 6.5; color: dot.color; opacity: 0.25 }
            Rectangle { id: dot; anchors.fill: parent; radius: 2.5; color: chip.current ? Theme.yellow : Theme.cyan }
        }
    }

    HoverHandler { id: hover; enabled: !chip.disabled }
    TapHandler {
        enabled: !chip.disabled
        acceptedButtons: Qt.LeftButton
        onTapped: chip.clicked()
    }
    TapHandler {
        enabled: !chip.disabled
        acceptedButtons: Qt.RightButton
        onTapped: chip.rightClicked()
    }
}
