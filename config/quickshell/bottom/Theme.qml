pragma Singleton
import QtQuick

// Palette = kitty "cyberpunk" (source of truth per the rice skill); the
// same hexes live in waybar/colors/colors.css.
QtObject {
    readonly property color bg:     "#120b10"
    readonly property color panel:  Qt.rgba(18 / 255, 11 / 255, 16 / 255, 0.92)
    readonly property color fg:     "#eeffff"
    readonly property color dim:    "#6d5a78"
    readonly property color dim2:   "#9a86a6"
    readonly property color sel:    "#563466"
    readonly property color cyan:   "#00ffc8"
    readonly property color pink:   "#ff0055"
    readonly property color purple: "#d57bff"
    readonly property color yellow: "#f4ef00"
    readonly property color green:  "#00ff9c"
    readonly property color orange: "#ff9a3c"

    readonly property string font: "CaskaydiaCove Nerd Font Propo"
    readonly property int fontSize: 12

    // geometry (logical px; the eDP-1 output runs at scale 1.75)
    readonly property int railH: 2          // idle workspace rail
    readonly property int hotH: 6           // hover-to-open strip
    readonly property int panelH: 46
    readonly property int panelMargin: 0    // flush with the bottom edge
    readonly property int panelPad: 18      // horizontal padding inside the panel
    readonly property int launcherMaxW: 560 // chips/results clip beyond this
    readonly property int sideMargin: 10
    readonly property int cut: 12           // angled corner size
    readonly property int miniH: 22         // minimized island (niri struts.bottom reserves it)
    readonly property real miniScale: 0.9   // content scale in mini mode (12 px → ~11 px text)
    readonly property int unfoldMs: 260
    readonly property int sysUnfoldExtra: 190   // width the sys island gains when unfolded (⬡, arc, :SS)
    readonly property int mediaZoneW: 320   // invisible centre zone for the player
    readonly property int stripH: 104       // wallpaper strip
    readonly property int windowH: 300      // whole layer surface; everything animates inside it
}
