{ ... }:
{
  imports = [
    ./identity.nix
    ./shell/zsh.nix
    ./editors/helix.nix
    ./terminal/kitty.nix
    ./terminal/spotify-player.nix
    ./bar/waybar.nix
    ./bar/quickshell-bottom.nix
    ./wm/niri.nix
  ];
}
