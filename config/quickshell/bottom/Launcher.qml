import QtQuick
import "services"

// Apps island content. One row that unfolds:
//   mini:   [ws segments] [running apps as plain labels]
//   full:   [> _ prompt] [ws segments] [pins (numbered, ● running)] [running-unpinned chips]
// Typing filters desktop entries: the chips fold away and Bar raises a
// vertical ResultList above the island. Enter launches the selected row,
// Tab/Up/Down move the selection, digits (with an empty prompt) activate pins.
// In mini mode names drop to three letters when the row would reach the
// media zone, and the row scrolls on the mouse wheel past that.
Item {
    id: launcher
    property bool expanded: false
    property string outputName: ""
    property real maxWidth: 600                    // from Bar: room before the media zone

    readonly property bool hasText: input.text.length > 0
    property int selected: 0
    readonly property var results: hasText ? Apps.search(input.text) : []
    readonly property var unpinnedRunning: Niri.runningAppIds.filter(a => !Pins.isPinned(a))
    readonly property var runningAll: Niri.runningAppIds

    signal escapePressed()
    signal launched()
    signal requestKeyboard()
    // kind: "pin" (data = index) | "transient" (data = appId) | "result" (data = DesktopEntry)
    signal menuRequested(string kind, var data, Item chip)

    implicitHeight: Theme.panelH
    implicitWidth: row.implicitWidth

    function focusInput() { input.forceActiveFocus(); }
    function clear() { input.text = ""; selected = 0; }
    function setText(t) { input.text = t; selected = 0; }
    function activate(i) {
        const e = results[i];
        if (!e) return;
        Apps.launch(e);
        launched();
    }
    onResultsChanged: selected = 0

    // predicted width once unfolded, so the media island can move out of the
    // way before the unfold starts (chips measured as text + chip padding)
    readonly property real expandedWidth: prompt.fullWidth + row.spacing + rail.width + row.spacing
        + Math.min(measureAll.implicitWidth + 24, Theme.launcherMaxW)
    Row {
        id: measureAll
        visible: false
        spacing: 6
        Repeater {
            model: Pins.pins
            Text { required property var modelData; required property int index
                   text: (index < 9 ? (index + 1) + ": " : "") + modelData.name + " ●"
                   font.family: Theme.font; font.pixelSize: Theme.fontSize; leftPadding: 6; rightPadding: 6 }
        }
        Repeater {
            model: launcher.unpinnedRunning
            Text { required property string modelData; text: modelData + " ●"
                   font.family: Theme.font; font.pixelSize: Theme.fontSize; leftPadding: 6; rightPadding: 6 }
        }
    }

    // mini-mode shortening: measure the running labels at full length
    readonly property real chipsAvail: Math.max(80, maxWidth - prompt.width - rail.width - 2 * row.spacing)
    readonly property bool shortNames: !expanded && measure.implicitWidth > chipsAvail
    function miniLabel(id) { return shortNames && id.length > 3 ? id.slice(0, 3) : id; }
    Row {
        id: measure
        visible: false
        spacing: 6
        Repeater {
            model: launcher.runningAll
            Text { required property string modelData; text: modelData; font.family: Theme.font; font.pixelSize: Theme.fontSize; leftPadding: 6; rightPadding: 6 }
        }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Fold {   // prompt
            id: prompt
            open: launcher.expanded
            anchors.verticalCenter: parent.verticalCenter
            Row {
                spacing: 8
                NeonText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ">"
                    color: Theme.cyan
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: true
                    glow: 0.8
                    TapHandler { onTapped: launcher.requestKeyboard() }
                }
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(input.contentWidth + 10, 14)
                    height: 20
                    TextInput {
                        id: input
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        cursorVisible: activeFocus
                        selectByMouse: false
                        Keys.onEscapePressed: launcher.escapePressed()
                        Keys.onPressed: e => {
                            if (!launcher.hasText && e.key >= Qt.Key_1 && e.key <= Qt.Key_9) {
                                Pins.activate(e.key - Qt.Key_1);
                                launcher.launched();
                                e.accepted = true;
                            } else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Down) {
                                if (launcher.results.length) launcher.selected = (launcher.selected + 1) % launcher.results.length;
                                e.accepted = true;
                            } else if (e.key === Qt.Key_Backtab || e.key === Qt.Key_Up) {
                                if (launcher.results.length) launcher.selected = (launcher.selected + launcher.results.length - 1) % launcher.results.length;
                                e.accepted = true;
                            }
                        }
                        onAccepted: launcher.activate(launcher.selected)
                    }
                    NeonText {   // blinking underscore while the prompt has no keyboard focus
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !input.activeFocus && !launcher.hasText
                        text: "_"
                        color: Theme.cyan
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize + 1
                        font.bold: true
                        glow: 0.8
                        SequentialAnimation on opacity {
                            running: visible
                            loops: Animation.Infinite
                            NumberAnimation { to: 0; duration: 500 }
                            NumberAnimation { to: 1; duration: 500 }
                        }
                    }
                    TapHandler { onTapped: launcher.requestKeyboard() }
                }
            }
        }

        Rail {
            id: rail
            outputName: launcher.outputName
            anchors.verticalCenter: parent.verticalCenter
        }

        Flickable {   // chips, wheel-scrollable when wider than the room available
            id: flick
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(chips.implicitWidth, launcher.expanded ? Theme.launcherMaxW : launcher.chipsAvail)
            height: 22
            contentWidth: chips.implicitWidth
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            interactive: false
            clip: true
            Behavior on width { NumberAnimation { duration: Theme.unfoldMs; easing.type: Easing.OutCubic } }
            WheelHandler {
                onWheel: ev => {
                    const d = ev.angleDelta.y !== 0 ? ev.angleDelta.y : ev.angleDelta.x;
                    flick.contentX = Math.max(0, Math.min(Math.max(0, flick.contentWidth - flick.width), flick.contentX - d / 2));
                }
            }

            Row {
                id: chips
                spacing: 6

                Repeater {   // pins: mini shows only the running ones
                    model: Pins.pins
                    Chip {
                        required property var modelData
                        required property int index
                        readonly property bool isRunning: Niri.hasWindow(modelData.appId)
                        label: launcher.miniLabel(modelData.name)
                        number: index < 9 ? index + 1 : 0
                        running: isRunning
                        current: Niri.sameApp(Niri.focusedAppId, modelData.appId)
                        mini: !launcher.expanded
                        shown: !launcher.hasText && (launcher.expanded || isRunning)
                        onClicked: { Pins.activate(index); launcher.launched(); }
                        onRightClicked: launcher.menuRequested("pin", index, this)
                    }
                }
                Repeater {   // running, not pinned
                    model: launcher.unpinnedRunning
                    Chip {
                        required property string modelData
                        label: launcher.miniLabel(modelData)
                        dim: launcher.expanded
                        running: true
                        current: Niri.focusedAppId === modelData
                        mini: !launcher.expanded
                        shown: !launcher.hasText
                        onClicked: { Niri.focusOrSpawn(modelData, [modelData]); launcher.launched(); }
                        onRightClicked: launcher.menuRequested("transient", modelData, this)
                    }
                }
            }
        }
    }
}
