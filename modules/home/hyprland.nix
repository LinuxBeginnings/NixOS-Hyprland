# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#  Hyprland / Wayland desktop tooling for the user session.
#
#  Packages only. Hyprland's own configuration is owned by the KoolDots
#  dotfiles in ~/.config/hypr (hyprland.lua), so nothing here generates
#  hyprland.conf and wayland.windowManager.hyprland stays disabled.
#  Session enablement (programs.hyprland, hyprlock, the polkit agent unit)
#  lives in modules/hyprland.nix.
{
  pkgs,
  inputs,
  ...
}: let
  # cava sources vendored by the waybar flake (github:alexays/waybar); keep in sync
  # with the hash it uses there.
  libcavaSrc = pkgs.fetchFromGitHub {
    owner = "LukashonakV";
    repo = "cava";
    tag = "1.0.0";
    hash = "sha256-0r5aAmTs+FcmS501tNYKxG9H+Pq6i32BDRBEjWW6M74=";
  };

  waybarPkg = inputs.waybar.packages.${pkgs.stdenv.hostPlatform.system}.waybar.overrideAttrs (old: {
    doCheck = false;
    mesonFlags = (old.mesonFlags or []) ++ ["-Dtests=disabled"];

    # Upstream waybar switched subprojects/libcava.wrap from a [wrap-file] tarball
    # (directory = cava-1.0.0) to a [wrap-git] clone with no directory key, so meson
    # now looks for subprojects/libcava. Nix runs meson with --wrap-mode=nodownload,
    # and the waybar flake still vendors cava into subprojects/cava-1.0.0, so
    # dependency('libcava') cannot be satisfied and configurePhase fails with
    # "Automatic wrap-based subproject downloading is disabled".
    # TODO: drop this once the waybar flake vendors cava into subprojects/libcava.
    postUnpack =
      (old.postUnpack or "")
      + ''
        pushd "$sourceRoot"
        cp -R --no-preserve=mode,ownership ${libcavaSrc} subprojects/libcava
        patchShebangs subprojects/libcava
        popd
      '';
  });
in {
  home.packages = with pkgs; [
    #  Bar and its modules
    waybarPkg
    waybar-weather # provided by the overlay in modules/overlays.nix
    cava # spectrum visualiser behind the waybar cava module

    #  Hyprland ecosystem
    hypridle
    hyprlang
    hyprshot
    hyprshutdown
    hyprcursor
    hyprland-qt-support # QML import path referenced by hosts/*/config.nix
    nwg-displays
    nwg-dock-hyprland
    nwg-look

    #  Wayland desktop tooling
    awww # wallpaper daemon
    wallust # colour scheme generation
    cliphist # clipboard history
    grim
    grimblast
    slurp
    swappy
    wl-clipboard
    wlr-randr
    wdisplays
    swaynotificationcenter
    wlogout
    rofi
    brightnessctl
    playerctl
    pamixer
    feh
    xdg-user-dirs # needed for copy.sh

    #  Qt theming on Wayland
    kdePackages.qt6ct
    kdePackages.qtwayland
    kdePackages.qtstyleplugin-kvantum # kvantum
    kdePackages.qtdeclarative

    #  Helpers used by the KoolDots dotfiles
    socat # Needed for Tak0 scripts
    ddcutil # Needed for ExternalBrightness script

    # Normally pulled in by hardware.graphics.enable; kept explicit so the
    # Hyprland GL stack does not depend on that toggle staying on.
    mesa
  ];
}
