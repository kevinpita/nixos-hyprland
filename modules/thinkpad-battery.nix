{
  lib,
  pkgs,
  username,
  ...
}:
let
  chargeStartThreshold = 75;
  chargeStopThreshold = 80;
in
{
  nixpkgs.overlays = [
    (_: prev: {
      dms-shell = prev.dms-shell.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          battery_popout=$out/share/quickshell/dms/Modules/DankBar/Popouts/BatteryPopout.qml
          chmod u+w "$(dirname "$battery_popout")" "$battery_popout"
          patch -d $out/share/quickshell/dms -p2 < ${../patches/battery-popout.patch}
          substituteInPlace "$battery_popout" \
            --replace-fail '@batteryChargeStatus@' '${
              lib.getExe (
                prev.writeShellApplication {
                  name = "battery-charge-status";
                  runtimeInputs = [ prev.coreutils ];
                  text = ''
                    battery=/sys/class/power_supply/BAT0
                    start_file="$battery/charge_control_start_threshold"
                    stop_file="$battery/charge_control_end_threshold"

                    if [[ ! -r "$start_file" || ! -r "$stop_file" ]]; then
                      printf '%s\n' '{"available":false,"start":0,"end":0,"configuredStart":${toString chargeStartThreshold},"configuredEnd":${toString chargeStopThreshold}}'
                      exit 0
                    fi

                    start=$(cat "$start_file")
                    stop=$(cat "$stop_file")

                    if [[ ! $start =~ ^[0-9]+$ || ! $stop =~ ^[0-9]+$ ]]; then
                      exit 1
                    fi

                    printf '{"available":true,"start":%d,"end":%d,"configuredStart":${toString chargeStartThreshold},"configuredEnd":${toString chargeStopThreshold}}\n' "$start" "$stop"
                  '';
                }
              )
            }' \
            --replace-fail '@sudo@' '/run/wrappers/bin/sudo' \
            --replace-fail '@tlp@' '${lib.getExe prev.tlp}'
        '';
      });
    })
  ];

  security.sudo.extraRules = [
    {
      users = [ username ];
      runAs = "root";
      commands = [
        {
          command = "${lib.getExe pkgs.tlp} fullcharge BAT0";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${lib.getExe pkgs.tlp} setcharge BAT0";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  services = {
    power-profiles-daemon.enable = false;

    tlp = {
      enable = true;
      pd.enable = true;
      settings = {
        START_CHARGE_THRESH_BAT0 = chargeStartThreshold;
        STOP_CHARGE_THRESH_BAT0 = chargeStopThreshold;
      };
    };
  };
}
