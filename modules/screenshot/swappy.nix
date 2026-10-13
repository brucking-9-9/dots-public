# ── Screenshot annotation — swappy ─────────────────────────────────────────
# Bound to Print / Ctrl+Print in the niri config: grim/slurp capture pipes
# into swappy so you can draw on it before saving or copying.
{ ... }:
{
  programs.swappy = {
    enable = true;
    settings.Default = {
      save_dir            = "$HOME/Pictures/Screenshots";
      save_filename_format = "swappy-%Y%m%d-%H%M%S.png";
      show_panel          = true;
      line_size           = 5;
      text_size           = 20;
      text_font           = "Terminus (TTF)";
      paint_mode          = "brush";
      early_exit          = false;
      fill_shape          = false;
      auto_save           = false;
      custom_color        = "rgba(255,140,0,1)"; # amber, matches the theme
      transparent         = false;
      transparency        = 50;
    };
  };
}
