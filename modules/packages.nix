# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#  Hyprland-specific packages and the session itself now live in
#  modules/hyprland.nix and modules/home/hyprland.nix.
{ pkgs
, inputs
, host
, ...
}: {
  services.power-profiles-daemon.enable = true;

  programs = {
    zsh.enable = true;
    firefox.enable = true;
    dconf.enable = true;
    seahorse.enable = true;
    fuse.userAllowOther = true;
    mtr.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    git.enable = true;
    tmux.enable = true;
    nm-applet.indicator = true;
    neovim = {
      enable = true;
      defaultEditor = false;
    };

    thunar.enable = true;
    thunar.plugins = with pkgs; [
      xfce4-exo
      mousepad
      thunar-archive-plugin
      thunar-volman
      tumbler
    ];
  };

  # Foreign dynamically linked binaries. NixOS ships stub-ld at
  # /lib64/ld-linux-x86-64.so.2, which refuses to start them, so anything that
  # fetches a prebuilt executable at runtime fails. freebuff-cli (see
  # modules/home/cli/freebuff-cli.nix) is the case here: its npm launcher
  # unpacks a platform binary into ~/.config/manicode on first run. nix-ld
  # installs a real loader at that path and points it at the libraries below.
  #
  # The binary itself only needs glibc, which the loader brings with it, and
  # the module already defaults to zlib, zstd, stdenv.cc.cc, curl, openssl,
  # util-linux, xz and systemd. These are the extras its bundled
  # libopentui*.so opens lazily. listOf options merge, so they add to that
  # default set instead of replacing it.
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    alsa-lib # audio output
    libpulseaudio # PulseAudio / PipeWire
    glib # GLib and GObject
    libsecret # secret storage
  ];

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    alejandra
    nixfmt
    nixfmt-tree
    onefetch
    atop
    util-linux
    #go # needed for waybar-weather compile

    # Update flkake script
    (pkgs.writeShellScriptBin "update" ''
      cd ~/NixOS-Hyprland
      nh os switch -u -H ${host} .
    '')

    # Update flake script, activate on next boot instead of now
    (pkgs.writeShellScriptBin "update-boot" ''
      cd ~/NixOS-Hyprland
      nh os boot -u -H ${host} .
    '')

    # Rebuild flkake script
    (pkgs.writeShellScriptBin "rebuild" ''
      cd ~/NixOS-Hyprland
      nh os switch -H ${host} .
    '')

    # Rebuild flake script, activate on next boot instead of now
    (pkgs.writeShellScriptBin "rebuild-boot" ''
      cd ~/NixOS-Hyprland
      nh os boot -H ${host} .
    '')

    # clean up old generations
    (writeShellScriptBin "ncg" ''
      nix-collect-garbage --delete-old && sudo nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot
    '')

    #  Apps
    power-profiles-daemon
    loupe
    appimage-run
    bc
    # To eanble GPU load monitoring in btop
    (btop.override {
      cudaSupport = true;
      rocmSupport = true;
    })
    bottom
    baobab
    btrfs-progs
    cliamp
    cmatrix
    distrobox
    dua
    duf
    cargo
    #clang
    # cmake
    cpufrequtils
    curl
    dysk
    eog
    easyeffects
    eza
    findutils
    figlet
    ffmpeg
    fd
    file # identify file types
    file-roller
    gcc
    git
    glib # for gsettings to work
    gnome-system-monitor
    gsettings-qt
    fastfetch
    jq
    gcc
    git
    gnumake
    inxi
    imagemagick
    killall
    lazygit
    libappindicator
    libnotify
    (mpv.override { scripts = [ mpvScripts.mpris ]; }) # with tray
    nvtopPackages.full
    openssl # required by Rainbow borders
    pciutils
    networkmanagerapplet
    pavucontrol
    pulseaudio
    rsync
    unzip
    wget
    xarchiver
    yad
    yazi
    yt-dlp

    (inputs.ags.packages.${pkgs.stdenv.hostPlatform.system}.default)

    # Utils
    ctop # container top
    ghee # git TUI explorer
    butterpal # wallpaper palette generator for the butter setups
    erdtree # great tree util run: erd
    lolcat
    lsd # ls replacement util
    mcat # show images in terminal
    mdcat # Markdown tool
    parallel-disk-usage # fast disk space tool run: pdu
    pik # Interactive process killer
    oh-my-posh
    ncdu # disk usage tool
    ncftp
    netop # network mon tool run: sudo netop
    ripgrep
    starship
    timeshift # snapshot / rsync util
    trippy # trace tool like mtr  run  sudo trip host/IP
    tldr
    tuptime # better uptime tool
    ugrep
    unrar
    v4l-utils
    #obs-studio   # move to host pkgs
    zoxide

    # Hardware related
    atop # monitoring tool
    bandwhich # network monitor run with sudo
    # caligula # burn ISOs at cli FAST
    # cpufetch
    # cpuid
    # cpu-x
    cyme # list USB devices - very handy
    gdu # Dusk usage
    # glances # system monitor tool
    # Disabled 2026-11-12: nixpkgs' glances hard-depends on python-jose, which
    # nixpkgs marks insecure for CVE-2026-120459 (JWT algorithm confusion in
    # its crypto backend). Re-enable only once nixpkgs ships a fixed
    # python-jose or glances drops the dependency; do not re-enable it by
    # whitelisting the insecure package via permittedInsecurePackages.
    # Other monitors already in this list: btop, bottom, htop, mission-center.
    gping # Graphical ping tool
    htop # system monitor tool
    # hyfetch
    ipfetch
    pfetch
    smartmontools
    lm_sensors
    mission-center

    # Development related
    lua
    lua55Packages.luacheck
    luarocks
    lua-language-server
    stylua
    nh

    # Internet
    #  discord  # Move to host pkgs

    # Virtuaizaiton
    virt-viewer
    libvirt

    # Video
    vlc

    # Terminals
    ghostty
    kitty
    wezterm
  ];
  environment.variables = {
    JAKOS_NIXOS_VERSION = "0.4.3";
    JAKOS = "true";
  };
}
