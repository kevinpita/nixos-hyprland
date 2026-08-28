{
  pkgs,
  username,
  ...
}:
let
  pixelBudsControl = pkgs.callPackage ../packages/pixel-buds-control/package.nix { };
  pixelBudsPlugin = pkgs.runCommand "pixel-buds-plugin" { } ''
    mkdir -p "$out"
    cp -a ${../config/dms/plugins/pixelBuds}/. "$out/"
    substituteInPlace "$out/PixelBudsWidget.qml" \
      --replace-fail '@pixel-buds-control@' '${pixelBudsControl}/bin/pixel-buds-control'
  '';
in
{
  home-manager.users.${username} = {
    home.packages = [ pixelBudsControl ];
    xdg.configFile."DankMaterialShell/plugins/pixelBuds".source = pixelBudsPlugin;
    systemd.user.services.dms.Unit.X-Restart-Triggers = [ pixelBudsPlugin ];
  };
}
