{ pkgs, username, ... }:
let
  timeManagerPlugin = pkgs.fetchFromGitHub {
    owner = "Zhainy";
    repo = "DmsTimeManager";
    rev = "2ad012c14c10c0e667ca4e48c8958d4b2206f84f";
    hash = "sha256-ODDjsD+X/hLYI47r2GSDCoHTUHavL91G2REJQ/9f9qs=";
  };
in
{
  home-manager.users.${username} = {
    home.packages = with pkgs; [
      libcanberra-gtk3
      libnotify
      pulseaudio
    ];

    xdg.configFile."DankMaterialShell/plugins/timeManager".source = timeManagerPlugin;
    systemd.user.services.dms.Unit.X-Restart-Triggers = [ timeManagerPlugin ];
  };
}
