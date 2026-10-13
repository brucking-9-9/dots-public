# ── Launcher — fuzzel ─────────────────────────────────────────────────────
# fuzzel is also listed in configuration.nix user packages; you can drop it
# from there now that home-manager owns both the package and the config.
{ ... }:
{
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font         = "Terminus (TTF):size=14";
        terminal     = "kitty";
        prompt       = "» ";
        icon-theme   = "Adwaita";
        show-actions = true;
        lines        = 8;
        width        = 42;
        anchor       = "top";
        "y-margin"       = 64;
        "horizontal-pad" = 22;
        "vertical-pad"   = 18;
        "inner-pad"      = 12;
      };
      # cyberpunk-neon palette, matched to the kitty 'cyberpunk' theme.
      # fuzzel colors are RRGGBBAA (no '#').
      colors = {
        background      = "120b10f2";   # near-black bg, slightly translucent
        text            = "00ffc8ff";   # neon cyan
        match           = "ff0055ff";   # hot pink — matched chars
        selection       = "563466ff";   # purple selection bar
        "selection-text"  = "eeffffff";   # near-white on selection
        "selection-match" = "00ffc8ff";   # cyan match on selection
        border          = "d57bffff";   # soft purple border
      };
      border = {
        width  = 2;
        radius = 14;   # rounded, softer
      };
    };
  };
}
