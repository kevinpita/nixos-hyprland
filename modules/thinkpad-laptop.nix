{ lib, pkgs, ... }:
let
  keyboardBacklightOsd = pkgs.writeTextFile {
    name = "keyboard-backlight-osd";
    destination = "/bin/keyboard-backlight-osd";
    executable = true;
    text = ''
      #!${lib.getExe pkgs.python3}
      from pathlib import Path
      from subprocess import DEVNULL, run
      from time import sleep

      brightness_file = Path("/sys/class/leds/tpacpi::kbd_backlight/brightness")
      dms = "${lib.getExe pkgs.dms-shell}"
      percentages = {0: "0", 1: "51", 2: "100"}

      def read_level():
          return int(brightness_file.read_text().strip())

      def show_osd(level):
          percentage = percentages.get(level)
          if percentage is None:
              return
          run(
              [dms, "ipc", "call", "brightness", "set", percentage, "leds:tpacpi::kbd_backlight"],
              stdout=DEVNULL,
              stderr=DEVNULL,
              check=False,
          )

      previous = read_level()
      while True:
          sleep(0.1)
          current = read_level()
          if current == previous:
              continue
          previous = current
          show_osd(current)
    '';
  };
in
{
  systemd.user.services.keyboard-backlight-osd = {
    description = "Show keyboard backlight changes in the DMS OSD";
    after = [ "dms.service" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    unitConfig.ConditionPathExists = "/sys/class/leds/tpacpi::kbd_backlight/brightness";
    serviceConfig = {
      ExecStart = "${keyboardBacklightOsd}/bin/keyboard-backlight-osd";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };
}
