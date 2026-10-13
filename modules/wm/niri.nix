# ── Niri compositor ───────────────────────────────────────────────────────
# The raw config lives at ../../config/niri/config.kdl. It contains two
# placeholders — @POLKIT_GNOME@ (${pkgs.polkit_gnome}) and
# @XWAYLAND_SATELLITE@ (the pinned build below) — because Nix string
# interpolation can't happen inside a plain file on disk, so they're
# substituted back in here at build time.
{ config, lib, pkgs, ... }:
let
  # xwayland-satellite 0.8.2 (nixpkgs, since the 2026-09-06 flake update)
  # regressed override-redirect popups: it hands X11 focus back to the
  # parent ~50 ms after a menu maps, so CEF/Steam's main-client dropdowns
  # close instantly (the Friends/chat dropdowns are in-page, so they
  # survive). Upstream fix is PR #494 (issues #468/#489), merged
  # 2026-09-09, not in any tagged release yet. Pin to that commit; drop
  # this override (and the path block in config.kdl) once nixpkgs ships a
  # release containing it.
  xwayland-satellite-fixed = pkgs.xwayland-satellite.overrideAttrs (old: rec {
    version = "0.8.2-unstable-2026-09-09";
    src = pkgs.fetchFromGitHub {
      owner = "Supreeeme";
      repo = "xwayland-satellite";
      rev = "add2795134593faafce60e404a0a75df68e9ee0c";
      hash = "sha256-0TxfMgqW0/BLD4M942c5DCKYrtPvzsPJwvdcco4LQUM=";
    };
    # Cargo.lock changed since v0.8.2, so the vendored deps need a new hash.
    cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
      inherit src;
      hash = "sha256-s1gl9eR6Mt2QLrhfcowstPFjzwE/lz4PJhJzWYHoIHg=";
    };
  });
in
{
  # Also on the user PATH, ahead of the system copy, so `xwayland-satellite
  # --version` and anything else that spawns it by name get the same build.
  home.packages = [ xwayland-satellite-fixed ];

  home.file.".config/niri/config.kdl".text =
    lib.replaceStrings
      [ "@POLKIT_GNOME@" "@XWAYLAND_SATELLITE@" ]
      [ "${pkgs.polkit_gnome}" "${xwayland-satellite-fixed}" ]
      (builtins.readFile ../../config/niri/config.kdl);
}
