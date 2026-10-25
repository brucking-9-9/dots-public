pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen backlight level for the top bar's icon and slider. Seeded from sysfs
// once; every change this box makes afterwards goes through Osd (the niri
// binds, the slider below), which reads brightnessctl's result back into
// Osd.screenLevel. The slider floor is waybar's backlight/slider min of 5.
Singleton {
    id: root

    property real level: 0   // 0..1

    Process {
        running: true
        command: ["bash", "-c", "read -r b < /sys/class/backlight/acpi_video0/brightness; read -r m < /sys/class/backlight/acpi_video0/max_brightness; echo $((b * 1000 / m))"]
        stdout: StdioCollector { onStreamFinished: { const v = Number(text.trim()); if (!isNaN(v)) root.level = v / 1000; } }
    }
    Connections {
        target: Osd
        function onScreenLevelChanged() { root.level = Osd.screenLevel; }
    }

    function set(pct) { Osd.setScreen(Math.max(5, Math.min(100, Math.round(pct))), true); }
    function step(notches) { set(level * 100 + 2 * notches); }   // waybar scroll-step 2
}
