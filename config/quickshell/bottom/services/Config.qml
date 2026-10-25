pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Tunables written by quickshell-bottom.nix into
// ~/.config/quickshell-bottom/config.json. The defaults below make a live
// `quickshell -p <dir>` run work before the file exists.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    property bool ready: false

    readonly property var defaultPins: adapter.defaultPins
    readonly property string wallpaperDir: adapter.wallpaperDir
    readonly property QtObject schedule: adapter.schedule
    readonly property string chime: adapter.chime
    readonly property var dynamicDarkPhases: adapter.dynamicDarkPhases   // phases showing a Dynamic pair's Dark member

    FileView {
        path: root.home + "/.config/quickshell-bottom/config.json"
        printErrors: false
        onLoaded: root.ready = true
        onLoadFailed: root.ready = true

        JsonAdapter {
            id: adapter
            property list<string> defaultPins: ["obsidian", "steam", "firefox", "kitty"]
            property string wallpaperDir: root.home + "/Pictures/Wallpapers"
            property string chime: "/run/current-system/sw/share/sounds/freedesktop/stereo/message-new-instant.oga"
            property list<string> dynamicDarkPhases: ["dusk", "night"]
            property JsonObject schedule: JsonObject {
                property string day: "07:30"
                property string dusk: "18:30"
                property string night: "20:30"
                property int dayK: 6500
                property int duskK: 4500
                property int nightK: 3000
                property int rampMin: 30
            }
        }
    }
}
