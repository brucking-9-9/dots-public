# ── Discord TUI — discordo ────────────────────────────────────────────────
# Package is listed in ../packages.nix. This module only ships the config.
# discordo overlays this file on its embedded defaults, so the theme file
# carries just the colour/style overrides; keybinds stay upstream.
{ ... }:
{
  # Theme file lives at ../../themes/discordo/cyberpunk.toml
  xdg.configFile."discordo/config.toml".source = ../../themes/discordo/cyberpunk.toml;
}
