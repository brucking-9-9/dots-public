# ── Editor — helix ────────────────────────────────────────────────────────
# helix is also in environment.systemPackages; home-manager's copy shadows it
# cleanly and owns the config.  Remove from systemPackages when convenient.
{ config, lib, pkgs, ... }:
{
  programs.helix = {
    enable = true;
    defaultEditor = true;
    settings = {
      theme = "cyberpunk";
      editor = {
        "line-number"   = "relative";
        "color-modes"   = true;        # statusbar tints per mode (normal/insert/select)
        "indent-guides" = { render = true; };
        "cursor-shape"  = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };
        statusline = {
          left   = [ "mode" "spinner" "file-name" "file-modification-indicator" ];
          center = [];
          right  = [ "diagnostics" "selections" "position" "file-encoding" "file-type" ];
        };
        lsp = {
          display-messages = true;
          display-inlay-hints = true;
        };
        end-of-line-diagnostics = "hint";
      };
    };

    languages = {
      language-server = {
        nixd = {
          command = "nixd";
          args = ["--semantic-tokens=true"];
          config.nixd = {
            # nixpkgs.expr = "import ${flakeExpr}.${nixpkgsInput} { }";
            formatting.command = [ "${lib.getExe pkgs.nixfmt}"];
          };
        };
      };
    };
  };

  # Theme file lives at ../../themes/helix/cyberpunk.toml
  xdg.configFile."helix/themes/cyberpunk.toml".source =
    ../../themes/helix/cyberpunk.toml;
}
