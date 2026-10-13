# ── Lock screen — swaylock ────────────────────────────────────────────────
{ pkgs, ... }:
{
  programs.swaylock = {
    enable  = true;
    package = pkgs.swaylock-effects;
    settings = {
      color                   = "120b10";
      font-size               = 24;
      indicator-idle-visible  = false;
      indicator-radius        = 80;
      show-failed-attempts    = true;
      # swaylock-effects extras
      effect-blur             = "7x5";
      fade-in                 = "0.2";
      # Cyberpunk-neon ring — colours are RRGGBB (no '#')
      ring-color              = "00ffc8";   # idle ring
      ring-ver-color          = "d57bff";   # verifying
      ring-wrong-color        = "ff0055";   # wrong PIN
      key-hl-color            = "f4ef00";   # key highlight flash
      inside-color            = "120b10";
      inside-ver-color        = "120b10";
      inside-wrong-color      = "120b10";
      line-color              = "120b10";
      line-ver-color          = "120b10";
      line-wrong-color        = "120b10";
      text-color              = "00ffc8";
      text-ver-color          = "d57bff";
      text-wrong-color        = "ff0055";
      separator-color         = "00000000"; # transparent
    };
  };
}
