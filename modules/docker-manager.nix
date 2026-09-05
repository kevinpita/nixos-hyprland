{
  config,
  pkgs,
  username,
  ...
}:
let
  dockerManagerPlugin = pkgs.fetchFromGitHub {
    owner = "LuckShiba";
    repo = "DmsDockerManager";
    rev = "v1.3.1";
    hash = "sha256-YDCwXF0dyuNy07voKvkLlKfHFfPkhSS4oGopn+EnM+0=";
  };
in
{
  home-manager.users.${username} = {
    home.packages = [
      config.virtualisation.podman.package
      pkgs.podman-compose
    ];
    xdg.configFile."DankMaterialShell/plugins/DockerManager".source = dockerManagerPlugin;
    systemd.user.services.dms.Unit.X-Restart-Triggers = [ dockerManagerPlugin ];
  };
}
