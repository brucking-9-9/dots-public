import QtQuick
import QtQuick.Effects

// Text with a blurred copy of itself behind it: the neon glow. `glow` is the
// halo opacity (0 disables the extra layer entirely).
Item {
    id: neon
    property alias text: t.text
    property alias color: t.color
    property alias font: t.font
    property alias textFormat: t.textFormat
    property alias horizontalAlignment: t.horizontalAlignment
    property real glow: 0.6
    property real blur: 0.8

    implicitWidth: t.implicitWidth
    implicitHeight: t.implicitHeight

    Text {
        id: halo
        anchors.centerIn: t
        text: t.text
        color: t.color
        font: t.font
        textFormat: t.textFormat
        padding: 12             // room for the blur inside the layer texture
        visible: neon.glow > 0
        opacity: neon.glow
        layer.enabled: neon.glow > 0
        layer.effect: MultiEffect { blurEnabled: true; blur: neon.blur; blurMax: 16 }
    }
    Text {
        id: t
        anchors.centerIn: parent
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
    }
}
