# nixos-hyprland

Declarative Hyprland and Dank Material Shell configuration for NixOS.

## Use the modules

```nix
{
  inputs.nixos-hyprland.url = "github:kevinpita/nixos-hyprland";
}
```

Import `nixosModules.default`. ThinkPad battery controls are available through `nixosModules.thinkpadBattery`.

The default module links writable DMS settings and loads the Hyprland Lua configuration from `~/nixos-hyprland`. Override `programs.nixos-hyprland.configDirectory` when the checkout is in a different location.

Set `programs.nixos-hyprland.hostConfig` to an absolute Lua file path for monitor layout and other host-specific rules. The host file runs before the shared configuration.

`session.json` is not part of this repository. DMS stores private runtime state in `~/.local/state/DankMaterialShell/session.json`.

## Connect Google Calendar

The default module starts DankCalendar and adds its agenda widget to the DMS bar. After the first rebuild, connect an account:

```bash
dcal account add google
```

Complete the Google authorization in the browser. DankCalendar stores account data outside this repository and keeps OAuth tokens in the desktop keyring. Use `dcal sync` to request an immediate sync.

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
