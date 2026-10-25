pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Default output (sink) and microphone (source) volume/mute through
// Quickshell's Pipewire service. Nodes must be bound by a tracker before
// their audio properties are live.
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [root.sink, root.source] }

    readonly property bool sinkOk: sink !== null && sink.audio !== null
    readonly property bool sourceOk: source !== null && source.audio !== null
    readonly property real volume: sinkOk ? sink.audio.volume : 0
    readonly property bool muted: sinkOk ? sink.audio.muted : true
    readonly property real micVolume: sourceOk ? source.audio.volume : 0
    readonly property bool micMuted: sourceOk ? source.audio.muted : true

    function clamp(v) { return Math.max(0, Math.min(1, v)); }
    function changeVolume(d) { if (sinkOk) sink.audio.volume = clamp(sink.audio.volume + d); }
    function toggleMute() { if (sinkOk) sink.audio.muted = !sink.audio.muted; }
    function changeMic(d) { if (sourceOk) source.audio.volume = clamp(source.audio.volume + d); }
    function toggleMicMute() { if (sourceOk) source.audio.muted = !source.audio.muted; }

    function pct(v) { return Math.round(v * 100) + "%"; }

    // Wheel → notches, the one place every WheelHandler (TopModule, Launcher,
    // MediaIsland) normalises events: mouse wheels report angleDelta (120 per
    // notch); trackpads often report only pixelDelta, so fall back to it
    // (40 px ≈ one notch). Either axis counts.
    function wheelNotches(ev) {
        const a = ev.angleDelta.y !== 0 ? ev.angleDelta.y : ev.angleDelta.x;
        if (a !== 0) return a / 120;
        const p = ev.pixelDelta.y !== 0 ? ev.pixelDelta.y : ev.pixelDelta.x;
        return p / 40;
    }
    // …→ volume delta: one notch = 5 %
    function wheelStep(ev) { return wheelNotches(ev) * 0.05; }
}
