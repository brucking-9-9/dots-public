# ── Quickshell shell: top bar + bottom "scanline rail" ────────────────────
#
# Top bar (TopBar.qml, Oct 2026): waybar's layout redrawn in QML — same
# pills, glyphs, paddings and colours (config/waybar/ is kept as the
# reference), backed by Quickshell's Pipewire / Bluetooth / Networking /
# SystemTray services plus a /proc + sysfs sampler (services/Sys.qml) for
# cpu, load, memory, core temperature and the battery (no UPower daemon
# here). The power glyph is power-profiles-daemon + the quiet-mode unit
# (services/Power.qml; power/quiet.nix pokes `qs ipc -c bottom call top
# refresh`). Clicks spawn through niri so toggle_bluetooth, power-cycle,
# nmtui… get the login environment. Same 25 px exclusive zone as waybar had,
# so struts.top in config.kdl is untouched. Iterate on it alone with
#   quickshell -p /etc/nixos/home/config/quickshell/bottom/top-only.qml
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
  # Dynamic wallpapers (Pictures/Wallpapers/Dynamic/{Dark,Light} pairs): the
  # schedule phases that show the Dark member; the rest show Light. Read by
  # the bar (config.json → services/Wallpapers.qml) and by wallpaper-apply.
  dynamicDarkPhases = [
    "dusk"
    "night"
  ];

  # Seed only — once pins.json exists the bar owns the list.
  defaultPins = [
    "obsidian"
    "steam"
    "firefox"
    "kitty"
  ];
  wallpaperDir = "${config.home.homeDirectory}/Pictures/Wallpapers";
  # what wallpaper-ingest converts clips to: the built-in panel's pixels, 30 fps
  videoW = 2560;
  videoH = 1600;
  videoFps = 30;
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
  # waits for the daemon's socket, then shows the remembered wallpaper (the
  # bar writes ~/.local/state/wallpaper/current on every pick)
  # A Dynamic pair member is swapped for the variant the schedule's phase
  # wants (the bar does the same while running), so a reboot at night after a
  # daytime pick comes up Dark. Pairs match by name with the trailing
  # -Dark/_dark/-Light/_light stripped, case-insensitively.
  wallpaperApply = pkgs.writeShellScriptBin "wallpaper-apply" ''
    PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.findutils
        pkgs.gawk
        pkgs.awww
        nightSchedule
      ]
    }
    for _ in $(seq 50); do awww query >/dev/null 2>&1 && break; sleep 0.2; done
    img=$(cat "$HOME/.local/state/wallpaper/current" 2>/dev/null || true)
    [ -r "$img" ] || img="$HOME/Pictures/Wallpapers/wallpaper.png"
    case "$img" in
      */Dynamic/Dark/*|*/Dynamic/Light/*)
        phase=$(night-schedule status 2>/dev/null | awk '{print $2}')
        want=Light
        case " ${lib.concatStringsSep " " dynamicDarkPhases} " in *" $phase "*) want=Dark ;; esac
        base=$(basename "$img"); base=''${base%.*}; base=''${base,,}
        base=''${base%[-_]dark}; base=''${base%[-_]light}
        hit=$(find "$(dirname "$(dirname "$img")")/$want" -maxdepth 1 -iname "$base[-_]$want.*" | head -n1)
        [ -r "$hit" ] && img=$hit
        ;;
    esac
    # a video: awww shows its poster frame, wallpaper-video.service plays on top
    case "''${img,,}" in
      *.mp4|*.webm|*.mkv|*.mov)
        img="$(dirname "$img")/.thumbs/$(basename "''${img%.*}").jpg"
        [ -r "$img" ] || img="$HOME/Pictures/Wallpapers/wallpaper.png"
        ;;
    esac
    exec awww img "$img" --transition-type wipe --transition-fps 60
  '';

  # ── video wallpapers ───────────────────────────────────────────────────
  # awww can't play video and preloads every frame of a GIF (a 4K, 4000-frame
  # one never finishes loading), so clips go through mpvpaper instead:
  #   * wallpaper-video.service plays ~/.local/state/wallpaper/current when it
  #     is a video (VA-API decode, paused while the wallpaper is hidden) and
  #     exits when it is a still. The bar restarts/stops it on every pick.
  #   * wallpaper-ingest converts whatever lands in Wallpapers/Animated-stage
  #     to a display-sized 30 fps H.264 loop in Wallpapers/Animated (+ a poster
  #     in Animated/.thumbs for the strip, awww and wallpaper-accent). The
  #     source moves to Wallpapers/.animated-originals (failed/ if ffmpeg
  #     choked on it), so the stage dir ends up empty.
  wallpaperVideo = pkgs.writeShellScript "wallpaper-video" ''
    img=$(${pkgs.coreutils}/bin/cat "$HOME/.local/state/wallpaper/current" 2>/dev/null || true)
    case "''${img,,}" in
      *.mp4|*.webm|*.mkv|*.mov) [ -r "$img" ] || exit 0 ;;
      *) exit 0 ;;
    esac
    exec ${pkgs.mpvpaper}/bin/mpvpaper -p \
      -o "no-audio loop hwdec=auto-safe panscan=1.0 no-osc no-input-default-bindings" '*' "$img"
  '';

  wallpaperIngest = pkgs.writeShellScriptBin "wallpaper-ingest" ''
    set -u
    PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.findutils
        pkgs.ffmpeg
        pkgs.libnotify
      ]
    }
    stage="${wallpaperDir}/Animated-stage"
    out="${wallpaperDir}/Animated"
    orig="${wallpaperDir}/.animated-originals"
    mkdir -p "$stage" "$out/.thumbs" "$orig/failed"
    # never upscale; a source bigger than the panel shrinks until it just covers it
    vf="scale=w='min(iw,${toString videoW})':h='min(ih,${toString videoH})':force_original_aspect_ratio=increase:force_divisible_by=2:flags=lanczos,fps=${toString videoFps},format=yuv420p"
    # move a source out of the stage dir without clobbering an earlier one
    keep() {
      dst="$2/$(basename "$1")"
      [ ! -e "$dst" ] || dst="$2/$(date +%s)-$(basename "$1")"
      mv "$1" "$dst"
    }
    while :; do
      f=$(find "$stage" -mindepth 1 -maxdepth 1 -type f -not -name '.*' | sort | head -n1)
      [ -n "$f" ] || break
      # still being copied in?
      s1=$(stat -c %s "$f"); sleep 3; s2=$(stat -c %s "$f" 2>/dev/null || echo gone)
      [ "$s1" = "$s2" ] || continue
      base=$(basename "''${f%.*}")
      name=$base; n=2
      while [ -e "$out/$name.mp4" ]; do name="$base-$n"; n=$((n + 1)); done
      tmp="$out/.$name.tmp.mp4"
      if ffmpeg -nostdin -hide_banner -loglevel error -y -i "$f" -map 0:v:0 -an -map_metadata -1 \
           -vf "$vf" -c:v libx264 -preset slow -crf 20 -movflags +faststart "$tmp" \
         && ffmpeg -nostdin -hide_banner -loglevel error -y -ss 1 -i "$tmp" -frames:v 1 -vf scale=480:-2 "$out/.thumbs/$name.jpg"; then
        mv "$tmp" "$out/$name.mp4"
        keep "$f" "$orig"
        notify-send -a wallpaper -i "$out/.thumbs/$name.jpg" "Wallpaper ready" "$name" || true
      else
        rm -f "$tmp" "$out/.thumbs/$name.jpg"
        keep "$f" "$orig/failed"
        notify-send -a wallpaper "Wallpaper convert failed" "$(basename "$f") → .animated-originals/failed" || true
      fi
    done
  '';

  # nixos-switch — the bar's 󱄅 button (bottom/Bar.qml, sys fold), also fine
  # from a terminal. Runs the rebuild as the transient user unit
  # `nixos-switch` rather than under the bar, because the switch restarts
  # quickshell.service. sudo is the only auth (Touch ID first, then the
  # fuzzel askpass after its 10 s timeout); its own prompts and errors go to
  # `auth`, so `log` stays empty until it has authenticated and the bar's
  # SwitchHud (services/Switch.qml) slides down only after a good scan.
  # A second call while a run is live does nothing.
  # `nixos-switch --remote[-all]` builds on mbp13 (tools/remote-build.nix).
  # nixos-rebuild's output goes through `nix-plan --filter` (also in
  # remote-build.nix), which renders it readable into `log` and records the
  # derivation plan for mbp13's build kiosk.
  switchAskpass = pkgs.writeShellScript "nixos-switch-askpass" ''
    exec ${pkgs.fuzzel}/bin/fuzzel --dmenu --password --lines 0 --prompt "sudo nixos-rebuild  "
  '';
  switchRun = pkgs.writeShellScript "nixos-switch-run" ''
    # full system PATH: sudo passes it on to nixos-rebuild
    PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.libnotify ]}:/run/wrappers/bin:/run/current-system/sw/bin
    d=$1
    shift # rest: extra nixos-rebuild args (--remote's --builders ...)
    np=${config.home.profileDirectory}/bin/nix-plan
    if [ -x "$np" ]; then
      lbl="nixos-switch"
      case "$*" in *builders*) lbl="nixos-switch --remote" ;; esac
      lbl="$lbl · $(cat /proc/sys/kernel/hostname) system"
      rm -f "$d/rc"
      {
        sudo -A -H ${pkgs.bash}/bin/sh -c 'exec /run/current-system/sw/bin/nixos-rebuild switch --flake /etc/nixos "$@" -v --log-format internal-json 2>&1' sh "$@" 2>"$d/auth"
        r=$?
        echo "$r" > "$d/rc"
        echo "@nix-plan-rc $r"
      } | "$np" --filter --label "$lbl" >"$d/log" 2>&1
      r=$(cat "$d/rc" 2>/dev/null || echo 1)
    else
      sudo -A -H ${pkgs.bash}/bin/sh -c 'log=$1; shift; exec /run/current-system/sw/bin/nixos-rebuild switch --flake /etc/nixos "$@" >"$log" 2>&1' sh "$d/log" "$@" 2>"$d/auth"
      r=$?
    fi
    echo "$r" > "$d/status.tmp" && mv -f "$d/status.tmp" "$d/status"
    if [ "$r" != 0 ] && [ ! -s "$d/log" ]; then
      notify-send -a nixos-switch "Switch cancelled" "$(tail -n1 "$d/auth")" || true
    fi
  '';
  nixosSwitch = pkgs.writeShellScriptBin "nixos-switch" ''
    set -u
    PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.systemd ]}
    unit=nixos-switch
    d="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/nixos-switch"
    systemctl --user is-active -q "$unit" && exit 0
    # --remote / --remote-all: build on mbp13 (tools/remote-build.nix). Only
    # big-parallel jobs (the T2 kernel) by default, everything with -all.
    # mbp13 asleep/offline -> a normal local switch, with a notification.
    extra=()
    case "''${1:-}" in
      --remote|--remote-all)
        mode=""; [ "$1" = --remote-all ] && mode=--all
        if b=$(${config.home.profileDirectory}/bin/mbp13-builders $mode 2>/dev/null); then
          extra=(--option builders "$b" --option builders-use-substitutes true)
          [ -n "$mode" ] && extra+=(--max-jobs 0)
        else
          ${pkgs.libnotify}/bin/notify-send -a nixos-switch "mbp13 unreachable" "Switching with a local build instead" || true
          echo "nixos-switch: mbp13 unreachable, building locally" >&2
        fi ;;
    esac
    mkdir -p "$d"
    : > "$d/log"
    rm -f "$d/status" "$d/auth"
    systemctl --user reset-failed "$unit" 2>/dev/null
    exec systemd-run --user --quiet --collect --unit="$unit" \
      --setenv=SUDO_ASKPASS=${switchAskpass} \
      ${switchRun} "$d" "''${extra[@]}"
  '';

  # ── follow-wallpaper accent ────────────────────────────────────────────
  # `wallpaper-accent [--follow on|off] [image]` — called by the bar when a
  # wallpaper is picked (services/Wallpapers.qml) and when the ◐ accent chip
  # is toggled (Theme.qml). Finds the image's dominant vibrant hue (matugen's
  # own picker prefers tiny saturated details over the colour that fills the
  # frame), lets matugen build a scheme from it, and writes:
  #   ~/.local/state/wallpaper/palette.json        full matugen JSON (source hue)
  #   ~/.local/state/wallpaper/palette2.json       same for the tertiary hue
  #   ~/.local/state/wallpaper/accent-colors.json  tonal ladder: accent (60),
  #                                                 accentText (70), accentHi (90),
  #                                                 accentDim (35), accent2/accent2Text
  #                                                 (60/70 of the tertiary hue)
  #   ~/.local/state/wallpaper/niri-accent.kdl     focus-ring active-color when
  #                                                 follow is on, a comment when off
  # niri `include optional=true`s that last file (config.kdl) and live-reloads.
  wallpaperAccent = pkgs.writeShellScriptBin "wallpaper-accent" ''
        set -u
        PATH=${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.diffutils # cmp
            pkgs.gawk
            pkgs.imagemagick
            pkgs.matugen
          ]
        }
        state="$HOME/.local/state/wallpaper"
        mkdir -p "$state"
        follow=""
        if [ "''${1:-}" = "--follow" ]; then follow=$2; shift 2; fi
        img="''${1:-$(cat "$state/current" 2>/dev/null || true)}"
    # a video: sample its poster frame (written by wallpaper-ingest)
    case "''${img,,}" in
      *.mp4|*.webm|*.mkv|*.mov) img="$(dirname "$img")/.thumbs/$(basename "''${img%.*}").jpg" ;;
    esac
        # (gawk, not grep: grep is not on this script's PATH)
        [ -n "$follow" ] || { gawk '/"follow": *true/ { f=1 } END { exit !f }' "$state/accent.json" 2>/dev/null && follow=on || follow=off; }
        default_cyan="#00ffc8"; default_pink="#ff0055"

        # dominant vibrant hue: 120x120 copy quantised to 24 colours, each weighted
        # pixels*sat*val², summed into 15° hue buckets (3-bucket window); print the
        # most vivid colour of the winning family. Greys only → print nothing, so
        # the stock palette stays (matugen would otherwise invent a teal from grey).
        dominant() {
          magick "$1" -resize '120x120!' -colors 24 -depth 8 -format '%c' histogram:info:- 2>/dev/null | gawk '
            match($0, /^ *([0-9]+): *\(([0-9]+),([0-9]+),([0-9]+)/, m) {
              n=m[1]; R=m[2]; G=m[3]; B=m[4]; r=R/255; g=G/255; b=B/255
              mx=(r>g?r:g); mx=(mx>b?mx:b); mn=(r<g?r:g); mn=(mn<b?mn:b); d=mx-mn
              v=mx; s=(mx>0)?d/mx:0
              if (s < 0.25 || v < 0.25) next
              if (d == 0) h=0; else if (mx==r) h=60*(((g-b)/d)%6); else if (mx==g) h=60*((b-r)/d+2); else h=60*((r-g)/d+4)
              if (h < 0) h+=360
              k++; hue[k]=h; vivid[k]=s*v; hex[k]=sprintf("#%02x%02x%02x", R, G, B)
              bk=int(h/15); acc[bk]+=n*s*v*v
            }
            END {
              if (k == 0) exit
              best=-1
              for (i=0;i<24;i++) { w=acc[(i+23)%24]+acc[i]+acc[(i+1)%24]; if (w>best) { best=w; bb=i } }
              bv=-1
              for (j=1;j<=k;j++) { d=int(hue[j]/15)-bb; if (d<0) d=-d; if (d>12) d=24-d; if (d<=1 && vivid[j]>bv) { bv=vivid[j]; out=hex[j] } }
              print out
            }'
        }
        # tones N of palettes.primary in a matugen --json hex file, printed as "N=#hex"
        # (gated: "primary" also appears under colors, tone keys appear in every palette)
        tones() {
          gawk -v want="$2" '
            BEGIN { n = split(want, w, " "); for (i = 1; i <= n; i++) ok[w[i]] = 1 }
            /"palettes": *\{/ { p = 1 }
            p && /"primary": *\{/ { q = 1; next }
            p && q && /"(secondary|tertiary|neutral|neutral_variant|error)": *\{/ { q = 0 }
            p && q && match($0, /^ *"([0-9]+)": *\{/, m) { tone = m[1]; next }
            p && q && tone != "" && match($0, /"color": *"(#[0-9a-fA-F]{6})"/, m) { if (tone in ok) print tone "=" m[1]; tone = "" }
          ' "$1"
        }

        # Material tonal ladder (same hue + chroma at perceptual tones 0–100; a
        # given tone has the same contrast against the bar's bg for every hue):
        #   35 fills · 60 ring/glow (6:1) · 70 text (8.5:1) · 90 hover (15:1)
        # Stock palette as the fallback for grey wallpapers.
        accent=$default_cyan; accentText=$default_cyan; accentHi=$default_cyan; accentDim="#563466"
        accent2=$default_pink; accent2Text=$default_pink; src=""; src2=""
        if [ -n "$img" ] && [ -r "$img" ]; then
          src=$(dominant "$img")
          if [ -n "$src" ] && matugen color hex "$src" --json hex --dry-run -t scheme-content > "$state/palette.json.tmp" 2>/dev/null; then
            mv "$state/palette.json.tmp" "$state/palette.json"
            while IFS='=' read -r t c; do
              case "$t" in 35) accentDim=$c ;; 60) accent=$c ;; 70) accentText=$c ;; 90) accentHi=$c ;; esac
            done <<EOT
    $(tones "$state/palette.json" "35 60 70 90")
    EOT
            # matugen's tertiary is deliberately muted (chroma 24); use it only as a
            # hue and build a second, full-chroma ladder from it (scheme-content
            # keeps the analogous hue, e.g. orange next to red)
            src2=$(gawk '/"tertiary": *\{/ {t=1} t && /"dark": *\{/ {d=1} t && d && match($0, /"color": *"(#[0-9a-fA-F]{6})"/, m) { print m[1]; exit }' "$state/palette.json")
            if [ -n "$src2" ] && matugen color hex "$src2" --json hex --dry-run > "$state/palette2.json.tmp" 2>/dev/null; then
              mv "$state/palette2.json.tmp" "$state/palette2.json"
              while IFS='=' read -r t c; do
                case "$t" in 60) accent2=$c ;; 70) accent2Text=$c ;; esac
              done <<EOT
    $(tones "$state/palette2.json" "60 70")
    EOT
            fi
          fi
        fi
        rm -f "$state/palette.json.tmp" "$state/palette2.json.tmp"
        printf '{ "accent": "%s", "accentText": "%s", "accentHi": "%s", "accentDim": "%s", "accent2": "%s", "accent2Text": "%s", "source": "%s", "source2": "%s" }\n' \
          "$accent" "$accentText" "$accentHi" "$accentDim" "$accent2" "$accent2Text" "$src" "$src2" > "$state/accent-colors.json.tmp"
        mv "$state/accent-colors.json.tmp" "$state/accent-colors.json"
        if [ "$follow" = on ]; then
          printf '// written by wallpaper-accent — focus ring follows the wallpaper (tone 60)\nlayout {\n  focus-ring {\n    active-color "%s"\n  }\n}\n' "$accent" > "$state/niri-accent.kdl.tmp"
        else
          printf '// written by wallpaper-accent — accent off, config.kdl colours apply\n' > "$state/niri-accent.kdl.tmp"
        fi
        # only replace the include when it changes: every write makes niri reload its whole config
        if cmp -s "$state/niri-accent.kdl.tmp" "$state/niri-accent.kdl"; then
          rm -f "$state/niri-accent.kdl.tmp"
        else
          mv "$state/niri-accent.kdl.tmp" "$state/niri-accent.kdl"
        fi
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

  # ── wallpaper daemon ───────────────────────────────────────────────────
  # awww-daemon as a user service (Restart=always from the HM module) instead
  # of niri's spawn-at-startup: the niri-spawned one died silently on
  # 2026-10-13 and nothing brought it back. ExecStartPost re-applies the
  # remembered wallpaper every (re)start; ExecStartPre clears a stray daemon
  # left over from the spawn-at-startup days so the socket is free (match on
  # the full command line: the nix wrapper's comm is ".awww-daemon-wr", so
  # `pkill -x awww-daemon` finds nothing — that bit us on 2026-10-13).
  services.awww.enable = true;
  systemd.user.services.awww.Service = {
    ExecStartPre = "-${pkgs.procps}/bin/pkill -f 'awww-daemon(-wrapped)?$'";
    ExecStartPost = "-${wallpaperApply}/bin/wallpaper-apply";
    RestartSec = lib.mkForce 1;
  };

  # video wallpapers (see wallpaperVideo / wallpaperIngest above)
  systemd.user.services.wallpaper-video = {
    Unit = {
      Description = "Video wallpaper (mpvpaper) when the remembered wallpaper is a clip";
      PartOf = [ "graphical-session.target" ];
      After = [
        "graphical-session.target"
        "awww.service"
      ];
    };
    Service = {
      ExecStart = "${wallpaperVideo}";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
  systemd.user.services.wallpaper-ingest = {
    Unit.Description = "Convert clips dropped into Wallpapers/Animated-stage";
    Service = {
      Type = "oneshot";
      ExecStart = "${wallpaperIngest}/bin/wallpaper-ingest";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };
  systemd.user.paths.wallpaper-ingest = {
    Unit.Description = "Watch Wallpapers/Animated-stage for new clips";
    Path = {
      PathChanged = "${wallpaperDir}/Animated-stage";
      MakeDirectory = true;
    };
    Install.WantedBy = [ "paths.target" ];
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
          pkgs.pipewire # pw-play, the notification chime
          pkgs.systemd
          pkgs.coreutils
          pkgs.findutils
          pkgs.bash
          nightSchedule
          pkgs.wl-gammarelay-rs
          pkgs.glib # gdbus: the Touch ID HUD listens on the system bus
          pkgs.brightnessctl # the OSD's screen / keyboard backlight steps (services/Osd.qml)
          pkgs.networkmanager # nmcli: the top bar's wifi frequency tooltip (services/Net.qml)
          wallpaperAccent # palette + niri focus-ring colour on wallpaper pick / accent toggle
        ]
      }:${config.home.profileDirectory}/bin" # power-cycle (power/quiet.nix) for the top bar's power glyph
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
    nixosSwitch
    pkgs.wl-gammarelay-rs
    wallpaperAccent # `wallpaper-accent --follow on|off [image]` by hand
    wallpaperIngest # `wallpaper-ingest` by hand (the path unit runs it on drops)
  ];

  # nix → QML tunables. Not inside quickshell/bottom/: that dir is a
  # read-only store symlink (programs.quickshell.configs), and a live
  # `quickshell -p <source dir>` run would not see a file placed there.
  xdg.configFile."quickshell-bottom/config.json".text = builtins.toJSON {
    inherit
      defaultPins
      wallpaperDir
      chime
      dynamicDarkPhases
      ;
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

  # helper scripts the top bar's clicks / menus run (inherited from the waybar
  # config, which called them from ~/.local/bin); `launch` and `themesw` are
  # kept for the shell
  home.file = {
    ".local/bin/toggle_bluetooth" = {
      executable = true;
      source = ../../scripts/waybar/toggle_bluetooth;
    };
    ".local/bin/themesw" = {
      executable = true;
      source = ../../scripts/waybar/themesw;
    };
    ".local/bin/caffeine" = {
      executable = true;
      source = ../../scripts/waybar/caffeine;
    };
    ".local/bin/powersafe" = {
      executable = true;
      source = ../../scripts/waybar/powersafe;
    };
    ".local/bin/refreshrate" = {
      executable = true;
      source = ../../scripts/waybar/refreshrate;
    };
    ".local/bin/launch" = {
      executable = true;
      source = ../../scripts/waybar/launch;
    };
  };

  # state dirs the bar writes into (FileView's atomic writes need the parent)
  xdg.stateFile."quickshell-bottom/.keep".text = "";
  xdg.stateFile."wallpaper/.keep".text = "";
}
