# ── XDG base dirs ─────────────────────────────────────────────────────────
{ config, ... }:
{
  xdg = {
    enable = true;
    userDirs = {
      enable            = true;
      createDirectories = true;
      setSessionVariables = false;  # new HM default: don't export XDG_*_DIR as session vars
      documents   = "${config.home.homeDirectory}/Documents";
      download    = "${config.home.homeDirectory}/Downloads";
      music       = "${config.home.homeDirectory}/Music";
      pictures    = "${config.home.homeDirectory}/Pictures";
      videos      = "${config.home.homeDirectory}/Videos";
    };
  };
}
