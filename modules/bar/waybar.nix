# ── Status bar — waybar ───────────────────────────────────────────────────
# This config (cebem1nt/dotfiles waybar, adapted for Niri + T2 — see the
# upstream README that shipped with it for what was changed) is plain
# JSONC/CSS, not expressed as programs.waybar.settings/style, so the raw
# files live under ../../config/waybar/ (same treatment as
# ../../config/niri/config.kdl) and are dropped into ~/.config/waybar
# as-is below.
#
# Helper scripts it shells out to (bluetooth toggle, theme switcher,
# caffeine/idle-inhibit, powersafe, refreshrate) live in
# ../../scripts/waybar/ and get deployed to ~/.local/bin, since the config
# calls them from there rather than from inside ~/.config/waybar.
{ config, ... }:
{
  programs.waybar = {
    enable         = true;
    systemd.enable = false;
  };

  xdg.configFile = {
    "waybar/config.jsonc".source          = ../../config/waybar/config.jsonc;
    "waybar/modules.jsonc".source         = ../../config/waybar/modules.jsonc;
    "waybar/style.css".source             = ../../config/waybar/style.css;
    "waybar/colors/colors.css".source       = ../../config/waybar/colors/colors.css;
    "waybar/colors/colors.dark.css".source  = ../../config/waybar/colors/colors.dark.css;
    "waybar/colors/colors.light.css".source = ../../config/waybar/colors/colors.light.css;
    "waybar/context/ctlcenter.xml".source  = ../../config/waybar/context/ctlcenter.xml;
    "waybar/context/network.xml".source    = ../../config/waybar/context/network.xml;
  };

  home.file = {
    ".local/bin/toggle_bluetooth" = {
      executable = true;
      source     = ../../scripts/waybar/toggle_bluetooth;
    };
    ".local/bin/themesw" = {
      executable = true;
      source     = ../../scripts/waybar/themesw;
    };
    ".local/bin/caffeine" = {
      executable = true;
      source     = ../../scripts/waybar/caffeine;
    };
    ".local/bin/powersafe" = {
      executable = true;
      source     = ../../scripts/waybar/powersafe;
    };
    ".local/bin/refreshrate" = {
      executable = true;
      source     = ../../scripts/waybar/refreshrate;
    };
    ".local/bin/launch" = {
      executable = true;
      source     = ../../scripts/waybar/launch;
    };
  };
}
