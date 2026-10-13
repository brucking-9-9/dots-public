# ── GTK theming ───────────────────────────────────────────────────────────
{ pkgs, ... }:
{
  gtk = {
    enable = true;
    theme = {
      name    = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name    = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
    cursorTheme = {
      name    = "Adwaita";
      package = pkgs.adwaita-icon-theme;
      size    = 24;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
    # New HM default (stateVersion >= 26.05): don't force the gtk3 theme name
    # onto gtk4. Dark preference is still carried by extraConfig + dconf below.
    gtk4.theme = null;
  };

  # xdg-desktop-portal-gnome reads this key and advertises the dark
  # preference to all portal-aware apps (Firefox, Flatpaks, etc.)
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  # ── Qt theming ────────────────────────────────────────────────────────────
  # Without this, Qt apps (Steam's older dialogs, anything Qt you install
  # later) ignore the GTK dark theme above and render with plain default
  # widgets. This points Qt at the gtk3 platform theme so it just reuses
  # the Adwaita-dark settings instead of needing a separate qt5ct/qt6ct +
  # Kvantum setup. Qt theming on Linux is a genuinely fiddly corner — if
  # some app still looks unstyled, qt6ct + Kvantum is the fallback.
  qt = {
    enable            = true;
    platformTheme.name = "gtk3";
    style.name          = "adwaita-dark";
  };
}
