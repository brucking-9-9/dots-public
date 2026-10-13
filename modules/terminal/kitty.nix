# ── Terminal — kitty ──────────────────────────────────────────────────────
{ ... }:
{
  programs.kitty = {
    enable = true;
    themeFile = "cyberpunk";
    extraConfig = "
      font_family      ProFont IIx Nerd Font Mono
      bold_font        auto
      italic_font      auto
      bold_italic_font auto
      cursor_trail 1
      cursor_trail_color blue
      cursor_trail_start_threshold 1
      cursor_trail_decay 0.1 0.6
      ";
    };

  # kitty is the default terminal for desktop entries with Terminal=true
  # (btop, hx, …). Anything that honours the XDG terminal-exec spec — GTK /
  # gio launches, file managers, the quickshell bar's launcher — runs them
  # through `xdg-terminal-exec`, which reads ~/.config/xdg-terminals.list.
  # (fuzzel has its own `terminal = "kitty"` setting.)
  xdg.terminal-exec = {
    enable = true;
    settings.default = [ "kitty.desktop" ];
  };
}
