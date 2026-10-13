# ── Extra packages (CLI tools, wayland utilities) ─────────────────────────
{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages =
    with pkgs;
    [
      # Wayland / compositor utils
      brightnessctl
      grim # screenshot — whole screen
      slurp # screenshot — region selector
      wl-clipboard # wl-copy / wl-paste
      pwvucontrol # pipewire-native volume control (opened by waybar)
      awww # animated wallpaper daemon (spawn-at-startup "awww-daemon")

      playerctl
      file

      # Notes
      obsidian

      # Browser — Chromium with all Google services/telemetry patched out
      # (Firefox stays the default via programs.firefox + BROWSER=firefox)
      ungoogled-chromium

      # Chat
      discordo # Discord TUI (~5 MB RSS); themed via terminal/discordo.nix
      # vesktop (Discord GUI w/ voice) is installed by programs.vesktop in tools/vesktop.nix

      # Polkit agent
      polkit_gnome

      # notify-send — used by the waybar audio/power picker scripts below
      # to confirm the switch actually happened
      libnotify

      # Fonts
      terminus_font
      # General utilities
      fd
      unar # handles zip / rar / 7z / tar with one command
      curl
      yt-dlp
      # Autoclicker — reads the trigger from evdev, clicks through /dev/uinput,
      # so it works in any Wayland/XWayland window. Bare `theclicker` gives an
      # interactive device + bind picker; hold-side-button-to-click on the G305:
      #   theclicker run -d "Logitech G305" -H -l 275
      # (wl-clicker is no use here: its keyboard auto-detect mangles the
      # /dev/input path on every keyboard on this box, and has no device flag)
      theclicker
      # Benchmarking (Cinebench itself is Windows/Mac-only, no Linux build —
      # these are the closest Linux-native equivalents)
      sysbench # quick CPU/memory/IO score:  sysbench cpu --threads=$(nproc) run
      phoronix-test-suite # the closest thing to Cinebench's global leaderboard:
      #   phoronix-test-suite benchmark pts/cpu
      # (there IS a "pts/cinebench" profile, but it just runs
      # the Windows build under Wine — pts/cpu and pts/blender
      # are the genuinely native-Linux render/CPU benchmarks)
      # downloads test profiles + submits/compares scores at
      # openbenchmarking.org — needs network at run time
      glmark2 # GPU/OpenGL score, useful since the CPU-only story
      # above doesn't touch the iGPU at all
      passmark-performancetest # PassMark PerformanceTest for Linux (TUI):
      #   performancetest   — CPU/memory suite; the CPU Mark is comparable
      #   to the Windows version's on passmark.com/baselines
      # (unfree, prebuilt binary — built locally, not in the cache)
    ]
    ++ (builtins.filter lib.isDerivation (builtins.attrValues pkgs.nerd-fonts));
}
