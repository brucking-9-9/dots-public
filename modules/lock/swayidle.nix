# ── Idle / auto-lock — swayidle ───────────────────────────────────────────
{ config, ... }:
{
  services.swayidle = {
    enable   = true;
    timeouts = [
      {
        timeout = 300;
        command = "${config.programs.swaylock.package}/bin/swaylock -f";
      }
      {
        timeout = 600;
        command = "systemctl suspend";
      }
    ];
    # New HM schema: attrset keyed by event name, command as the value.
    events = {
      before-sleep = "${config.programs.swaylock.package}/bin/swaylock -f";
    };
  };
}
