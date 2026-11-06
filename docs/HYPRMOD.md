# Hyprmod Integration for NixOS-Hyprland

## Overview

[hyprmod](https://github.com/BlueManCZ/hyprmod) is a native GTK4/libadwaita
settings application for Hyprland. It is consumed here as an upstream flake
input rather than a hand-written derivation.

## Wiring

Three places touch it:

- `flake.nix` — the `hyprmod` input, with `inputs.nixpkgs.follows = "nixpkgs"`
  so the flake does not pull a second nixpkgs pin, and a re-exported
  `packages.<system>.hyprmod` output.
- `modules/overlays.nix` — `inputs.hyprmod.overlays.default`, which makes
  `pkgs.hyprmod` available to every module and Home Manager.
- `modules/home/hyprland.nix` — `hyprmod` in `home.packages`, i.e. installed
  for the user session alongside `nwg-look`, `nwg-displays` and friends.

The upstream flake supplies `packages.<system>.hyprmod`,
`packages.<system>.default` and `overlays.default`; the overlay builds hyprmod
from the flake source (`self`), so the binary always matches the revision pinned
in `flake.lock`.

## Usage

```bash
# build the package on its own
nix build '.#hyprmod'

# run it
./result/bin/hyprmod
```

On an installed system it appears in the application launcher as "Hyprmod" (it
installs its own desktop entry, icon and metainfo).

## Dependencies

hyprmod needs five Python bindings that are not in nixpkgs yet:

- `hyprland-config`
- `hyprland-monitors`
- `hyprland-schema`
- `hyprland-socket`
- `hyprland-state`

The upstream `nix/hyprmod.nix` builds them inline with pinned hashes, tracking
[NixOS/nixpkgs#505419](https://github.com/NixOS/nixpkgs/pull/505419). They need
no maintenance here: this repo previously carried its own copies in `pkgs/`,
but they used `lib.fakeHash` placeholders and could not build.

## Checks

`nix flake check` covers the integration in two derivations:

- `checks.x86_64-linux.hyprmod` — builds the same derivation the overlay gives
  to modules, so a bad upstream rev fails here instead of at activation time.
- `checks.x86_64-linux.formatting` — runs `alejandra --check` over every `.nix`
  file in the flake (only `.nix` files are copied to the store, not `assets/`).

Nix also evaluates `nixosConfigurations.jak-hl` as part of the same command, so
a broken module wiring fails the check too. `nix flake check --no-build` evaluates
without building anything.

```bash
nix flake check                  # evaluate + build both checks + eval the system
nix flake check --no-build       # evaluation only, fastest
nix build '.#checks.x86_64-linux.formatting'   # just the formatting check
```

## Updating

hyprmod is updated by hand, together with the rest of the flake; there is no
scheduled job and no update pull request.

```bash
nix flake update            # every input, including hyprmod
nix flake update hyprmod    # or hyprmod on its own, leaving the rest pinned
nix flake check             # catches a revision that no longer builds
sudo nixos-rebuild switch --flake .#<host>
```

Running `nix flake check` between the update and the switch is what makes the
manual path safe: `checks.x86_64-linux.hyprmod` builds the new revision without
touching the running system. If upstream bumps a binding version or a
`pyproject.toml` floor, the change comes in with the input — no local edits are
required.

## Known caveats

- hyprmod does not edit the KooLDots files: upstream writes only to its own
  `hyprland-gui.conf`, or edits `hyprland.lua` directly in Lua mode. What that
  means for persistence is decided by the dotfiles, which preserve only
  `~/.config/hypr/UserConfigs/user_*.lua` across an upgrade and refresh
  everything else, `hyprland.lua` included.
- Practical consequence for a Lua setup: hyprmod's Lua mode saves into
  `hyprland.lua`, which the installer refreshes, so those edits are lost on a
  dotfile upgrade. Two ways to keep them: save the setup as a hyprmod profile and
  re-apply it afterwards (`hyprmod profile list`, `hyprmod profile apply <name>`),
  or move the resulting settings into a `UserConfigs/user_*.lua` file that
  `hyprland.lua` already `dofile`s, which is the tree the dotfiles preserve.
- Upstream's flake targets `x86_64-linux` and `aarch64-linux`; this repo only
  builds `x86_64-linux`.

## Further Reading

- [Hyprmod repository](https://github.com/BlueManCZ/hyprmod)
- [NixOS Python packaging](https://nixos.org/manual/nixpkgs/stable/#sec-python)
