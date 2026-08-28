{
  dankcalendar,
  pkgs,
  username,
  ...
}:
let
  dankCalendarAgenda = pkgs.fetchFromGitHub {
    owner = "arqueon";
    repo = "dms-dankcalendar";
    rev = "a592b4954ded272303d76fe5c85663a0fad1cdaf";
    hash = "sha256-Ud7I1+EIDCXep/02mCR8wwu1D66jy/F6VzjX0tvsvbo=";
  };
in
{
  services.gnome.gnome-keyring.enable = true;

  home-manager.sharedModules = [ dankcalendar.homeModules.default ];

  home-manager.users.${username} = {
    programs.dank-calendar = {
      enable = true;
      systemd = {
        enable = true;
        target = "graphical-session.target";
      };
    };

    home.packages = [ pkgs.jq ];

    xdg.configFile."DankMaterialShell/plugins/dankCalendarAgenda".source = dankCalendarAgenda;

    systemd.user.services.dms.Unit = {
      After = [ "dcal.service" ];
      Wants = [ "dcal.service" ];
      X-Restart-Triggers = [ dankCalendarAgenda ];
    };
  };
}
