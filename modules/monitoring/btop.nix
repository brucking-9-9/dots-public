# ── btop ──────────────────────────────────────────────────────────────────
{ ... }:
{
  programs.btop = {
    enable = true;
    settings = {
      vim_keys         = true;
      update_ms        = 2000;
      color_theme      = "cyberpunk";
    };
  };

  # Theme file lives at ../../themes/btop/cyberpunk.theme
  xdg.configFile."btop/themes/cyberpunk.theme".source =
    ../../themes/btop/cyberpunk.theme;
}
