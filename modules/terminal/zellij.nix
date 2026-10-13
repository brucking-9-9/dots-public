# ── Terminal multiplexer — zellij ─────────────────────────────────────────
{ ... }:
{
  programs.zellij = {
    enable = true;
    settings = {
      theme = "cyberpunk";
    };
  };

  # Theme file lives at ../../themes/zellij/cyberpunk.kdl
  # (palette matched to kitty's "cyberpunk" theme). zellij auto-loads any
  # *.kdl under ~/.config/zellij/themes/.
  xdg.configFile."zellij/themes/cyberpunk.kdl".source =
    ../../themes/zellij/cyberpunk.kdl;
}
