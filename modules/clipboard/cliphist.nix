# ── Clipboard history — cliphist ─────────────────────────────────────────
# Runs as a systemd user service tied to graphical-session.target, same
# as mako/swayidle. niri-session already brings that target up, so no
# extra wiring is needed. Pair it with a fuzzel bind, e.g.:
#   Mod+Shift+C { spawn "sh" "-c" "cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"; }
{ ... }:
{
  services.cliphist = {
    enable      = true;
    allowImages = true;
  };
}
