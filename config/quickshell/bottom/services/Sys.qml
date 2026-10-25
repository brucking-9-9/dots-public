pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// cpu / load / memory / core temperature / battery for the top bar (waybar's
// cpu, load, memory, temperature and battery modules). One shell loop prints
// a JSON line every 10 s; /proc files report size 0, so no FileView. The
// coretemp hwmon index changes between boots, hence the glob. Battery is
// sysfs like waybar's (no UPower daemon on this box): percent is
// charge_now/charge_full, time is charge/current.
Singleton {
    id: root

    property real cpu: 0        // 0..100, busy share of the last interval
    property var cores: []      // per-core busy %, same interval (the cpu tooltip)
    property real load1: 0
    property real load5: 0
    property real load15: 0
    property real memUsed: 0    // GiB, MemTotal - MemAvailable (what waybar shows)
    property real memTotal: 0
    property real memPct: 0
    property real temp: 0       // °C
    property bool batPresent: false
    property int batPct: 0
    property string batStatus: ""   // Charging | Discharging | Full | Not charging
    property int batSeconds: 0      // to empty (discharging) or to full (charging)
    property bool ok: false

    Process {
        id: sampler
        running: true
        command: ["bash", "-c", `
declare -A pt pi
while :; do
  cores=; cpu=0
  while read -r name u n s i w q sq st _; do
    case $name in cpu|cpu[0-9]*) ;; *) break ;; esac
    t=$((u+n+s+i+w+q+sq+st)); idle=$((i+w))
    dt=$((t-\${pt[$name]:-0})); di=$((idle-\${pi[$name]:-0}))
    v=0; [ "$dt" -gt 0 ] && v=$(( (dt-di)*100/dt ))
    pt[$name]=$t; pi[$name]=$idle
    if [ "$name" = cpu ]; then cpu=$v; else cores="$cores,$v"; fi
  done < /proc/stat
  cores="[\${cores#,}]"
  read -r l1 l5 l15 _ < /proc/loadavg
  tot=0; avail=0
  while read -r k v _; do case $k in MemTotal:) tot=$v;; MemAvailable:) avail=$v;; esac; done < /proc/meminfo
  temp=0; for f in /sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input; do [ -r "$f" ] && read -r temp < "$f" && break; done
  bp=0; bpct=0; bst=; bsec=0; b=/sys/class/power_supply/BAT0
  if [ -r $b/present ] && read -r bp < $b/present && [ "$bp" = 1 ]; then
    read -r bst < $b/status
    now=0; full=0; cur=0
    if [ -r $b/charge_now ]; then read -r now < $b/charge_now; read -r full < $b/charge_full; read -r cur < $b/current_now
    elif [ -r $b/energy_now ]; then read -r now < $b/energy_now; read -r full < $b/energy_full; read -r cur < $b/power_now; fi
    [ "$full" -gt 0 ] && bpct=$(( (now * 100 + full / 2) / full ))
    cur=$(( cur < 0 ? -cur : cur ))
    if [ "$cur" -gt 0 ]; then case $bst in Charging) bsec=$(( (full - now) * 3600 / cur ));; Discharging) bsec=$(( now * 3600 / cur ));; esac; fi
  fi
  echo "{\\"cpu\\":$cpu,\\"cores\\":$cores,\\"load1\\":$l1,\\"load5\\":$l5,\\"load15\\":$l15,\\"tot\\":$tot,\\"avail\\":$avail,\\"temp\\":$temp,\\"bp\\":$bp,\\"bpct\\":$bpct,\\"bst\\":\\"$bst\\",\\"bsec\\":$bsec}"
  sleep 10
done`]
        stdout: SplitParser { onRead: line => root.parse(line) }
        onExited: restart.start()
    }
    Timer { id: restart; interval: 3000; onTriggered: sampler.running = true }

    function parse(line) {
        let s;
        try { s = JSON.parse(line); } catch (e) { return; }
        cpu = s.cpu;
        cores = s.cores;
        load1 = s.load1;
        load5 = s.load5;
        load15 = s.load15;
        memTotal = s.tot / 1048576;
        memUsed = (s.tot - s.avail) / 1048576;
        memPct = s.tot > 0 ? (s.tot - s.avail) * 100 / s.tot : 0;
        temp = s.temp / 1000;
        batPresent = s.bp === 1;
        batPct = s.bpct;
        batStatus = s.bst;
        batSeconds = s.bsec;
        ok = true;
    }
}
