{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  cfg = config.programs.nixos-hyprland;
  sessionCommand = "${lib.getExe config.programs.uwsm.package} start -e -D Hyprland hyprland.desktop";
  omasnap = pkgs.stdenv.mkDerivation {
    pname = "omasnap";
    version = "1.19.1";

    src = pkgs.fetchFromGitHub {
      owner = "tobi";
      repo = "omasnap";
      rev = "a07a68d5b73c38166b470196dfeb1afeae75fbb6";
      hash = "sha256-9Dqtevs8TDKcfRuxuDwcNmhcgBThLRh6Qpkl6xTzmw8=";
    };

    nativeBuildInputs = with pkgs; [
      cmake
      ninja
      pkg-config
      qt6.wrapQtAppsHook
      wayland
    ];
    buildInputs = with pkgs; [
      kdePackages.layer-shell-qt
      qt6.qtbase
      wayland
    ];

    postPatch = ''
      substituteInPlace CMakeLists.txt \
        --replace-fail /usr/share/wayland-protocols ${pkgs.wayland-protocols}/share/wayland-protocols
    '';
    cmakeFlags = [ "-DBUILD_TESTING=OFF" ];
    qtWrapperArgs = [
      "--prefix PATH : ${
        lib.makeBinPath [
          config.programs.hyprland.package
          pkgs.tesseract
          pkgs.wl-clipboard
        ]
      }"
    ];

    meta = {
      description = "Native Wayland screenshot and annotation tool for Hyprland";
      homepage = "https://github.com/tobi/omasnap";
      license = lib.licenses.mit;
      mainProgram = "omasnap";
      platforms = lib.platforms.linux;
    };
  };
  superDoubleTap = pkgs.writeShellApplication {
    name = "super-double-tap";
    runtimeInputs = with pkgs; [
      coreutils
      util-linux
    ];
    text = ''
      runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$UID}"
      state_file="$runtime_dir/super-double-tap"
      now="$(date +%s%3N)"

      exec 9>"$state_file.lock"
      flock 9

      previous=0
      if [[ -r "$state_file" ]]; then
        candidate="$(<"$state_file")"
        if [[ "$candidate" =~ ^[0-9]+$ ]]; then
          previous="$candidate"
        fi
      fi

      if (( now >= previous && now - previous <= 400 )); then
        rm -f "$state_file"
        exec ${lib.getExe config.programs.dms-shell.package} ipc call spotlight toggle
      fi

      printf '%s\n' "$now" > "$state_file"
    '';
  };
  tuigreetCommand = lib.escapeShellArgs [
    (lib.getExe pkgs.tuigreet)
    "--time"
    "--remember"
    "--asterisks"
    "--cmd"
    sessionCommand
  ];
in
{
  options.programs.nixos-hyprland.configDirectory = lib.mkOption {
    type = lib.types.str;
    default = "/home/${username}/nixos-hyprland";
    description = "Absolute path to the writable nixos-hyprland checkout";
  };

  config = {
    programs.hyprland = {
      enable = true;
      withUWSM = true;
    };

    services.greetd = {
      enable = true;
      useTextGreeter = true;
      settings = {
        default_session.command = tuigreetCommand;
        initial_session = {
          command = sessionCommand;
          user = username;
        };
      };
    };

    programs.dms-shell = {
      enable = true;
      systemd.enable = false;
      enableSystemMonitoring = true;
      enableVPN = true;
      enableDynamicTheming = true;
      enableAudioWavelength = false;
      enableCalendarEvents = false;
      enableClipboardPaste = true;
    };

    home-manager.users.${username} =
      { config, ... }:
      {
        home.pointerCursor = {
          enable = true;
          package = pkgs.adwaita-icon-theme;
          name = "Adwaita";
          size = 24;
        };

        xdg.configFile."hypr/hyprland.lua".source =
          config.lib.file.mkOutOfStoreSymlink "${cfg.configDirectory}/config/hypr/hyprland.lua";

        home.packages = with pkgs; [
          inter
          libnotify
          nixos-artwork.wallpapers.catppuccin-mocha
          omasnap
          playerctl
          superDoubleTap
        ];

        systemd.user.services.dms = {
          Unit = {
            Description = "Dank Material Shell (DMS)";
            PartOf = [ "graphical-session.target" ];
            After = [ "graphical-session.target" ];
            Requisite = [ "graphical-session.target" ];
          };
          Service = {
            Type = "dbus";
            BusName = "org.freedesktop.Notifications";
            ExecStart = "${lib.getExe pkgs.dms-shell} run --session";
            ExecReload = "${lib.getExe' pkgs.procps "pkill"} -USR1 -x dms";
            Restart = "on-failure";
            RestartSec = "1.23s";
            SuccessExitStatus = "143 SIGTERM";
            TimeoutStopSec = "10s";
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };

        xdg.configFile = {
          "DankMaterialShell/settings.json".source =
            config.lib.file.mkOutOfStoreSymlink "${cfg.configDirectory}/config/dms/settings.json";
          "DankMaterialShell/.firstlaunch".text = "";
          "DankMaterialShell/.changelog-1.5".text = "";
        };
      };
  };
}
