pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// The interface behind the default route — what waybar's network module
// shows — read from /proc/net/route every 10 s (lowest metric wins), matched
// to Quickshell's NetworkManager device for its type and wifi network. The
// same loop samples the interface's rx/tx bytes (bandwidth over the interval)
// and, for wifi, the frequency (nmcli) and signal in dBm (/proc/net/wireless),
// which waybar's tooltip-format prints.
Singleton {
    id: root

    property string iface: ""
    property real upBps: 0        // bytes/s over the last interval
    property real downBps: 0
    property real freqGHz: 0      // wifi, 0 when not
    property int dbm: -90         // wifi signal
    // waybar: 100 - 70 * (max - dBm) / (max - floor), dBm clamped to [-90, -20]
    readonly property int strengthDbm: 100 - 70 * (-20 - Math.max(-90, Math.min(-20, dbm))) / 70
    // waybar's pow_format: 1000-based k/M/G, one decimal once scaled
    function pow(v, unit) {
        const p = ["", "k", "M", "G", "T"]; let i = 0;
        while (i < p.length - 1 && v >= 1000) { v /= 1000; i++; }
        return (i ? v.toFixed(1) : Math.round(v)) + p[i] + unit;
    }
    readonly property var device: {
        const n = iface;
        return n ? (Networking.devices.values.find(d => d.name === n) || null) : null;
    }
    readonly property bool up: device !== null
    readonly property bool wired: up && device.type === DeviceType.Wired
    readonly property bool wifi: up && device.type === DeviceType.Wifi
    readonly property var wifiNetwork: wifi ? (device.networks.values.find(n => n.connected) || null) : null
    readonly property string essid: wifiNetwork ? wifiNetwork.name : ""
    readonly property bool wifiEnabled: Networking.wifiEnabled

    function setWifi(on) { Networking.wifiEnabled = on; }

    Process {
        id: route
        running: true
        command: ["bash", "-c", `
prev=; prx=0; ptx=0; pts=0
while :; do
  best=; bm=
  while read -r i d g f r u m _; do
    [ "$d" = 00000000 ] || continue
    [ $((0x$f & 2)) -ne 0 ] || continue
    if [ -z "$bm" ] || [ "$m" -lt "$bm" ]; then best=$i; bm=$m; fi
  done < /proc/net/route
  up=0; down=0; freq=0; dbm=-90; now=$(date +%s)
  if [ -n "$best" ]; then
    read -r rx < /sys/class/net/$best/statistics/rx_bytes 2>/dev/null || rx=0
    read -r tx < /sys/class/net/$best/statistics/tx_bytes 2>/dev/null || tx=0
    if [ "$best" = "$prev" ] && [ "$now" -gt "$pts" ]; then up=$(( (tx-ptx)/(now-pts) )); down=$(( (rx-prx)/(now-pts) )); fi
    prev=$best; prx=$rx; ptx=$tx; pts=$now
    if [ -d /sys/class/net/$best/wireless ]; then
      while read -r n _ _ lvl _; do [ "\${n%:}" = "$best" ] && { dbm=\${lvl%.*}; break; }; done < <(tail -n +3 /proc/net/wireless)
      # no sed on the unit PATH: pick the active row and keep the leading digits of "5180 MHz"
      while IFS=: read -r a fr _; do [ "$a" = yes ] && { fr=\${fr%%[^0-9]*}; [ -n "$fr" ] && freq=$fr; break; }; done < <(nmcli -t -f ACTIVE,FREQ dev wifi 2>/dev/null)
    fi
  fi
  echo "{\\"iface\\":\\"$best\\",\\"up\\":$up,\\"down\\":$down,\\"freq\\":$freq,\\"dbm\\":$dbm}"
  sleep 10
done`]
        stdout: SplitParser {
            onRead: line => {
                let s; try { s = JSON.parse(line); } catch (e) { return; }
                root.iface = s.iface; root.upBps = s.up; root.downBps = s.down;
                root.freqGHz = s.freq / 1000; root.dbm = s.dbm;
            }
        }
        onExited: restart.start()
    }
    Timer { id: restart; interval: 3000; onTriggered: route.running = true }
}
