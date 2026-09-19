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
  ];
}
