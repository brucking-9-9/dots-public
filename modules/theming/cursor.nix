# ── Pointer cursor ────────────────────────────────────────────────────────
{ pkgs, ... }:
{
  home.pointerCursor = {
    enable     = true;   # HM now requires explicit enable for cursor config generation
    gtk.enable = true;
    x11.enable = true;
    name       = "Adwaita";
    package    = pkgs.adwaita-icon-theme;
    size       = 24;
  };
}
