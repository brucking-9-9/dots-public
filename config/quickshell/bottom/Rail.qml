import QtQuick
import "services"

// The idle 2 px rail: cyan segments are this output's workspaces (long =
// active, dim = empty, pink = urgent).
Item {
    id: rail
    required property string outputName
    property bool hidden: false
    readonly property real contentWidth: segs.width

    height: Theme.railH
    width: segs.width
    opacity: hidden ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: 250 } }

    Row {
        id: segs
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        spacing: 6

        Repeater {
            model: Niri.workspacesFor(rail.outputName)
            delegate: Item {
                id: seg
                required property var modelData
                readonly property bool active: modelData.is_active
                readonly property bool occupied: Niri.occupied(modelData.id)
                width: active ? 64 : 28
                height: Theme.railH
                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                Rectangle {   // glow
                    visible: seg.active
                    anchors.centerIn: parent
                    width: parent.width + 10
                    height: 6
                    radius: 3
                    color: Theme.cyan
                    opacity: 0.3
                }
                Rectangle {
                    anchors.fill: parent
                    color: seg.modelData.is_urgent ? Theme.pink : Theme.cyan
                    opacity: seg.active ? 1 : (seg.occupied ? 0.8 : 0.45)
                }
            }
        }
    }
}
