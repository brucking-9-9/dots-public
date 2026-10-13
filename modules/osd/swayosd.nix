# ── Volume / brightness OSD — swayosd ────────────────────────────────────
# Bound in the niri config via swayosd-client, which replaces the old
# direct wpctl/brightnessctl calls (it performs the same action and shows
# a popup while doing it).
{ ... }:
{
  services.swayosd.enable = true;
}
