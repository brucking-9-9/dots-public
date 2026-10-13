{ pkgs,... }:
{

  programs.yazi = {
    enable  = true;
    enableZshIntegration = true;
    shellWrapperName = "y";   # new HM default (was "yy"); launch yazi-with-cd via `y`
  };
   }
 
