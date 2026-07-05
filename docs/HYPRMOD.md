# Hyprmod Integration for NixOS-Hyprland

## Overview

This flake provides a NixOS-compatible package for [hyprmod](https://github.com/BlueManCZ/hyprmod), a native GTK4/libadwaita settings app for Hyprland.

## Usage

### Build the Package

To build hyprmod from the flake:

```bash
nix build '.#hyprmod'
```

### Run Hyprmod

After building, you can run it directly:

```bash
./result/bin/hyprmod
```

Or install it into your system via the flake output.

### Add to System Packages

To include hyprmod in your system packages, uncomment the line in `modules/packages.nix`:

```nix
# In modules/packages.nix around line 133:
hyprmod  # custom package (flake output .#hyprmod); uncomment when hyprland-* deps are available or packaged
```

Then rebuild your system:

```bash
nix flake update
sudo nixos-rebuild switch --flake .#your-host
```

## Package Configuration

- **Source**: Fetches from [github:BlueManCZ/hyprmod](https://github.com/BlueManCZ/hyprmod)
- **Build system**: Python 3.12+ with hatchling
- **Runtime dependencies**:
  - `pygobject3` (GTK4 bindings)
  - `gtk4`, `libadwaita`, `libcanberra-gtk3` (GTK/Adwaita UI libraries)

## Known Limitations

Hyprmod depends on several hyprland-* Python packages:
- `hyprland-config`
- `hyprland-schema`
- `hyprland-state`
- `hyprland-monitors`
- `hyprland-socket`

These packages are **not yet in nixpkgs** and need to be packaged separately (or added as overlays) for the full build to succeed. Currently, the hyprmod package definition includes them as commented placeholders.

To complete integration, you can:

1. **Create overlays** in `modules/overlays.nix` for the hyprland-* Python packages
2. **Add them as custom modules** under `pkgs/`
3. **Wait for upstream nixpkgs** to include these packages

## File Structure

- `pkgs/hyprmod.nix` — Package derivation
- `flake.nix` — Flake input and output configuration
- `modules/packages.nix` — Optional system package inclusion

## Development

To work on hyprmod source code modifications:

1. Clone your fork: `git clone https://github.com/your-fork/hyprmod.git`
2. Update the `hyprmod-src` input in `flake.nix` to point to your fork
3. Rebuild the package

## Further Reading

- [Hyprmod Repository](https://github.com/BlueManCZ/hyprmod)
- [NixOS Python Packaging](https://nixos.org/manual/nixpkgs/stable/#sec-python)
