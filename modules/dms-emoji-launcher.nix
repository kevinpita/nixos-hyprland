{
  pkgs,
  username,
  ...
}:
let
  emojiLauncherPlugin = pkgs.fetchFromGitHub {
    owner = "devnullvoid";
    repo = "dms-emoji-launcher";
    rev = "8ff394e3ddfcb2fd755ed2e7b4c6f01f3e26e596";
    hash = "sha256-fmIddCvACwO8wbAtLBMtDnEXXQJjb7+o2s4jW3f8VIU=";
  };
in
{
  home-manager.users.${username} = {
    home.packages = [ pkgs.wl-clipboard ];
    xdg.configFile."DankMaterialShell/plugins/emojiLauncher".source = emojiLauncherPlugin;
    systemd.user.services.dms.Unit.X-Restart-Triggers = [ emojiLauncherPlugin ];
  };
}
