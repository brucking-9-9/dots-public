# ── Bottom bar — Quickshell "scanline rail" ───────────────────────────────
#
# Bottom bar for niri (mockup option A, reshaped into two unfolding islands).
# Two HUD islands always sit in the bottom corners at 22 px (niri reserves
# that with struts.bottom in config.kdl, and pulls windows up under waybar
# with a negative struts.top): bottom-left the workspace segments plus the
# running apps, bottom-right K · clock · ✉. Hovering an island unfolds it to
# 46 px with its full content sliding in; hovering the centre of the edge
# raises the media island; Mod+B unfolds everything with the prompt focused:
#
#   ▬▬ ▬ kitty firefox ............ (media) ............ 4500K │ 23:02 │ ✉2
#   > _ ▬▬ ▬ 1:kitty● 2:hx 3:firefox●    ⬡ │ ☼⌒☾ 6500K night·auto │ 23:02:17 │ ✉ 2
#
#   * apps       — mini: running apps only, names cut to 3 letters when the
#                  row would reach the media zone, wheel-scrolls past that.
#                  Full: `> _` prompt + text chips, runtime pinning (right-click → pin/unpin/move,
#                  state in ~/.local/state/quickshell-bottom/pins.json,
#                  seeded from defaultPins below), typing filters desktop
#                  entries, digits 1-9 focus-or-spawn a pin.
#   * media      — centre island whenever an MPRIS player exists, tucked
#                  below the edge until the bottom-centre strip is hovered:
#                  24 cava bars, scrolling title, output volume and mic
#                  (wheel = level, click = mute, via Quickshell's Pipewire
#                  service). Slides aside from an expanded tab; hover → card
#                  with art, oscilloscope seek bar and transport. Replaces
#                  waybar's custom/music + custom/cava.
#   * launcher   — typing in the `> _` prompt raises a vertical result list
#                  above the apps island (Enter/click launch, right-click pins).
#                  Mod+D "summons" it alone: apps island centred, surface on
#                  the overlay layer (visible over fullscreen windows, with
#                  exclusive keyboard focus); Esc / Mod+D / a launch closes it.
#                  niri's Mod+Alt+N / Mod+Alt+Shift+N call `bar pin N` /
#                  `bar killpin N` directly: pin N launches/focuses or dies
#                  without the launcher showing.
#   * sys        — ⬡ wallpaper strip (hover previews via awww, click sets,
#                  remembered in ~/.local/state/wallpaper/current), the night
#                  arc, the clock, and notifications (✉ count → list of open
#                  + past ones with actions/dismiss/clear; right-click = dnd,
#                  middle-click = mute; the tab line turns pink while pending).
#   * notifs     — the bar IS the notification daemon (Quickshell's
#                  NotificationServer in services/Notif.qml, mako retired):
#                  HUD cards slide in top-right (NotifPopups.qml), glow by
#                  urgency, drain a timeout bar, show action chips and icons;
#                  chime via pw-play, dnd/mute/history persisted in
#                  ~/.local/state/quickshell-bottom/notif.json.
#   * night mode — wl-gammarelay-rs daemon + a drag-able sun arc (live
#                  temperature over DBus) + `night-schedule`, a per-minute
#                  timer that ramps day/dusk/night at the times below. A
#                  manual drag sticks until the next phase change (marker in
#                  $XDG_RUNTIME_DIR, so a reboot returns to the schedule).
#
# The QML lives in ../../config/quickshell/bottom/ (one PanelWindow per
# screen, services/ singletons for niri/mpris/night/wallpapers/pins). Nix
# only supplies the tunables (as JSON, since the config dir itself is a
# read-only store symlink), PATH for the systemd unit, and the night units.
#
# Live iteration without a rebuild:
#   quickshell -p /etc/nixos/home/config/quickshell/bottom
#   qs ipc -p /etc/nixos/home/config/quickshell/bottom call bar open|summon|"search fi"
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # ── schedule tunables ──────────────────────────────────────────────────
  day = "07:30";
  dayK = 6500;
  dusk = "18:30";
  duskK = 4500;
  night = "20:30";
  nightK = 3000;
  rampMin = 30; # minutes to ramp between temperatures at each anchor

  # Seed only — once pins.json exists the bar owns the list.
  defaultPins = [
    "obsidian"
    "steam"
    "firefox"
    "kitty"
  ];
  wallpaperDir = "${config.home.homeDirectory}/Pictures/Wallpapers";
  chime = "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/message-new-instant.oga";

  gammaBus = "rs.wl-gammarelay / rs.wl.gammarelay";

  # night-schedule apply|set K|auto|status — stateless piecewise-linear
  # temperature from wall time. Run by the timer every minute; `set` is what
  # the bar's arc calls, `auto` returns to the schedule.
  nightSchedule = pkgs.writeShellScriptBin "night-schedule" ''
    set -u
    PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.systemd
        pkgs.gawk
      ]
    }
    day=${day}; dusk=${dusk}; night=${night}
    dayK=${toString dayK}; duskK=${toString duskK}; nightK=${toString nightK}
    ramp=${toString rampMin}
    marker="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/night-mode/manual"
    bus="${gammaBus}"

    mins() { local h m; IFS=: read -r h m <<<"$1"; echo $(( 10#$h * 60 + 10#$m )); }
    now=$(( 10#$(date +%H) * 60 + 10#$(date +%M) ))
    D=$(mins "$day"); U=$(mins "$dusk"); N=$(mins "$night")

    # [s, e) on a 24 h circle
    in_range() { if (( $1 <= $2 )); then (( $3 >= $1 && $3 < $2 )); else (( $3 >= $1 || $3 < $2 )); fi; }
    # linear a→b over $ramp minutes starting at anchor s
    interp() { local a=$1 b=$2 s=$3 d=$(( ($4 - $3 + 1440) % 1440 ));
      if (( d >= ramp )); then echo "$b"; else echo $(( a + (b - a) * d / ramp )); fi; }

    if in_range "$D" "$U" "$now"; then phase=day;   K=$(interp "$nightK" "$dayK"  "$D" "$now")
    elif in_range "$U" "$N" "$now"; then phase=dusk; K=$(interp "$dayK"  "$duskK" "$U" "$now")
    else phase=night; K=$(interp "$duskK" "$nightK" "$N" "$now"); fi

    # shellcheck disable=SC2086
    current() { busctl --user get-property $bus Temperature 2>/dev/null | awk '{print $2}'; }
    # shellcheck disable=SC2086
    write() { busctl --user set-property $bus Temperature q "$1"; }

    case "''${1:-status}" in
      apply)
        # daemon not up yet (timer fired before graphical-session): nothing to do
        [ -n "$(current)" ] || exit 0
        if [ -f "$marker" ]; then
          # a manual override holds until the phase it was made in ends
          [ "$(cat "$marker")" = "$phase" ] && exit 0
          rm -f "$marker"
        fi
        [ "$(current)" = "$K" ] || write "$K"
        ;;
      set)
        k=''${2:?usage: night-schedule set <kelvin>}
        write "$k" || exit 1
        mkdir -p "$(dirname "$marker")" && echo "$phase" > "$marker"
        ;;
      auto)
        rm -f "$marker"
        exec "$0" apply
        ;;
      status)
        cur=$(current); [ -n "$cur" ] || cur=--
        mode=auto; [ -f "$marker" ] && mode=manual
        echo "$cur $phase $mode"
        ;;
      *) echo "usage: night-schedule [apply|set K|auto|status]" >&2; exit 2 ;;
    esac
  '';
in
{
  programs.quickshell = {
    enable = true;
    configs.bottom = ../../config/quickshell/bottom;
    activeConfig = "bottom";
    systemd = {
      enable = true;
      target = "graphical-session.target";
    };
  };

  # The HM unit runs `quickshell --config bottom` with the bare systemd
  # environment, not the login PATH that niri-spawned waybar gets.
  systemd.user.services.quickshell = {
    Unit = {
      After = [ "wl-gammarelay-rs.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service.Environment = [
      "PATH=${
        lib.makeBinPath [
          pkgs.niri
          pkgs.cava
          pkgs.awww
          pkgs.pipewire   # pw-play, the notification chime
          pkgs.systemd
          pkgs.coreutils
          pkgs.findutils
          pkgs.bash
          nightSchedule
          pkgs.wl-gammarelay-rs
          pkgs.glib       # gdbus: the Touch ID HUD listens on the system bus
        ]
      }"
    ];
  };

  systemd.user.services.wl-gammarelay-rs = {
    Unit = {
      Description = "wl-gammarelay-rs — display temperature over DBus";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "dbus";
      BusName = "rs.wl-gammarelay";
      ExecStart = "${pkgs.wl-gammarelay-rs}/bin/wl-gammarelay-rs run";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.night-schedule = {
    Unit = {
      Description = "Apply the night-mode temperature schedule";
      After = [ "wl-gammarelay-rs.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${nightSchedule}/bin/night-schedule apply";
    };
  };
  systemd.user.timers.night-schedule = {
    Unit.Description = "Night-mode schedule tick";
    Timer = {
      OnCalendar = "*:0/1";
      AccuracySec = "10s";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  home.packages = [
    nightSchedule
    pkgs.wl-gammarelay-rs
  ];

  # nix → QML tunables. Not inside quickshell/bottom/: that dir is a
  # read-only store symlink (programs.quickshell.configs), and a live
  # `quickshell -p <source dir>` run would not see a file placed there.
  xdg.configFile."quickshell-bottom/config.json".text = builtins.toJSON {
    inherit defaultPins wallpaperDir chime;
    schedule = {
      inherit
        day
        dusk
        night
        dayK
        duskK
        nightK
        rampMin
        ;
    };
  };

  # state dirs the bar writes into (FileView's atomic writes need the parent)
  xdg.stateFile."quickshell-bottom/.keep".text = "";
  xdg.stateFile."wallpaper/.keep".text = "";
}
