import QtQuick
import "services"

// Short, long now-playing strip: 24 cava bars, a scrolling "artist — title",
// then output volume and microphone controls. Click the bars/title to toggle
// play/pause; hovering raises the MediaCard (handled by Bar). Volume: wheel
// adjusts, click mutes. Mic: wheel adjusts, click mutes.
Item {
    id: island
    readonly property var player: Media.player
    readonly property bool hovered: hover.hovered
    implicitWidth: row.implicitWidth
    implicitHeight: Theme.panelH

    HoverHandler { id: hover }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Item {   // bars + title: click toggles playback
            width: play.implicitWidth
            height: Theme.panelH
            TapHandler { onTapped: if (island.player) island.player.togglePlaying() }
            Row {
                id: play
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    height: 14
                    Repeater {
                        model: 24
                        Item {
                            required property int index
                            anchors.bottom: parent.bottom
                            width: 3
                            height: 2 + 12 * (Media.level(Math.floor(index * Media.levels.length / 24)) / 100)
                            opacity: Media.barsActive ? 1 : 0.35
                            Behavior on height { NumberAnimation { duration: 50 } }
                            Rectangle { anchors.fill: parent; anchors.margins: -2; color: Theme.cyan; opacity: 0.3; radius: 2 }
                            Rectangle { anchors.fill: parent; color: Theme.cyan }
                        }
                    }
                }

                Text {
                    visible: island.player && !island.player.isPlaying
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⏸"
                    color: Theme.dim2
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                }

                Item {
                    id: box
                    readonly property int maxW: 300
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(maxW, title.implicitWidth)
                    height: title.implicitHeight
                    clip: true

                    Text {
                        id: title
                        textFormat: Text.StyledText
                        text: island.player
                            ? '<font color="' + Theme.purple + '">' + Media.esc(island.player.trackArtist) + '</font>'
                              + (island.player.trackArtist && island.player.trackTitle ? " — " : "")
                              + Media.esc(island.player.trackTitle)
                            : ""
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize

                        readonly property bool overflow: implicitWidth > box.maxW
                        SequentialAnimation on x {
                            running: title.overflow && island.visible
                            loops: Animation.Infinite
                            PauseAnimation { duration: 1800 }
                            NumberAnimation { to: box.maxW - title.implicitWidth; duration: Math.max(800, (title.implicitWidth - box.maxW) * 28) }
                            PauseAnimation { duration: 1500 }
                            NumberAnimation { to: 0; duration: 350; easing.type: Easing.InOutQuad }
                        }
                        onOverflowChanged: if (!overflow) x = 0
                    }
                }
            }
        }

        Rectangle { width: 1; height: 14; color: Theme.sel; anchors.verticalCenter: parent.verticalCenter }

        Row {   // output volume
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5
            NeonText {
                anchors.verticalCenter: parent.verticalCenter
                text: Audio.muted ? "\u{f0581}" : (Audio.volume < 0.34 ? "\u{f057f}" : Audio.volume < 0.67 ? "\u{f0580}" : "\u{f057e}")   // nf-md volume glyphs by escape
                color: Audio.muted ? Theme.pink : (vh.hovered ? Theme.fg : Theme.cyan)
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 2
                glow: Audio.muted ? 0.6 : 0.35
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Audio.pct(Audio.volume)
                color: Audio.muted ? Theme.dim : Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
            }
            HoverHandler { id: vh }
            TapHandler { onTapped: Audio.toggleMute() }
            WheelHandler { acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad; onWheel: ev => Audio.changeVolume(Audio.wheelStep(ev)) }
        }

        Row {   // microphone
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5
            NeonText {
                anchors.verticalCenter: parent.verticalCenter
                text: Audio.micMuted ? "\u{f036d}" : "\u{f036c}"   // nf-md microphone glyphs by escape
                color: Audio.micMuted ? Theme.pink : (mh.hovered ? Theme.fg : Theme.green)
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 2
                glow: Audio.micMuted ? 0.6 : 0.35
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Audio.pct(Audio.micVolume)
                color: Audio.micMuted ? Theme.dim : Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
            }
            HoverHandler { id: mh }
            TapHandler { onTapped: Audio.toggleMicMute() }
            WheelHandler { acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad; onWheel: ev => Audio.changeMic(Audio.wheelStep(ev)) }
        }
    }
}
