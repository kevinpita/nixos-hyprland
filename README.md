# nixos-hyprland

Declarative Hyprland and Dank Material Shell configuration for NixOS.

## Use the modules

```nix
{
  inputs.nixos-hyprland.url = "github:kevinpita/nixos-hyprland";
}
```

Import `nixosModules.default`. ThinkPad battery controls are available through `nixosModules.thinkpadBattery`.

The default module links writable DMS settings and the Hyprland Lua configuration from `~/nixos-hyprland`. Override `programs.nixos-hyprland.configDirectory` when the checkout is in a different location.

`session.json` is not part of this repository. DMS stores private runtime state in `~/.local/state/DankMaterialShell/session.json`.

## Develop locally

Keep the GitHub input as the canonical lock. Use a local override to test uncommitted changes:

```bash
nix flake check ~/nixos-config \
  --no-write-lock-file \
  --override-input nixos-hyprland "path:$HOME/nixos-hyprland"
```

## Validate

```bash
nix fmt
nix flake check --all-systems
```
