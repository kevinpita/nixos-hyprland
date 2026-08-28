{
  nixpkgs.overlays = [
    (_: prev: {
      dms-shell = prev.dms-shell.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          workspace_switcher=$out/share/quickshell/dms/Modules/DankBar/Widgets/WorkspaceSwitcher.qml
          chmod u+w "$(dirname "$workspace_switcher")" "$workspace_switcher"
          patch -d $out/share/quickshell/dms -p2 < ${../patches/workspace-switcher-drag-reorder.patch}

          substituteInPlace $out/share/quickshell/dms/Modules/ControlCenter/BuiltinPlugins/TailscaleWidget.qml \
            --replace-fail 'color: peerMouseArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceLight' \
            'color: peerMouseArea.containsMouse ? Theme.primaryContainer : Theme.surfaceContainerHighest' \
            --replace-fail 'z: -1' $'id: peerMouseArea\n                                        z: -1'
        '';
      });
    })
  ];
}
