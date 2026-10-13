# ── Quiet mode — pin the fans low and cap the CPU, independent of ppd ─────
#
# `quiet on` makes the laptop as silent as it can be without cooking itself:
#
#   * fans     — both fans are switched to manual and pinned at their minimum
#                RPM (1250 / 1350 on this MacBookPro15,2; `quiet on 2000`
#                pins them higher). t2fanrd is stopped while the mode is on so
#                it doesn't fight over fan*_output.
#   * CPU      — the package power limit (Intel RAPL) is dropped from the
#                firmware's 100 W to pl1W (burst 1.5×), turbo is disabled and
#                intel_pstate is capped at maxPerfPct. Less power in → less
#                heat → the pinned-low fans are actually enough.
#   * safety   — a root "guard" loop (transient systemd unit `quiet-mode`)
#                re-asserts every knob every `tick` seconds (thermald, ppd,
#                firmware and suspend/resume all like to reset them) and
#                aborts the mode if the package hits tripC °C or if t2fanrd
#                gets restarted behind its back (e.g. by nixos-rebuild switch).
#                Restore runs from the unit's ExecStopPost, so it also happens
#                on `systemctl stop quiet-mode`, on a guard crash and on kill.
#
# `quiet on [rpm] [--cpu PCT] [--watts W]` — the optional knobs override the
# defaults below: fan rpm (clamped to the hardware range), CPU ceiling as a
# percentage of the 4.7 GHz max clock (10–100), and the package power limit
# in watts (3–28; the burst limit is 1.5×). Running `quiet on` again while
# the mode is active just adjusts the caps live, the guard applies them on
# its next tick.
# `quiet off` restores the saved fan/RAPL/pstate state and restarts t2fanrd.
# `quiet` / `quiet status` prints the current state; `quiet toggle` flips it.
#
# This is deliberately separate from power-profiles-daemon: ppd only moves
# the energy_performance_preference knob, which changes how eagerly the CPU
# boosts but never stops it from boosting. `powerprofilesctl set power-saver`
# is a complementary (not required) tweak while quiet mode is on.
#
# Privilege: everything that writes sysfs or talks to systemd runs in
# `quiet-root`, which the `quiet` wrapper invokes through sudo. A NOPASSWD
# rule for /etc/profiles/per-user/user/bin/quiet-root lives in
# configuration.nix (security.sudo.extraRules) so the waybar click and any
# keybind work without a prompt. That path is the home-manager profile,
# i.e. a file this user controls, so the rule is effectively passwordless
# root for this user — fine on a single-user laptop, but that's what it is.
#
# Waybar: `power-cycle` (below) backs the bar's custom/power module, which
# replaces waybar's built-in power-profiles-daemon module. Left-click cycles
# the ppd profiles as before (performance → balanced → power-saver);
# right-click toggles quiet mode on/off independently, and a speaker-off
# glyph is shown next to the profile icon while it is on. If the guard aborts quiet mode (thermal trip,
# t2fanrd restart) the icon falls back to the ppd profile on the next
# refresh.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # ── Tunables ────────────────────────────────────────────────────────────
  # Defaults; `quiet on --cpu N --watts W` overrides per run.
  pl1W = 10; # RAPL long-term package power in W (chip TDP is 28 W); burst is 1.5×
  maxPerfPct = 50; # intel_pstate ceiling, % of 4.7 GHz max → ~2.3 GHz
  tripC = 90; # package temperature (°C) that aborts quiet mode
  tick = 2; # guard loop period in seconds
  tripTicks = 5; # consecutive over-trip ticks before aborting (10 s)

  # ── Fixed sysfs locations on this box ───────────────────────────────────
  smc = "/sys/bus/acpi/devices/APP0001:00"; # applesmc fan nodes (stable alias)
  rapl = "/sys/class/powercap/intel-rapl:0"; # package-0
  pstate = "/sys/devices/system/cpu/intel_pstate";
  state = "/run/quiet-mode"; # saved pre-quiet values + active caps (tmpfs)
  unit = "quiet-mode";

  rootHelper = "${config.home.profileDirectory}/bin/quiet-root";

  quietRoot = pkgs.writeShellScriptBin "quiet-root" ''
    # Root side of quiet mode. Subcommands: on [rpm] | off | guard | restore
    PATH=${
      lib.makeBinPath (
        with pkgs;
        [
          coreutils
          systemd
          util-linux
          libnotify
        ]
      )
    }
    smc=${smc}; rapl=${rapl}; pstate=${pstate}; state=${state}; unit=${unit}

    log() { echo "quiet: $*"; }
    die() { echo "quiet: $*" >&2; exit 1; }

    # Write a sysfs value, log (not abort) on failure.
    w() { echo "$2" > "$1" 2>/dev/null || log "write $1 <- $2 failed"; }
    r() { cat "$1" 2>/dev/null; }

    # hwmon node of the "Package id 0" coretemp sensor.
    package_temp_file() {
      local h
      for h in /sys/class/hwmon/hwmon*; do
        [ "$(r "$h/name")" = coretemp ] || continue
        local l
        for l in "$h"/temp*_label; do
          [ "$(r "$l")" = "Package id 0" ] && { echo "''${l%_label}_input"; return; }
        done
        echo "$h/temp1_input"; return
      done
    }

    # Desktop notification to every logged-in graphical user (best effort).
    notify() {
      local bus uid user
      for bus in /run/user/*/bus; do
        [ -S "$bus" ] || continue
        uid=''${bus#/run/user/}; uid=''${uid%/bus}
        user=$(id -nu "$uid" 2>/dev/null) || continue
        runuser -u "$user" -- env DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" \
          notify-send -u critical -a quiet "$@" 2>/dev/null || true
      done
    }

    # Apply every cap. Returns 1 if t2fanrd is running (then we must not
    # touch the fans).
    apply() {
      systemctl is-active -q t2fanrd && return 1
      local n
      for n in 1 2; do
        w "$smc/fan''${n}_manual" 1
        w "$smc/fan''${n}_output" "$(r "$state/fan''${n}_cap")"
      done
      w "$rapl/constraint_0_power_limit_uw" "$(r "$state/pl1_cap")"
      w "$rapl/constraint_1_power_limit_uw" "$(r "$state/pl2_cap")"
      w "$pstate/no_turbo" 1
      w "$pstate/max_perf_pct" "$(r "$state/cpu_pct")"
      return 0
    }

    # Write the fan / CPU caps the guard applies each tick.
    write_caps() {
      local rpm=$1 pct=$2 watts=$3 n min max cap
      for n in 1 2; do
        min=$(r "$smc/fan''${n}_min"); max=$(r "$smc/fan''${n}_max")
        cap=''${rpm:-$min}
        (( cap < min )) && cap=$min
        (( cap > max )) && cap=$max
        echo "$cap" > "$state/fan''${n}_cap"
      done
      echo "$pct" > "$state/cpu_pct"
      echo $((watts * 1000000)) > "$state/pl1_cap"
      echo $((watts * 1500000)) > "$state/pl2_cap"
    }

    caps_summary() {
      echo "fans $(r "$state/fan1_cap")/$(r "$state/fan2_cap") rpm, CPU ≤$(r "$state/cpu_pct")% of max clock, $(( $(r "$state/pl1_cap") / 1000000 )) W / $(( $(r "$state/pl2_cap") / 1000000 )) W burst, turbo off"
    }

    cmd_on() {
      [ "$(id -u)" = 0 ] || die "must run as root (use the 'quiet' wrapper)"
      local rpm="" pct=${toString maxPerfPct} watts=${toString pl1W}
      while [ $# -gt 0 ]; do
        case "$1" in
          --cpu)   pct=''${2:-}; shift ;;
          --cpu=*) pct=''${1#--cpu=} ;;
          --watts)   watts=''${2:-}; shift ;;
          --watts=*) watts=''${1#--watts=} ;;
          -h|--help) echo "usage: quiet on [rpm] [--cpu PCT] [--watts W]"; exit 0 ;;
          -*) die "unknown option: $1" ;;
          *)  rpm=$1 ;;
        esac
        shift
      done
      [ -z "$rpm" ] || [[ $rpm =~ ^[0-9]+$ ]] || die "rpm must be a number: $rpm"
      if ! [[ $pct =~ ^[0-9]+$ ]] || (( pct < 10 || pct > 100 )); then
        die "--cpu must be 10–100 (percent of max clock): $pct"
      fi
      if ! [[ $watts =~ ^[0-9]+$ ]] || (( watts < 3 || watts > 28 )); then
        die "--watts must be 3–28: $watts"
      fi
      [ -e "$smc/fan1_output" ] || die "no applesmc fan nodes at $smc"

      if systemctl is-active -q "$unit"; then
        # Already on: just change the caps, the guard applies them next tick.
        write_caps "$rpm" "$pct" "$watts"
        log "adjusted — $(caps_summary)"
        exit 0
      fi

      # Save what we are about to change so restore can put it back.
      rm -rf "$state"; mkdir -p "$state"; chmod 755 "$state"
      local n
      for n in 1 2; do
        r "$smc/fan''${n}_manual" > "$state/fan''${n}_manual"
        r "$smc/fan''${n}_output" > "$state/fan''${n}_output"
      done
      write_caps "$rpm" "$pct" "$watts"
      r "$rapl/constraint_0_power_limit_uw" > "$state/pl1"
      r "$rapl/constraint_1_power_limit_uw" > "$state/pl2"
      r "$pstate/no_turbo" > "$state/no_turbo"
      r "$pstate/max_perf_pct" > "$state/max_perf_pct"

      systemd-run --quiet --unit="$unit" --collect \
        --description="Quiet mode: fans pinned, CPU capped" \
        -p ExecStopPost="${placeholder "out"}/bin/quiet-root restore" \
        "${placeholder "out"}/bin/quiet-root" guard \
        || die "could not start $unit"

      # The guard first stops t2fanrd (blocking), then applies the caps —
      # poll for up to ~5 s before judging whether they took.
      local nt
      for _ in $(seq 1 10); do
        [ "$(r "$pstate/no_turbo")" = 1 ] && break
        sleep 0.5
      done
      nt=$(r "$pstate/no_turbo")
      log "on — $(caps_summary)"
      [ "$nt" = 1 ] || log "warning: no_turbo did not stick (kernel may make it read-only)"
    }

    cmd_off() {
      [ "$(id -u)" = 0 ] || die "must run as root (use the 'quiet' wrapper)"
      if ! systemctl is-active -q "$unit"; then
        log "already off"
        exit 0
      fi
      systemctl stop "$unit"   # ExecStopPost → restore
      log "off — fans back to t2fanrd, CPU limits restored"
    }

    # Runs as the transient unit's main process.
    cmd_guard() {
      trap 'exit 0' TERM INT
      [ -s "$state/fan1_cap" ] && [ -s "$state/cpu_pct" ] && [ -s "$state/pl1_cap" ] || die "no saved caps in $state — run 'quiet on'"
      systemctl stop t2fanrd
      local tf t hot=0
      tf=$(package_temp_file)
      log "guard started: $(caps_summary); trip ${toString tripC} °C for ${toString tripTicks} ticks (sensor $tf)"
      while :; do
        if ! apply; then
          log "t2fanrd is active again — leaving quiet mode"
          notify "Quiet mode ended" "t2fanrd was restarted; fans are back on the normal curve."
          exit 0
        fi
        # The package is often still hot from whatever ran before `quiet on`;
        # give the caps a few ticks to bite before treating it as a failure.
        t=$(( $(r "$tf" || echo 0) / 1000 ))
        if (( t >= ${toString tripC} )); then
          hot=$((hot + 1))
          log "package at ''${t} °C ≥ ${toString tripC} °C ($hot/${toString tripTicks})"
          if (( hot >= ${toString tripTicks} )); then
            log "still too hot — aborting quiet mode"
            notify "Quiet mode aborted" "CPU package held ''${t} °C for $((hot * ${toString tick})) s. Fans handed back to t2fanrd."
            exit 0
          fi
        else
          hot=0
        fi
        sleep ${toString tick}
      done
    }

    # ExecStopPost of the unit: undo everything, in a safe order.
    cmd_restore() {
      local n
      for n in 1 2; do
        # Fans first: back to whatever mode/output they had, then t2fanrd
        # takes over anyway.
        [ -s "$state/fan''${n}_output" ] && w "$smc/fan''${n}_output" "$(r "$state/fan''${n}_output")"
        w "$smc/fan''${n}_manual" "$(r "$state/fan''${n}_manual" || echo 0)"
      done
      systemctl start --no-block t2fanrd
      if [ -s "$state/pl1" ]; then
        w "$rapl/constraint_0_power_limit_uw" "$(r "$state/pl1")"
        w "$rapl/constraint_1_power_limit_uw" "$(r "$state/pl2")"
      else
        log "no saved RAPL limits — leaving power caps untouched"
      fi
      w "$pstate/no_turbo" "$(r "$state/no_turbo" || echo 0)"
      w "$pstate/max_perf_pct" "$(r "$state/max_perf_pct" || echo 100)"
      rm -rf "$state"
      log "restored"
    }

    case "''${1:-}" in
      on)      shift; cmd_on "$@" ;;
      off)     cmd_off ;;
      guard)   cmd_guard ;;
      restore) cmd_restore ;;
      *) echo "usage: quiet-root on [rpm] [--cpu PCT] [--watts W] | off | guard | restore" >&2; exit 2 ;;
    esac
  '';

  quiet = pkgs.writeShellScriptBin "quiet" ''
    # User-facing wrapper: status needs no root, everything else sudos.
    # /run/wrappers/bin holds the setuid sudo; the one in pkgs.sudo isn't.
    PATH=/run/wrappers/bin:${
      lib.makeBinPath (
        with pkgs;
        [
          coreutils
          systemd
        ]
      )
    }:$PATH
    smc=${smc}; rapl=${rapl}; pstate=${pstate}; state=${state}; unit=${unit}
    root=${rootHelper}

    r() { cat "$1" 2>/dev/null; }

    status() {
      if systemctl is-active -q "$unit"; then
        echo "quiet mode: ON  (fans pinned at $(r "$state/fan1_cap")/$(r "$state/fan2_cap") rpm, CPU ≤$(r "$state/cpu_pct")% / $(( $(r "$state/pl1_cap" || echo 0) / 1000000 )) W, turbo off)"
      else
        echo "quiet mode: OFF (t2fanrd $(systemctl is-active t2fanrd))"
      fi
      local n
      for n in 1 2; do
        printf '  fan%s  %5s rpm  (target %s, manual=%s, range %s–%s)\n' "$n" \
          "$(r "$smc/fan''${n}_input")" "$(r "$smc/fan''${n}_output")" \
          "$(r "$smc/fan''${n}_manual")" "$(r "$smc/fan''${n}_min")" "$(r "$smc/fan''${n}_max")"
      done
      local pkg
      for h in /sys/class/hwmon/hwmon*; do
        [ "$(r "$h/name")" = coretemp ] && { pkg=$(r "$h/temp1_input"); break; }
      done
      printf '  cpu   %s °C  PL1 %s W / PL2 %s W  no_turbo=%s  max_perf=%s%%  epp=%s\n' \
        "$(( ''${pkg:-0} / 1000 ))" \
        "$(( $(r "$rapl/constraint_0_power_limit_uw" || echo 0) / 1000000 ))" \
        "$(( $(r "$rapl/constraint_1_power_limit_uw" || echo 0) / 1000000 ))" \
        "$(r "$pstate/no_turbo")" "$(r "$pstate/max_perf_pct")" \
        "$(r /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference)"
    }

    case "''${1:-status}" in
      on)     shift; exec sudo "$root" on "$@" ;;
      off)    exec sudo "$root" off ;;
      toggle) if systemctl is-active -q "$unit"; then exec sudo "$root" off
              else shift; exec sudo "$root" on "$@"; fi ;;
      status|"") status ;;
      log)    exec journalctl -u "$unit" -n "''${2:-20}" --no-pager ;;
      -h|--help|help)
        cat <<EOF
    usage: quiet [status]        show fan / CPU state
           quiet on [rpm] [--cpu PCT] [--watts W]
                                 pin fans (default: minimum rpm) + cap CPU (sudo)
                                   --cpu    ceiling in % of max clock, 10–100 (default ${toString maxPerfPct})
                                   --watts  package power limit, 3–28 W (default ${toString pl1W})
                                 re-run while on to adjust the caps live
           quiet off             restore fans to t2fanrd, lift CPU caps (sudo)
           quiet toggle [args]   on ↔ off (args as for 'on')
           quiet log [n]         last n lines of the guard's journal
    EOF
        ;;
      *) echo "quiet: unknown command '$1' (try: quiet help)" >&2; exit 2 ;;
    esac
  '';
  powerCycle = pkgs.writeShellScriptBin "power-cycle" ''
    # Waybar custom/power backend. `power-cycle` prints the module JSON;
    # `power-cycle next` advances the cycle; `power-cycle toggle` flips quiet.
    PATH=/run/wrappers/bin:${
      lib.makeBinPath (
        with pkgs;
        [
          coreutils
          systemd
          jq
          procps
        ]
      )
    }:$PATH
    root=${rootHelper}; state=${state}; unit=${unit}

    quiet_on() { systemctl is-active -q "$unit"; }

    # powerprofilesctl is a Python tool (~200 ms per call); the D-Bus
    # property is the same thing in ~5 ms, and the bar re-runs this on
    # every click.
    ppd="net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile"
    # shellcheck disable=SC2086
    profile() { busctl get-property $ppd 2>/dev/null | cut -d\" -f2 || echo balanced; }
    # shellcheck disable=SC2086
    set_profile() { busctl set-property $ppd s "$1"; }

    # Run the (slow) root helper in the background and refresh the bar as
    # soon as the unit's state flips, so the icon doesn't wait for the
    # guard's cap verification.
    flip() {
      local want=$1
      sudo -n "$root" "$want" >/dev/null 2>&1 &
      for _ in $(seq 1 30); do
        if [ "$want" = on ]; then quiet_on && break; else quiet_on || break; fi
        sleep 0.1
      done
      refresh
      wait
    }

    # The bar shows the ppd profile icon (format-icons keyed on `alt`) and,
    # while quiet mode is on, the speaker-off glyph appended as text.
    quietGlyph=" <span foreground='#00ffc8'>\uf026</span>"

    # nixpkgs wraps waybar, so its comm is .waybar-wrapped, not waybar.
    refresh() { pkill -RTMIN+8 -x .waybar-wrapped 2>/dev/null || pkill -RTMIN+8 -x waybar 2>/dev/null || true; }

    case "''${1:-status}" in
      status)
        prof=$(profile); tip="Power profile: $prof"; txt=""; cls="$prof"
        if quiet_on; then
          txt=$(printf '%b' "$quietGlyph"); cls="$prof quiet"
          tip="$tip · quiet mode: fans $(cat "$state/fan1_cap" 2>/dev/null)/$(cat "$state/fan2_cap" 2>/dev/null) rpm, CPU ≤$(cat "$state/cpu_pct" 2>/dev/null)% / $(( $(cat "$state/pl1_cap" 2>/dev/null || echo 0) / 1000000 )) W, turbo off"
        fi
        jq -cn --arg a "$prof" --arg x "$txt" --arg c "$cls" --arg t "$tip" \
          '{text: $x, alt: $a, class: ($c | split(" ")), tooltip: $t}'
        ;;
      next)
        # Cycles the ppd profile only; quiet mode is left as it is.
        case "$(profile)" in
          performance) set_profile balanced ;;
          balanced)    set_profile power-saver ;;
          *)           set_profile performance ;;
        esac
        refresh
        ;;
      toggle)
        if quiet_on; then flip off; else flip on; fi
        ;;
      *) echo "usage: power-cycle [status|next|toggle]" >&2; exit 2 ;;
    esac
  '';
in
{
  home.packages = [
    quiet
    quietRoot
    powerCycle
  ];
}
