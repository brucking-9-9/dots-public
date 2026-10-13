import QtQuick

// Horizontal unfold: the child slides open from zero width with a fade.
Item {
    id: fold
    property bool open: true
    default property alias content: inner.data
    readonly property real fullWidth: inner.childrenRect.width
    width: open ? inner.childrenRect.width : 0
    height: inner.childrenRect.height
    opacity: open ? 1 : 0
    clip: true
    Behavior on width { NumberAnimation { duration: Theme.unfoldMs; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: Theme.unfoldMs } }
    Item {
        id: inner
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
}
