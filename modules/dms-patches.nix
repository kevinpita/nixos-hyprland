{
  nixpkgs.overlays = [
    (_: prev: {
      dms-shell = prev.dms-shell.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          substituteInPlace $out/share/quickshell/dms/Modules/ControlCenter/BuiltinPlugins/TailscaleWidget.qml \
            --replace-fail 'color: peerMouseArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceLight' \
            'color: peerMouseArea.containsMouse ? Theme.primaryContainer : Theme.surfaceContainerHighest' \
            --replace-fail 'z: -1' $'id: peerMouseArea\n                                        z: -1'
        '';
      });
    })
  ];
}
