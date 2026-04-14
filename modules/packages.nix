# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
{ pkgs
, inputs
, host
, lib
, ...
}: {
  services.power-profiles-daemon.enable = true;

  programs = {
    hyprland = {
      enable = true;
      withUWSM = true;
      #package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland; #hyprland-git
      #portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland; #xdph-git

      portalPackage = pkgs.xdg-desktop-portal-hyprland; # xdph none git
      xwayland.enable = true;
    };
    zsh.enable = true;
    firefox.enable = false;
    waybar.enable = false; #started by Hyprland dotfiles. Enabling causes two waybars
    hyprlock.enable = true;
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
  nixpkgs.config.allowUnfree = true;

  systemd.user.services.polkit-agent =
    let
      polkitAgentScript = pkgs.writeShellScript "polkit-agent" ''
        if [ -x "${lib.getExe pkgs.hyprpolkitagent}" ]; then
          exec "${lib.getExe pkgs.hyprpolkitagent}"
        fi
        if [ -x "${lib.getExe' pkgs.mate-polkit "polkit-mate-authentication-agent-1"}" ]; then
          exec "${lib.getExe' pkgs.mate-polkit "polkit-mate-authentication-agent-1"}"
        fi
        echo "No supported polkit agent found." >&2
        exit 1
      '';
    in
    {
      description = "Polkit authentication agent";
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = polkitAgentScript;
        Restart = "on-failure";
        RestartSec = 1;
      };
    };

  environment.systemPackages = with pkgs; [

    inputs.awww.packages.${pkgs.stdenv.hostPlatform.system}.awww
    alejandra
    onefetch
    atop
    go #needed for waybar-weather compile

    # Update flkake script
    (pkgs.writeShellScriptBin "update" ''
      cd ~/NixOS-Hyprland
      nh os switch -u -H ${host} .
    '')

    # Rebuild flkake script
    (pkgs.writeShellScriptBin "rebuild" ''
      cd ~/NixOS-Hyprland
      nh os switch -H ${host} .
    '')

    # clean up old generations
    (writeShellScriptBin "ncg" ''
      nix-collect-garbage --delete-old && sudo nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot
    '')

    # Hyprland Stuff
    hypridle
    hyprpolkitagent
    #pyprland
    uwsm
    hyprlang
    hyprshot
    hyprcursor
    mesa
    nwg-displays
    nwg-look
    waypaper
    waybar
    waybar-weather
    hyprland-qt-support # for hyprland-qt-support

    #  Apps
    power-profiles-daemon
    loupe
    appimage-run
    bc
    brightnessctl
    (btop.override {
      cudaSupport = true;
      rocmSupport = true;
    })
    bottom
    baobab
    btrfs-progs
    cmatrix
    distrobox
    dua
    duf
    cava
    cargo
    clang
    cmake
    cliphist
    cpufrequtils
    curl
    dysk # disk usage tool
    easyeffects # Audio tool
    eza
    findutils
    figlet
    ffmpeg
    fd
    feh
    file-roller
    git
    glib # for gsettings to work
    google-chrome
    gnome-system-monitor
    gsettings-qt
    fastfetch
    jq
    gcc
    git
    gnumake
    grim
    grimblast
    gtk-engine-murrine # for gtk themes
    inxi
    imagemagick
    killall
    kdePackages.qt6ct
    kdePackages.qtwayland
    kdePackages.qtstyleplugin-kvantum # kvantum
    lazydocker
    lazygit
    libappindicator
    libnotify
    libsForQt5.qtstyleplugin-kvantum # kvantum
    libsForQt5.qt5ct
    (mpv.override { scripts = [ mpvScripts.mpris ]; }) # with tray
    nvtopPackages.full
    openssl # required by Rainbow borders
    pciutils
    networkmanagerapplet
    pamixer
    pavucontrol
    pulseaudio
    playerctl
    rsync
    #polkit
    # polkit_gnome
    kdePackages.polkit-kde-agent-1
    mate-polkit
    # qt6ct
    #qt6.qtwayland
    #qt6Packages.qtstyleplugin-kvantum # kvantum
    rofi
    slurp
    swappy
    serie #git cli tool
    swaynotificationcenter
    swww
    unzip
    wallust
    wdisplays
    wl-clipboard
    wlr-randr
    wlogout
    wget
    xarchiver
    yad
    yazi
    xdg-user-dirs #needed for copy.sh
    yt-dlp

    (inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default)
    (inputs.ags.packages.${pkgs.stdenv.hostPlatform.system}.default)

    # Utils
    ctop # container top
    erdtree # great tree util run: erd
    frogmouth # cli markdown renderer A
    lstr # another tree util
    lolcat
    lsd # ls replacement util
    macchina # fetch tool
    mcat # show images in terminal
    mdcat # Markdown tool
    parallel-disk-usage # fast disk space tool run: pdu
    pik # Interactive process killer
    oh-my-posh
    ncdu # disk usage tool
    ncftp
    netop # network mon tool run: sudo netop
    ripgrep
    socat
    starship
    timeshift #snapshot / rsync util
    trippy # trace tool like mtr  run  sudo trip host/IP
    tldr
    tuptime # better uptime tool
    ugrep
    unrar
    v4l-utils
    #obs-studio
    zoxide

    # Hardware related
    atop # monitoring tool
    bandwhich # network monitor run with sudo
    caligula # burn ISOs at cli FAST
    cpufetch
    cpuid
    cpu-x
    cyme #list USB devices - very handy
    gdu # Dusk usage
    glances # system monitor tool
    gping # Graphical ping tool
    htop # system monitor tool
    hyfetch
    ipfetch
    pfetch
    smartmontools
    lm_sensors
    mission-center

    # Development related
    luarocks
    nh

    # Internet
    discord

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
    JAKOS_NIXOS_VERSION = "0.0.5";
    JAKOS = "true";
  };
}
