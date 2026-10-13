# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
{inputs, ...}: {
  nixpkgs.overlays = [
    (final: prev: {
      waybar-weather = final.callPackage ../pkgs/waybar-weather.nix {};
    })

    # typescript-language-server 6.0.2 (used by nixvim/neovim) ships a stale
    # pnpm dependency hash in the pinned nixpkgs revision (7fd4004, Oct 11 2026):
    #   declared: sha256-MUSxDMlbG21KSesGdEvqa2kEpuVfLlXRUX1qV/FGsSo=
    #   actual:   sha256-xR/EF60lVBsITKgH7wCM2wHM46PFQevD51KfCENSUH4=
    # Upstream fixed this in NixOS/nixpkgs@ac7b1aa ("typescript-language-server:
    # fix pnpm hash"), but that commit is only on master and has not landed in
    # the nixos-unstable branch we track yet, so patch it locally for now.
    # TODO: remove this overlay once nixos-unstable contains ac7b1aa.
    (final: prev: {
      typescript-language-server = prev.typescript-language-server.overrideAttrs (old: {
        pnpmDeps = old.pnpmDeps.override {
          hash = "sha256-xR/EF60lVBsITKgH7wCM2wHM46PFQevD51KfCENSUH4=";
        };
      });
    })
  ];
}
