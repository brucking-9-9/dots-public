import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "services"

// Top-right notification popups, one layer surface per screen. Cards slide in
// from the right edge (critical ones flare), drain a timeout bar along the bottom
// (paused while hovered) and slide back out when they expire or are dismissed.
// Left click = dismiss, right click = go to the sender's window, chips =
// actions. Overlay layer (the only one niri draws above a fullscreen
// window), so cards still show over a game; mask keeps the rest click-through.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    // the surface is padded all round so the glow halo isn't clipped at its edges
    readonly property int pad: 16
    readonly property int cardW: 340
    anchors { top: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    implicitWidth: cardW + 2 * pad
    implicitHeight: Math.max(1, col.implicitHeight + 2 * pad)
    visible: Notif.popups.length > 0
    WlrLayershell.namespace: "qs-notifs"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: col }

    Column {
        id: col
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: win.pad
        width: win.cardW
        spacing: 8

        Repeater {
            model: Notif.popups
            Item {
                id: card
                required property var modelData
                readonly property var e: modelData
                readonly property bool leaving: Notif.closing.indexOf(e.key) >= 0
                readonly property color edge: e.urgency === 2 ? Theme.yellow : (e.urgency === 0 ? Theme.sel : Theme.cyan)
                width: col.width
                height: inner.implicitHeight + 20

                // slide: 1 = parked off the right edge; pulse: arrival flare
                property real slide: 1
                property real pulse: 1
                property real progress: 1
                x: slide * (width + 24)
                opacity: 1 - slide
                Behavior on slide { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on pulse { NumberAnimation { duration: 900; easing.type: Easing.OutQuad } }
                Component.onCompleted: { slide = 0; pulse = 0; }
                onLeavingChanged: if (leaving) slide = 1

                NumberAnimation {
                    id: drain
                    target: card; property: "progress"
                    from: 1; to: 0
                    duration: Math.max(1, e.timeout)
                    running: e.timeout > 0
                    onFinished: if (!card.leaving && card.progress === 0) Notif.expire(card.e)
                }
                HoverHandler { id: hover; onHoveredChanged: if (drain.running) drain.paused = hovered }
                TapHandler { acceptedButtons: Qt.LeftButton; onTapped: Notif.dismiss(e) }
                TapHandler { acceptedButtons: Qt.RightButton; onTapped: Notif.goTo(e) }

                HudPanel {
                    anchors.fill: parent
                    cutTL: true; cutTR: false; cutBL: false; cutBR: true
                    cut: 10
                    soft: true
                    fill: Qt.rgba(18 / 255, 11 / 255, 16 / 255, 0.72)   // see-through: don't hide what's behind
                    edge: card.edge
                    edgeWidth: e.urgency === 2 ? 1.6 : 1
                    // only critical glows (and flares on arrival); the rest keep a faint edge
                    glow: e.urgency === 2 ? 1.5 + card.pulse * 5 : 0.3
                }

                Row {
                    id: inner
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 8

                    Image {
                        id: img
                        visible: source != ""
                        source: e.image || e.icon
                        width: 28; height: 28
                        sourceSize: Qt.size(56, 56)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        // symbolic theme icons are near-black: tint them to the card's edge colour
                        layer.enabled: String(source).indexOf("-symbolic") !== -1
                        layer.effect: MultiEffect { colorization: 1; colorizationColor: card.edge; brightness: 1 }
                    }
                    Column {
                        width: inner.width - (img.visible ? img.width + inner.spacing : 0)
                        spacing: 2
                        Text {
                            width: parent.width
                            text: (e.urgency === 2 ? "⚠ " : "") + e.app
                            visible: e.app.length > 0
                            color: e.urgency === 2 ? Theme.yellow : (e.urgency === 0 ? Theme.dim : Theme.purple)
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 2
                            font.letterSpacing: 1
                            elide: Text.ElideRight
                        }
                        Item {
                            width: parent.width
                            height: neon.implicitHeight
                            clip: true
                            NeonText {
                                id: neon
                                anchors.left: parent.left
                                text: e.summary
                                color: e.urgency === 2 ? Theme.yellow : (e.urgency === 0 ? Theme.dim2 : Theme.cyan)
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize
                                font.bold: true
                                glow: e.urgency === 2 ? 0.3 + card.pulse * 0.4 : 0
                            }
                        }
                        Text {
                            width: parent.width
                            visible: e.body.length > 0
                            text: e.body
                            textFormat: Text.StyledText
                            color: e.urgency === 0 ? Theme.dim2 : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 1
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            linkColor: Theme.pink
                            onLinkActivated: link => Qt.openUrlExternally(link)
                        }
                        Row {
                            visible: e.actions.length > 0
                            spacing: 6
                            topPadding: 4
                            Repeater {
                                model: e.actions
                                Rectangle {
                                    id: chip
                                    required property var modelData
                                    width: chipTxt.implicitWidth + 16
                                    height: 20
                                    color: ch.hovered ? Qt.rgba(1, 0, 0.33, 0.18) : "transparent"
                                    border.color: Theme.pink
                                    border.width: 1
                                    Text {
                                        id: chipTxt
                                        anchors.centerIn: parent
                                        text: chip.modelData.text
                                        color: ch.hovered ? Theme.fg : Theme.pink
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize - 1
                                    }
                                    HoverHandler { id: ch }
                                    TapHandler { onTapped: Notif.invoke(card.e, chip.modelData.id) }
                                }
                            }
                        }
                    }
                }

                Rectangle {   // timeout drain
                    visible: e.timeout > 0
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 10
                    anchors.bottomMargin: 3
                    height: 1
                    width: (card.width - 20) * card.progress
                    color: card.edge
                    opacity: 0.5
                }
            }
        }
    }
}
