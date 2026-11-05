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

    #  Packages from the justaguylinux flake inputs (justaguy.dev/drew).
    #  Exposed through pkgs so modules consume pkgs.ghee / pkgs.butterpal
    #  instead of reaching into inputs.* directly.
    (final: prev: {
      ghee = inputs.ghee.packages.${final.stdenv.hostPlatform.system}.ghee;
      butterpal = inputs.butterpal.packages.${final.stdenv.hostPlatform.system}.butterpal;
    })

  ];
}
