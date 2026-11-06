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

    #  hyprmod: GTK4/libadwaita settings app for Hyprland, taken from its own
    #  flake overlay so pkgs.hyprmod is available everywhere. The overlay builds
    #  hyprmod from the flake source and pins the five hyprland-* Python
    #  bindings inline, which keeps them in sync with hyprmod's version floors.
    inputs.hyprmod.overlays.default
  ];
}
