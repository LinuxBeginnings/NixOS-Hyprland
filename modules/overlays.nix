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

      # Fix dwarfs 0.14.0 build with modern GCC (missing <cstring>) and fmt 12 incompatibility
      dwarfs =
        (prev.dwarfs.override {
          fmt = prev.fmt_11;
        }).overrideAttrs
        (old: {
          preConfigure =
            (old.preConfigure or "")
            + ''
              export CXXFLAGS="-include cstring ''${CXXFLAGS:-}"
            '';
        });
    })
  ];
}
