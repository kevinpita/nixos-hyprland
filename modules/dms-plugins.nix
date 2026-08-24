{
  config,
  username,
  ...
}:
let
  cfg = config.programs.nixos-hyprland;
in
{
  home-manager.users.${username} =
    { config, ... }:
    {
      xdg.configFile."DankMaterialShell/plugin_settings.json".source =
        config.lib.file.mkOutOfStoreSymlink "${cfg.configDirectory}/config/dms/plugin_settings.json";
    };
}
