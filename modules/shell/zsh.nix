{ config, ... }:
{
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh"; # new HM default: keep zsh dotfiles under ~/.config/zsh

    initContent = ''
      command -v pfetch >/dev/null && pfetch
    '';

    sessionVariables = {
      TODO_DIR = "$HOME/Documents/todo";
      TODO_FILE = "$TODO_DIR/todo.txt";
      DONE_FILE = "$HOME/Documents/todo/done.txt";

    };
    shellAliases = {
      switch = "sudo -H nixos-rebuild switch --flake /etc/nixos";
      update = "sudo -H nix flake update --flake /etc/nixos";
      build = "sudo -H nixos-rebuild build --flake /etc/nixos";
      edit = "sudo hx /etc/nixos";
      ls = "ls --color=auto";
      ll = "ls -lh --color=auto";
      la = "ls -lah --color=auto";
      gs = "git status";
      tux = "tuxedo";
    };
  };

  # ── Prompt — starship ────────────────────────────────────────────────
  # Co-located here instead of its own module file because /etc/nixos/.git
  # is root-owned and new files need a sudo git add before the flake sees
  # them.
  # Look (chosen 2026-09-06 from live previews): every part is lifted from
  # published prior art, nothing hand-drawn —
  #   * module set, icons, layout, ➤ prompt: SilkCircuit Neon starship theme
  #     (github.com/hyperb1iss/silkcircuit, MIT), whose purple/pink/cyan
  #     family is the closest published match to the kitty theme;
  #   * separators: "ice waveform" glyphs U+E0CA / U+E0C8 as used by the
  #     tr3ss "viking" starship theme (github.com/tr3ss/starship-themes, MIT);
  #   * colours: SilkCircuit's hexes mapped role-for-role onto kitty's
  #     built-in "cyberpunk" theme (bg #120B10, selection #563466, color4
  #     #6766B3, color13 #C592FF, color5 #D57BFF, fg #FF0055, cursor #00FFC8).
  # right_format (duration / RAM / battery) is carried over from the previous
  # config as info-only additions.
  # Generated from the preview TOML; the settings block below IS the theme.
  programs.starship = {
    enable = true;
    settings = {
      format = "[](bg:#120B10 fg:#563466)$os$username[ ](bold bg:#563466)[](bg:#6766B3 fg:#563466)$directory[](bg:#C592FF fg:#6766B3)$git_branch$git_status[](bg:#D57BFF fg:#C592FF)$nodejs$python$rust$golang$java$kotlin$gradle$c$lua$kubernetes[](bg:#FF0055 fg:#D57BFF)[](bg:#120B10 fg:#FF0055)$character";
      add_newline = false;
      command_timeout = 1000;
      character = {
        success_symbol = "[➤](bold fg:#00FFC8) ";
        error_symbol = "[➤](bold fg:#FF0055) ";
      };
      os = {
        format = "[ $symbol]($style)";
        style = "bold fg:#00FFC8 bg:#563466";
        disabled = false;
        symbols = {
          Alpine = "";
          Amazon = "";
          Android = "";
          Arch = "";
          CachyOS = "";
          CentOS = "";
          Debian = "";
          DragonFly = "🐉";
          Emscripten = "🔗";
          EndeavourOS = "";
          Fedora = "";
          FreeBSD = "";
          Garuda = "";
          Gentoo = "";
          HardenedBSD = "聯";
          Illumos = "🐦";
          Linux = "";
          Macos = "";
          Manjaro = "";
          Mariner = "";
          MidnightBSD = "🌘";
          Mint = "";
          NetBSD = "";
          NixOS = "";
          OpenBSD = "";
          OpenCloudOS = "☁️";
          openEuler = "";
          openSUSE = "";
          OracleLinux = "⊂⊃";
          Pop = "";
          Raspbian = "";
          Redhat = "";
          RedHatEnterprise = "";
          Redox = "🧪";
          Solus = "";
          SUSE = "";
          Ubuntu = "";
          Unknown = "";
          Windows = "";
        };
      };
      username = {
        style_user = "bold fg:#00FFC8 bg:#563466";
        style_root = "bold fg:#FF0055 bg:#563466";
        format = "[ $user]($style)";
        disabled = false;
        show_always = true;
      };
      hostname = {
        style = "bold fg:#00FFC8 bg:#563466";
        ssh_only = true;
        format = "[@$hostname]($style)";
        trim_at = ".";
        disabled = false;
      };
      directory = {
        truncation_length = 3;
        truncation_symbol = "…/";
        style = "bold fg:#EEFFFF bg:#6766B3";
        format = "[ $path ]($style)";
      };
      git_branch = {
        symbol = " ";
        style = "bold fg:#120B10 bg:#C592FF";
        format = "[ $symbol$branch ]($style)";
      };
      git_status = {
        ignore_submodules = true;
        style = "bold fg:#120B10 bg:#C592FF";
        format = "[$all_status]($style)";
      };
      nodejs = {
        symbol = " ";
        style = "bold fg:#120B10 bg:#D57BFF";
        format = "[ $symbol($version) ]($style)";
        disabled = false;
      };
      python = {
        symbol = " ";
        style = "bold fg:#120B10 bg:#D57BFF";
        format = "([ $symbol(\${virtualenv}) ]($style))";
        detect_extensions = [
          "py"
        ];
        detect_files = [
          "requirements.txt"
          "pyproject.toml"
          "Pipfile"
          "tox.ini"
          "setup.py"
        ];
        disabled = false;
      };
      rust = {
        symbol = "󱘗 ";
        style = "bold fg:#120B10 bg:#D57BFF";
        format = "[ $symbol($version) ]($style)";
        disabled = false;
      };
      golang = {
        symbol = "󰟓 ";
        style = "bold fg:#120B10 bg:#D57BFF";
        format = "[ $symbol($version) ]($style)";
        disabled = false;
      };
      java = {
        symbol = "󰬷 ";
        style = "bold fg:#120B10 bg:#D57BFF";
        format = "[ $symbol($version) ]($style)";
        disabled = false;
      };
      kotlin = {
        symbol = "󱈙 ";
        style = "bold fg:#120B10 bg:#D57BFF";
        format = "[ $symbol($version) ]($style)";
        disabled = false;
      };
      gradle = {
        symbol = "󱎐 ";
        style = "bold fg:#120B10 bg:#D57BFF";
        format = "[ $symbol($version) ]($style)";
        disabled = false;
      };
      c = {
        symbol = "󰙱 ";
        style = "bold fg:#120B10 bg:#D57BFF";
        format = "[ $symbol($version) ]($style)";
        disabled = false;
      };
      lua = {
        symbol = "󰢱 ";
        style = "bold fg:#120B10 bg:#D57BFF";
        format = "[ $symbol($version) ]($style)";
        disabled = false;
      };
      kubernetes = {
        symbol = "󱃾 ";
        format = "[ $symbol$context ]($style)";
        style = "bold fg:#120B10 bg:#D57BFF";
        disabled = false;
        contexts = [
          {
            context_pattern = ".*[Pp][Rr][Oo][Dd].*";
            context_alias = "PROD";
            style = "bold fg:#120B10 bg:#F4EF00";
            symbol = " ";
          }
          {
            context_pattern = "eks-[a-z]+-[a-z]+-\\d+-(?P<env>.*)";
            context_alias = "eks-$env";
            style = "bold fg:#120B10 bg:#D57BFF";
          }
          {
            context_pattern = ".*";
            style = "bold fg:#120B10 bg:#D57BFF";
          }
        ];
      };
      time = {
        disabled = true;
        format = "󱑍 [\\[ $time \\]]($style) ";
        time_format = "%T";
      };
      cmd_duration = {
        min_time = 2000;
        format = "took [$duration]($style) ";
        style = "bold fg:#C592FF";
      };
      battery = {
        full_symbol = "󰁹 ";
        charging_symbol = "󰂄 ";
        discharging_symbol = "󰂃 ";
        unknown_symbol = "󰁽 ";
        empty_symbol = "󰂎 ";
        disabled = false;
        display = [
          {
            threshold = 20;
            style = "bold fg:#FF0055";
          }
          {
            threshold = 100;
            style = "fg:#C592FF";
          }
        ];
      };
      package = {
        symbol = "󰏗 ";
        style = "bold fg:#C592FF";
        disabled = false;
      };
      shell = {
        fish_indicator = "󰈺 ";
        powershell_indicator = "󰨊 ";
        bash_indicator = "󱆃 ";
        zsh_indicator = "󱐋 ";
        unknown_indicator = "󰀣 ";
        style = "cyan bold";
        disabled = true;
      };
      right_format = "$cmd_duration$memory_usage$battery";
      memory_usage = {
        disabled = false;
        threshold = 75;
        symbol = "󰍛";
        format = "[$symbol $ram_pct ](fg:#FF0055)";
      };
    };
  };

  # Bash managed too so nix-shell — which spawns bash and sources
  # ~/.bashrc — gets the starship prompt instead of stock [nix-shell:..]$.
  programs.bash.enable = true;

  programs.zoxide.enable = true;
}
