{
  description = "Declarative Hyprland and Dank Material Shell configuration for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    dankcalendar = {
      url = "github:AvengeMedia/dankcalendar";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      dankcalendar,
      home-manager,
      nixpkgs,
    }:
    let
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      formatter = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.writeShellApplication {
          name = "nixos-hyprland-format";
          runtimeInputs = [
            pkgs.fd
            pkgs.nixfmt
          ];
          text = ''
            if [ "$#" -gt 0 ]; then
              exec nixfmt "$@"
            fi
            fd --type f --extension nix --exec nixfmt
          '';
        }
      );

      packages = forAllSystems (system: {
        pixel-buds-control =
          nixpkgs.legacyPackages.${system}.callPackage ./packages/pixel-buds-control/package.nix
            { };
        pi-session-status =
          nixpkgs.legacyPackages.${system}.callPackage ./packages/pi-session-status/package.nix
            { };
        default = self.packages.${system}.pi-session-status;
      });

      nixosModules = {
        default = {
          imports = [ (import ./module.nix) ];
          _module.args = { inherit dankcalendar; };
        };
        thinkpadBattery = import ./modules/thinkpad-battery.nix;
      };

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          evaluated = nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs.username = "kevin";
            modules = [
              self.nixosModules.default
              self.nixosModules.thinkpadBattery
              home-manager.nixosModules.home-manager
              {
                system.stateVersion = "25.11";
                users.users.kevin = {
                  isNormalUser = true;
                  group = "users";
                  home = "/home/kevin";
                };
                home-manager.users.kevin.home.stateVersion = "25.11";
              }
            ];
          };
          xdgFiles = evaluated.config.home-manager.users.kevin.xdg.configFile;
          requiredXdgFiles = [
            "DankMaterialShell/plugin_settings.json"
            "DankMaterialShell/plugins/aiOverviewControl"
            "DankMaterialShell/plugins/Calculator"
            "DankMaterialShell/plugins/DockerManager"
            "DankMaterialShell/plugins/dankCalendarAgenda"
            "DankMaterialShell/plugins/emojiLauncher"
            "DankMaterialShell/plugins/piSessions"
            "DankMaterialShell/plugins/pixelBuds"
            "DankMaterialShell/plugins/workspaceFinder"
            "DankMaterialShell/settings.json"
            "hypr/hyprland.lua"
          ];
          missingXdgFiles = builtins.filter (name: !(builtins.hasAttr name xdgFiles)) requiredXdgFiles;
        in
        {
          ai-overview-control = xdgFiles."DankMaterialShell/plugins/aiOverviewControl".source;
          calculator-plugin = xdgFiles."DankMaterialShell/plugins/Calculator".source;
          dank-calendar = evaluated.config.home-manager.users.kevin.programs.dank-calendar.package;
          dank-calendar-plugin = xdgFiles."DankMaterialShell/plugins/dankCalendarAgenda".source;
          dms-shell = evaluated.config.programs.dms-shell.package;
          docker-manager-plugin = xdgFiles."DankMaterialShell/plugins/DockerManager".source;
          emoji-launcher-plugin = xdgFiles."DankMaterialShell/plugins/emojiLauncher".source;
          pi-sessions-plugin = xdgFiles."DankMaterialShell/plugins/piSessions".source;
          pixel-buds-control = self.packages.${system}.pixel-buds-control;
          pixel-buds-plugin = xdgFiles."DankMaterialShell/plugins/pixelBuds".source;
          workspace-finder-plugin = xdgFiles."DankMaterialShell/plugins/workspaceFinder".source;

          configuration =
            pkgs.runCommand "nixos-hyprland-configuration-check"
              {
                nativeBuildInputs = [
                  pkgs.jq
                  pkgs.lua
                ];
              }
              ''
                jq empty ${./config/dms/settings.json} ${./config/dms/plugin_settings.json}
                luac -p ${./config/hypr/hyprland.lua}
                touch "$out"
              '';

          module =
            assert evaluated.config.programs.hyprland.enable;
            assert evaluated.config.programs.dms-shell.enable;
            assert evaluated.config.services.gnome.gnome-keyring.enable;
            assert evaluated.config.services.greetd.enable;
            assert evaluated.config.home-manager.users.kevin.programs.dank-calendar.enable;
            assert evaluated.config.home-manager.users.kevin.programs.dank-calendar.systemd.enable;
            assert evaluated.config.services.tlp.enable;
            assert evaluated.config.services.tlp.settings.START_CHARGE_THRESH_BAT0 == 75;
            assert evaluated.config.services.tlp.settings.STOP_CHARGE_THRESH_BAT0 == 80;
            assert evaluated.config.programs.nixos-hyprland.configDirectory == "/home/kevin/nixos-hyprland";
            assert evaluated.config.programs.nixos-hyprland.hostConfig == null;
            assert missingXdgFiles == [ ];
            pkgs.writeText "nixos-hyprland-module-check" (
              builtins.toJSON {
                calendar = evaluated.config.home-manager.users.kevin.programs.dank-calendar.enable;
                configDirectory = evaluated.config.programs.nixos-hyprland.configDirectory;
                dms = evaluated.config.programs.dms-shell.enable;
                hyprland = evaluated.config.programs.hyprland.enable;
                tlp = evaluated.config.services.tlp.enable;
              }
            );

          pixel-buds-control-tests =
            pkgs.runCommand "pixel-buds-control-test"
              {
                nativeBuildInputs = [ pkgs.jq ];
              }
              ''
                PIXEL_BUDS_CONTROL_BIN=${self.packages.${system}.pixel-buds-control}/bin/pixel-buds-control \
                  bash ${./packages/pixel-buds-control/test.sh}
                touch "$out"
              '';

          pi-sessions =
            pkgs.runCommand "pi-sessions-test"
              {
                nativeBuildInputs = [
                  pkgs.bash
                  pkgs.jq
                ];
              }
              ''
                PI_SESSIONS_STATUS_BIN=${self.packages.${system}.pi-session-status}/bin/pi-session-status \
                  bash ${./packages/pi-session-status/test.sh}
                touch "$out"
              '';
        }
      );
    };
}
