# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
{ pkgs, ... }:
{
  programs.nh = {
    enable = true;
    clean = {
      enable = false;
      extraArgs = "--keep-since 7d --keep 5";
    };
    flake = "/home/$USER/NixOS-Hyprland";
  };

  environment.systemPackages = with pkgs; [
    nix-output-monitor
    nvd
  ];
}
