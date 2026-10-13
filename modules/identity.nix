# ── Identity ──────────────────────────────────────────────────────────────
# CHANGE ME: your user name and home directory.
{ config, ... }:
{
  home.username      = "user";
  home.homeDirectory = "/home/user";
  home.stateVersion  = "25.11";

  programs.home-manager.enable = true;
}
