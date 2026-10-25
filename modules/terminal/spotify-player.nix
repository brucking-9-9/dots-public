# ── Spotify TUI — spotify-player ──────────────────────────────────────────
# Standalone: streams through its own librespot session, no official client
# or daemon needed (Premium account required). Replaces spotatui.
# nixpkgs builds it with streaming + media-control (MPRIS → the bottom bar's
# media island and cava follow it) + daemon + notify; audio goes rodio →
# ALSA → PipeWire's ALSA plugin.
#
# First run opens the Spotify login page in the browser twice (Web API
# token, then librespot session) — see the README's "Authentication".
# `spotify_player authenticate` does the same up front.
{ pkgs, ... }:
let
  # Mini player: spotify-player inside a `kitten panel` — a kitty window drawn
  # as a wlr-layer-shell overlay (no niri window rules needed). Centered,
  # sized to show the playback block (cover, track, progress, visualizer) plus
  # the first rows of the library panes. --layer=overlay puts it above
  # fullscreen windows too (niri draws the overlay layer on top of everything).
  # --single-instance + --toggle-visibility make every further call a
  # show/hide toggle, so Mod+M (wm/niri config.kdl) works like a dropdown.
  # Note: it is its own spotify-player instance, so run either this or the
  # full TUI, not both at once (two librespot devices named nixos otherwise).
  # `spotify-mini --kill` (Mod+Shift+M) force-quits the panel and the
  # spotify_player inside it, for when the overlay wedges.
  spotify-mini = pkgs.writeShellScriptBin "spotify-mini" ''
    if [ "$1" = "--kill" ]; then
      # anchored to the kitty process so a shell whose command line merely
      # contains the pattern (like this one) is never matched
      pids=$(pgrep -f '^[^ ]*kitty \+kitten panel .*--app-id=spotify-mini')
      [ -n "$pids" ] || exit 0
      for p in $pids; do pkill -TERM -P "$p"; done
      kill -TERM $pids
      sleep 1
      # kitty has been seen ignoring TERM in panel mode; make sure
      kill -KILL $pids 2>/dev/null
      exit 0
    fi
    exec kitten panel \
      --edge=center-sized --columns=72 --lines=18 \
      --layer=overlay --focus-policy=on-demand \
      --app-id=spotify-mini \
      --single-instance --instance-group=spotify-mini --toggle-visibility \
      spotify_player "$@"
  '';
  # Visualizer window: the same TUI in a normal kitty window, sized to the
  # playback block (cover, track, visualizer). A niri window-rule (app-id
  # spotify-viz, wm config.kdl) floats it in the top-left corner, so it
  # behaves like a small app rather than a popup. Launcher entry below.
  spotify-viz = pkgs.writeShellScriptBin "spotify-viz" ''
    exec kitty --app-id=spotify-viz --title="Spotify" \
      -o initial_window_width=72c -o initial_window_height=12c \
      -o remember_window_size=no \
      spotify_player "$@"
  '';
in
{
  home.packages = [ spotify-mini spotify-viz ];

  programs.spotify-player = {
    enable = true;
    # After play/pause/skip spotify-player re-reads the playback state only at
    # +1 s and +3 s, so MPRIS (bottom bar, mbp13's music kiosk) lagged ~4 s.
    # The patch re-checks at +0.3/1/2/3.5 s. Built from source (no cache hit).
    package = pkgs.spotify-player.overrideAttrs (o: {
      patches = (o.patches or [ ]) ++ [ ./spotify-player-fast-refresh.patch ];
    });
    # → ~/.config/spotify-player/app.toml
    settings = {
      theme = "cyberpunk"; # ../../themes/spotify-player/cyberpunk.toml
      # Every Web API call is attributed to a Spotify "application" (client
      # ID). The default is ncspot's shared ID, which everyone using it
      # rate-limits together: 429s with ~30 s back-offs, so pages stay empty
      # and the TUI feels stuck. A personal client ID gets its own quota.
      # Register one at https://developer.spotify.com/dashboard → Create app
      # → Redirect URI http://127.0.0.1:8989/login → copy the Client ID into
      #   ~/.config/spotify-player/client_id      (secret, not in the repo)
      # then run `spotify_player authenticate` once. Until that file exists
      # this falls back to the shared ncspot ID (= upstream default).
      client_id_command = {
        command = "sh";
        args = [ "-c" "cat ~/.config/spotify-player/client_id 2>/dev/null || echo d420a117a32841c2b3474932e49fb54b" ];
      };
      enable_streaming = "Always";
      enable_media_control = true;
      enable_notify = true;
      notify_transient = true;
      # Built-in real-time frequency bars in the playback window (64
      # log-scale bands; colours from the theme's `visualization` style)
      enable_audio_visualization = true;
      # UI redraw tick (default 32 ms). It keeps ticking while the Mod+M panel
      # is hidden, and a hidden panel once spun spotify_player + its kitty at
      # ~99 % / ~80 % CPU; 100 ms is ~3x less work, bars a bit choppier.
      app_refresh_duration_in_ms = 100;
      border_type = "Rounded";
      progress_bar_type = "Line";
      cover_img_width = 6;
      enable_mouse_scroll_volume = true;
      device = {
        name = "nixos";
        device_type = "computer";
        volume = 70;
        bitrate = 320;
        audio_cache = true; # keeps replays off the network
        normalization = true;
      };
      layout = {
        playback_window_position = "Top";
        playback_window_height = 8; # room for the visualizer + 6-row cover
      };
    };
  };

  xdg.configFile."spotify-player/theme.toml".source =
    ../../themes/spotify-player/cyberpunk.toml;

  # Terminal=true entry so the bottom bar's launcher lists it and opens it in
  # kitty via xdg-terminal-exec (see services/Apps.qml).
  xdg.desktopEntries.spotify-mini = {
    name = "Spotify (mini)";
    genericName = "Music Player";
    comment = "spotify-player visualizer window, floats top-left (Mod+M is the popup)";
    exec = "spotify-viz";
    icon = "spotify";
    terminal = false;
    # the window spotify-viz opens is kitty --app-id=spotify-viz; the launcher
    # (services/Apps.qml) focuses by StartupWMClass, so name it or every click spawns another
    settings.StartupWMClass = "spotify-viz";
    categories = [ "AudioVideo" "Audio" "Player" ];
  };

  xdg.desktopEntries.spotify-player = {
    name = "Spotify";
    genericName = "Music Player";
    comment = "spotify-player — terminal Spotify client";
    exec = "spotify_player";
    icon = "spotify";
    terminal = true;
    categories = [ "AudioVideo" "Audio" "Player" ];
  };
}
