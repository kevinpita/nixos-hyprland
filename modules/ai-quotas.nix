{
  pkgs,
  username,
  ...
}:
let
  aiOverviewControlUpstream = pkgs.fetchFromGitHub {
    owner = "bernardopg";
    repo = "AiOverviewControl";
    rev = "v1.12.0";
    hash = "sha256-ELXTG1RW48sy/zJj9KVkSPEofTgD3BuS4HbNwkioGf4=";
  };
  aiOverviewControl = pkgs.runCommand "ai-overview-control-1.12.0-native" { } ''
    mkdir -p "$out"
    cp -a ${aiOverviewControlUpstream}/. "$out/"
    chmod -R u+w "$out"
    patch -d "$out" -p1 < ${../config/dms/plugins/aiOverviewControl/agy-cli-token.patch}
    cp ${../config/dms/plugins/aiOverviewControl/NativeQuotaWidget.qml} "$out/NativeQuotaWidget.qml"
    cp ${../config/dms/plugins/aiOverviewControl/NativeQuotaSettings.qml} "$out/NativeQuotaSettings.qml"
    substituteInPlace "$out/plugin.json" \
      --replace-fail '"component": "./AiOverviewControlWidget.qml"' '"component": "./NativeQuotaWidget.qml"' \
      --replace-fail '"settings": "./AiOverviewControlSettings.qml"' '"settings": "./NativeQuotaSettings.qml"'
  '';
in
{
  home-manager.users.${username} = {
    home.packages = with pkgs; [
      bash
      curl
      jq
      libsecret
    ];

    xdg.configFile."DankMaterialShell/plugins/aiOverviewControl" = {
      source = aiOverviewControl;
      recursive = true;
      force = true;
    };

    systemd.user.services.dms.Unit.X-Restart-Triggers = [ aiOverviewControl ];
  };
}
