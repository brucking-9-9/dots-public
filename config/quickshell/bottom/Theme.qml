pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Palette = kitty "cyberpunk" (source of truth per the rice skill); the
// same hexes live in waybar/colors/colors.css.
//
// Optional "follow wallpaper" accent (Oct 2026): when `follow` is on, `cyan`
// and `pink` become tones of the wallpaper's dominant hue and of matugen's
// tertiary hue for it (Material tonal ladder: same hue+chroma, perceptual
// tone; tone 70 ≈ 8.5:1 on bg for every hue). The colours come from
// ~/.local/state/wallpaper/accent-colors.json, written by the
// `wallpaper-accent` script (quickshell-bottom.nix) on every pick and on
// toggle; the same script feeds niri's focus ring (tone 60) through an
// included kdl. Tokens: accentText (70, → cyan) · accent (60, ring/glow) ·
// accent2 (60, → pink) · accent2Text (70). accentHi (90) and accentDim (35)
// are read from the file and exported, but nothing uses them yet beyond the
// `accentinfo` IPC (hover stays Theme.fg, fills Theme.sel). Everything else
// (bg, purple, yellow, kitty, waybar, …) stays fixed.
// Toggle: the ◐ chip in the wallpaper strip or `qs ipc -c bottom call bar accent`;
// persisted in ~/.local/state/wallpaper/accent.json.
Singleton {
    id: theme

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/wallpaper"
    property bool follow: false
    property color accent: "#00ffc8"      // tone 60 — ring, glow
    property color accentText: "#00ffc8"  // tone 70 — text
    property color accentHi: "#00ffc8"    // tone 90 — hover / highlight
    property color accentDim: "#563466"   // tone 35 — fills
    property color accent2: "#ff0055"     // tertiary hue, tone 60
    property color accent2Text: "#ff0055" // tertiary hue, tone 70
    property bool accentOk: false

    FileView {
        id: palette
        path: theme.stateDir + "/accent-colors.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const c = JSON.parse(text());
                const hex = v => /^#[0-9a-f]{6}$/i.test(v);
                if (!hex(c.accent) || !hex(c.accent2)) throw "bad";
                theme.accent      = c.accent;
                theme.accentText  = hex(c.accentText)  ? c.accentText  : c.accent;
                theme.accentHi    = hex(c.accentHi)    ? c.accentHi    : c.accent;
                theme.accentDim   = hex(c.accentDim)   ? c.accentDim   : "#563466";
                theme.accent2     = c.accent2;
                theme.accent2Text = hex(c.accent2Text) ? c.accent2Text : c.accent2;
                theme.accentOk = true;
            } catch (e) { theme.accentOk = false; }
        }
        onLoadFailed: theme.accentOk = false
    }

    FileView {
        id: followFile
        path: theme.stateDir + "/accent.json"
        printErrors: false
        onLoaded: theme.follow = adapter.follow
        JsonAdapter { id: adapter; property bool follow: false }
    }
    function toggleFollow() {
        follow = !follow;
        adapter.follow = follow;
        followFile.writeAdapter();
        // niri's focus ring follows through the script's kdl; pass the flag so it needn't re-read accent.json
        Quickshell.execDetached(["wallpaper-accent", "--follow", follow ? "on" : "off"]);
    }

    readonly property color bg:     "#120b10"
    readonly property color panel:  Qt.alpha(bg, 0.92)
    readonly property color fg:     "#eeffff"
    readonly property color dim:    "#6d5a78"
    readonly property color dim2:   "#9a86a6"
    readonly property color sel:    "#563466"
    readonly property color cyan:   follow && accentOk ? accentText : "#00ffc8"
    readonly property color pink:   follow && accentOk ? accent2    : "#ff0055"
    readonly property color purple: "#d57bff"
    readonly property color yellow: "#f4ef00"
    readonly property color green:  "#00ff9c"
    readonly property color orange: "#ff9a3c"

    readonly property string font: "CaskaydiaCove Nerd Font Propo"
    readonly property int fontSize: 12

    // top bar (TopBar.qml): waybar's style.css / colors.css, one to one
    readonly property color moduleBg: Qt.alpha(bg, 0.9)
    readonly property color topRed: "#ff0055"      // fixed, unlike pink/cyan: waybar never followed the accent
    readonly property color topBlue: "#00ffc8"
    readonly property color topYellow: "#f4ef00"
    readonly property color topGreen: "#00ff9c"
    readonly property int topFontSize: 14
    readonly property int topIconSize: 16    // the <span size='12pt'> glyphs
    readonly property int topH: 20           // bar height; 5 px margin above and below, zone = 20 + top margin = 25
    readonly property int topMargin: 5
    readonly property int topRadius: 15
    readonly property int drawerMs: 500      // waybar's drawer transition-duration
    readonly property int sliderMs: 600      // …and the volume/backlight ones
    readonly property int sliderDelayMs: 450 // reveal-delay before a slider slides out

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
    readonly property int mediaZoneW: 320   // invisible centre zone for the player
    readonly property int stripH: 120       // wallpaper strip (tabs row + thumbnails)
    readonly property int windowH: 300      // whole layer surface; everything animates inside it
}
