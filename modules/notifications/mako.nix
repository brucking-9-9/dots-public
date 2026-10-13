# ── Notifications — mako (NOT IMPORTED) ───────────────────────────────────
# Fallback only: the quickshell bar owns org.freedesktop.Notifications now
# (home/modules/bar/quickshell-bottom.nix). Re-add to default.nix to go back.
# Cyberpunk-neon palette (kitty theme is the source of truth; the same hexes
# live in quickshell/bottom/Theme.qml). Popups are top-right; the ✉ badge on
# the bottom rail (quickshell) lists/dismisses them via makoctl.
#
# Modes (toggle with `makoctl mode -t <name>`, or from the rail: right-click
# the ✉ badge = dnd, middle-click = silent, Mod+Shift+N = dnd):
#   dnd     popups hidden, still counted/listed on the rail
#   silent  no arrival sound
#
# Icons: app-supplied icons/images (hicolor, absolute paths, image-data hints)
# render; theme names like "dialog-information" don't, because Adwaita 50 ships
# only symbolic/ + scalable/ trees that mako's size-dir lookup can't find (and
# it wouldn't recolour the grey symbolic SVGs anyway). The app name in the
# format carries the sender instead.
{ pkgs, config, ... }:
let
  qs     = "${config.programs.quickshell.package}/bin/qs";
  pwplay = "${pkgs.pipewire}/bin/pw-play";
  sound  = "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/message-new-instant.oga";
  # tell the rail to re-read `makoctl list` right away instead of on its 5 s poll
  poke   = "${qs} ipc -c bottom call bar refresh >/dev/null 2>&1";
  app    = ''<span color="#d57bff" size="small">%a</span>'';
in
{
  services.mako = {
    enable = true;
    settings = {
      font             = "CaskaydiaCove Nerd Font Propo 12";
      background-color = "#120b10ee";
      text-color       = "#eeffff";
      border-color     = "#00ffc8";
      border-size      = 1;
      border-radius    = 0;       # sharp corners
      padding          = "10,14";
      margin           = 8;
      outer-margin     = "12,12,0,0";
      width            = 380;
      anchor           = "top-right";
      max-visible      = 5;
      sort             = "-time";
      icons            = 1;
      max-icon-size    = 28;
      icon-location    = "left";
      icon-path        = "${config.home.profileDirectory}/share/icons/hicolor";
      markup           = 1;
      format           = ''${app}\n<span color="#00ffc8"><b>%s</b></span>\n%b'';
      group-by         = "app-name,summary";
      default-timeout  = 6000;
      on-notify        = "exec ${poke}; ${pwplay} --media-role=Notification ${sound}";

      "urgency=low" = {
        border-color    = "#563466";
        text-color      = "#9a86a6";
        default-timeout = 3500;
        format          = ''<span color="#6d5a78" size="small">%a</span>\n<b>%s</b>\n%b'';
        on-notify       = "exec ${poke}";          # quiet ones don't chime
      };
      "urgency=critical" = {
        border-color    = "#f4ef00";
        border-size     = 2;
        default-timeout = 0;                       # stays until dismissed
        ignore-timeout  = 1;
        format          = ''<span color="#f4ef00" size="small">⚠ %a</span>\n<span color="#f4ef00"><b>%s</b></span>\n%b'';
      };
      # repeats collapse into one box with a ×N counter
      "grouped" = {
        format = ''${app} <span color="#6d5a78">×%g</span>\n<span color="#00ffc8"><b>%s</b></span>\n%b'';
      };
      "grouped urgency=low" = {
        format = ''<span color="#6d5a78" size="small">%a ×%g</span>\n<b>%s</b>\n%b'';
      };
      "grouped urgency=critical" = {
        format = ''<span color="#f4ef00" size="small">⚠ %a</span> <span color="#6d5a78">×%g</span>\n<span color="#f4ef00"><b>%s</b></span>\n%b'';
      };
      "mode=dnd"    = { invisible = 1; on-notify = "exec ${poke}"; };   # hidden and silent
      "mode=silent" = { on-notify = "exec ${poke}"; };
    };
  };
}
