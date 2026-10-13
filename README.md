# dots

A cyberpunk-neon rice for [niri](https://github.com/YaLTeR/niri) on NixOS,
managed with [home-manager](https://github.com/nix-community/home-manager).
It runs daily on an Apple T2 MacBook, but nothing in here needs that hardware
except `modules/power/quiet.nix` (see below).

| Piece          | What                                                                 |
| -------------- | -------------------------------------------------------------------- |
| Compositor     | niri (`config/niri/config.kdl`, `modules/wm/niri.nix`)               |
| Bar            | [quickshell](https://quickshell.org) bottom rail with app / media / system islands, launcher, notification daemon (`config/quickshell/bottom`, `modules/bar/quickshell-bottom.nix`) |
| Bar (fallback) | waybar, adapted from [cebem1nt/dotfiles](https://github.com/cebem1nt/dotfiles) (`config/waybar`, `modules/bar/waybar.nix`) |
| Terminal       | kitty with the built-in `cyberpunk` theme (`modules/terminal/kitty.nix`) |
| Prompt         | starship, colours from kitty's cyberpunk mapped onto the [SilkCircuit](https://github.com/hyperb1iss/silkcircuit) layout with [tr3ss](https://github.com/tr3ss/starship-themes) ice separators (`modules/shell/zsh.nix`) |
| Editor         | helix + nixd (`modules/editors/helix.nix`, `themes/helix/cyberpunk.toml`) |
| TUIs           | zellij, yazi, btop, discordo, spotify-player, all on the same palette (`themes/`) |
| Launcher       | fuzzel                                                               |
| Lock / idle    | swaylock, swayidle                                                   |
| OSD / power    | swayosd, wlogout, `quiet` mode                                       |
| Notifications  | the quickshell bar is the daemon; mako kept as a styled fallback     |
| Theming        | GTK / Qt dark, cursor (`modules/theming/`)                           |

## Palette

Every app is tuned to kitty's built-in **cyberpunk** theme:

| role       | hex       |
| ---------- | --------- |
| background | `#120B10` |
| text       | `#EEFFFF` |
| cyan       | `#00FFC8` |
| pink       | `#FF0055` |
| purple     | `#D57BFF` |
| yellow     | `#F4EF00` |
| green      | `#00FF9C` |
| selection  | `#563466` |
| dim        | `#6d5a78` |

## Layout

```
home.nix            # entry point — imports ./modules
modules/
  default.nix       # imports every module below
  identity.nix      # CHANGE ME: username / home dir / stateVersion
  xdg.nix, packages.nix, session.nix
  shell/zsh.nix     # zsh + starship prompt + zoxide
  editors/helix.nix
  terminal/         # kitty, zellij, yazi, discordo, spotify-player
  launcher/fuzzel.nix
  screenshot/swappy.nix
  bar/              # quickshell-bottom.nix, waybar.nix
  notifications/mako.nix
  lock/             # swaylock, swayidle
  clipboard/cliphist.nix
  osd/swayosd.nix
  power/            # wlogout, quiet (MacBook-specific, see below)
  monitoring/       # btop, ripgrep
  theming/          # gtk-qt, cursor
  wm/niri.nix       # sources config/niri/config.kdl
config/
  niri/config.kdl
  quickshell/bottom/   # the bar: QML + services
  waybar/              # config.jsonc, modules.jsonc, style.css, colors/, context/
scripts/waybar/        # helper scripts deployed to ~/.local/bin
themes/                # btop, helix, discordo, spotify-player, zellij colour files
```

Standalone files (QML, KDL, CSS, TOML) are referenced from the modules with
`.source = ./path` rather than inlined as Nix strings, so they keep their
syntax highlighting and can be test-run without a rebuild. The niri config
has one `@POLKIT_GNOME@` placeholder that `modules/wm/niri.nix` substitutes at
build time.

## Using it

1. Edit `modules/identity.nix`.
2. Point home-manager at `home.nix`, for example from a NixOS flake:

   ```nix
   home-manager.users.<you> = import ./dots/home.nix;
   ```

3. The system side needs, at minimum:

   ```nix
   programs.niri.enable = true;
   programs.xwayland.enable = true;
   xdg.portal = {
     enable = true;
     extraPortals = [ pkgs.xdg-desktop-portal-gnome pkgs.xdg-desktop-portal-gtk ];
     config.common.default = "*";
   };
   services.pipewire = { enable = true; pulse.enable = true; };
   services.power-profiles-daemon.enable = true;
   security.polkit.enable = true;
   programs.dconf.enable = true;
   fonts.packages = with pkgs; [ nerd-fonts.jetbrains-mono departure-mono fragment-mono terminus_font ];
   ```

   `packages.nix` pulls in the whole `nerd-fonts` set for the user; the bar
   uses *CaskaydiaCove Nerd Font Propo*, kitty uses *ProFont IIx Nerd Font Mono*.

4. Drop a wallpaper at `~/Pictures/Wallpapers/` (the bar's wallpaper strip
   reads that folder, `awww` paints it).

Pick modules à la carte if you don't want the whole thing: each file under
`modules/` is self-contained apart from the shared `config/` and `themes/`
files it sources.

### `quiet` mode

`modules/power/quiet.nix` pins the fans and caps the CPU on an Apple T2
MacBook (applesmc fan nodes, Intel RAPL, intel_pstate, t2fanrd). It is wired
into the waybar power module as a right-click, which calls `sudo -n`, so the
system config needs a NOPASSWD sudo rule for the `quiet-root` helper in the
user's home-manager profile. On other hardware drop it from
`modules/default.nix` and the `power-cycle` module from
`config/waybar/modules.jsonc`.

## Credits

- waybar config: [cebem1nt/dotfiles](https://github.com/cebem1nt/dotfiles)
- starship layout: [SilkCircuit](https://github.com/hyperb1iss/silkcircuit) (MIT)
- starship separators: [tr3ss/starship-themes](https://github.com/tr3ss/starship-themes) (MIT)
- kitty `cyberpunk` theme: shipped with kitty-themes

This tree is generated from a private config by a scrub script, so paths and
names are placeholders where they used to be personal.

## License

MIT, see [LICENSE](LICENSE).
