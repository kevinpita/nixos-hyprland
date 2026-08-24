{
  pkgs,
  username,
  ...
}:
let
  piSessionsPlugin = pkgs.runCommand "pi-sessions-plugin" { } ''
    mkdir -p "$out"
    cp -a ${../config/dms/plugins/piSessions}/. "$out/"
    substituteInPlace "$out/PiSessionsWidget.qml" \
      --replace-fail '@pi-session-status@' '${piSessionStatus}/bin/pi-session-status'
  '';
  piSessionStatus = pkgs.callPackage ../packages/pi-session-status/package.nix { };
in
{
  home-manager.users.${username} = {
    home.packages = [ piSessionStatus ];
    xdg.configFile."DankMaterialShell/plugins/piSessions".source = piSessionsPlugin;
    systemd.user.services.dms.Unit.X-Restart-Triggers = [ piSessionsPlugin ];
  };
}
