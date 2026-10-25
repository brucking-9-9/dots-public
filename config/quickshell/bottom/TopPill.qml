import QtQuick

// One of waybar's rounded module groups (#left, #right, #left-hidden-top…):
// module-bg, radius 15, the group's horizontal padding, modules in a row.
Rectangle {
    id: pill
    default property alias content: row.data
    property int padX: 10
    property int spacing: 0

    radius: Theme.topRadius
    color: Theme.moduleBg
    height: Theme.topH
    implicitWidth: row.width + 2 * padX

    Row {
        id: row
        x: pill.padX
        anchors.verticalCenter: parent.verticalCenter
        spacing: pill.spacing
    }
}
