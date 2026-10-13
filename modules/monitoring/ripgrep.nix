# ── ripgrep ───────────────────────────────────────────────────────────────
{ ... }:
{
  programs.ripgrep = {
    enable    = true;
    arguments = [
      "--smart-case"   # case-insensitive unless pattern contains uppercase
      "--hidden"       # search hidden files and dirs
      "--glob=!.git/"  # …but skip .git
    ];
  };
}
