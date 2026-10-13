# Home Manager
#
# This file just wires up modules/default.nix, which imports every piece
# below. See modules/ for the actual configuration, themes/ for standalone
# theme files, scripts/ for standalone shell scripts, and config/ for
# other standalone config files (e.g. niri's KDL config).
{ config, lib, pkgs, ... }:
{
  imports = [ ./modules ];
}
