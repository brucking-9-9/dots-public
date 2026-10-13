# ── Session environment ───────────────────────────────────────────────────
{ ... }:
{
  home.sessionVariables = {
    EDITOR = "hx";
    VISUAL = "hx";
    BROWSER = "firefox";
    MOZ_ENABLE_WAYLAND = "1";
    # Electron/Chromium apps (code-cursor) run native Wayland instead of
    # falling back to XWayland — sharper text, less latency.
    NIXOS_OZONE_WL = "1";
    # Hardware video decode (VA-API). iHD is the modern Intel media driver
    # for this GPU (Iris Plus 655) — without the pin, apps sometimes probe
    # the legacy i965 driver first. VDPAU-only apps get bridged onto the
    # same VA-API path by libvdpau-va-gl.
    LIBVA_DRIVER_NAME = "iHD";
    VDPAU_DRIVER = "va_gl";
  };

  # BROWSER only covers CLI tools; xdg-open / portals resolve links through
  # mimeapps.list, where ungoogled-chromium otherwise wins by default.
  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/http" = [ "firefox.desktop" ];
    "x-scheme-handler/https" = [ "firefox.desktop" ];
    "text/html" = [ "firefox.desktop" ];
    "application/xhtml+xml" = [ "firefox.desktop" ];
  };
}
