# ── Power / logout menu — wlogout ────────────────────────────────────────
# Bound to Mod+Shift+Escape in the niri config.
{ ... }:
{
  programs.wlogout = {
    enable = true;
    layout = [
      { label = "lock";     action = "swaylock -f";           text = "";     keybind = "l"; }
      { label = "logout";   action = "niri msg action quit";  text = "Logout";   keybind = "e"; }
      { label = "suspend";  action = "systemctl suspend";     text = "Suspend";  keybind = "u"; }
      { label = "reboot";   action = "systemctl reboot";      text = "Reboot";   keybind = "r"; }
      { label = "shutdown"; action = "systemctl poweroff";    text = "Shutdown"; keybind = "s"; }
    ];
    style = ''
      * {
        background-image: none;
        font-family: "ProFont IIx Nerd Font Mono",  monospace;
        font-size: 70px;
      }
      window {
        background-color: rgba(18, 11, 16, 0.85);
      }
      button {
        color: #00ffc8;
        background-color: #120b10;
        border: 1px solid #563466;
        border-radius: 0;   /* sharp corners — matches the rest of the theme */
        margin: 8px;
      }
      button:focus, button:active, button:hover {
        background-color: #563466;
        color: #ff0055;
        outline-style: none;
      }
    '';
  };
}
