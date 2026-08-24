{
  pkgs,
  username,
  ...
}:
let
  workspaceFinderPlugin = pkgs.runCommand "workspace-finder-plugin" { } ''
    mkdir -p "$out"
    cp -a ${../config/dms/plugins/workspaceFinder}/. "$out/"
  '';
in
{
  home-manager.users.${username} = {
    xdg.configFile."DankMaterialShell/plugins/workspaceFinder".source = workspaceFinderPlugin;
    systemd.user.services.dms.Unit.X-Restart-Triggers = [ workspaceFinderPlugin ];
  };
}
