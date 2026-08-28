{ pkgs, username, ... }:
let
  calculatorPlugin = pkgs.fetchFromGitHub {
    owner = "rochacbruno";
    repo = "DankCalculator";
    rev = "0.3.3";
    hash = "sha256-hiqrO8WkzmWGVlUrzxmffUZBs4t1QM2mMTBUxZqCIyU=";
  };
in
{
  home-manager.users.${username} = {
    xdg.configFile."DankMaterialShell/plugins/Calculator".source = calculatorPlugin;
    systemd.user.services.dms.Unit.X-Restart-Triggers = [ calculatorPlugin ];
  };
}
