{ ... }:
{
  imports = [
    ./identity.nix
    ./xdg.nix
    ./packages.nix
    ./session.nix

    ./shell/zsh.nix

    ./editors/helix.nix
    ./terminal/kitty.nix
    ./terminal/zellij.nix
    ./terminal/yazi.nix
    ./terminal/discordo.nix
    ./terminal/spotify-player.nix


    ./launcher/fuzzel.nix
    ./screenshot/swappy.nix

    ./bar/waybar.nix
    ./bar/quickshell-bottom.nix
    # notifications: the quickshell bar is the daemon (bar/quickshell-bottom.nix);
    # notifications/mako.nix is kept as a styled fallback, not imported.

    ./lock/swaylock.nix
    ./lock/swayidle.nix

    ./clipboard/cliphist.nix
    ./osd/swayosd.nix
    ./power/wlogout.nix
    ./power/quiet.nix

    ./monitoring/btop.nix
    ./monitoring/ripgrep.nix

    ./theming/gtk-qt.nix
    ./theming/cursor.nix

    ./wm/niri.nix
  ];
}
