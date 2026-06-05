# 💫 https://github.com/LinuxBeginnings 💫 #
# Packages and Fonts config including the "programs" options
{ pkgs, ... }:
let
  python-packages = pkgs.python3.withPackages (
    ps: with ps; [
      requests
      pyquery # needed for hyprland-dots Weather script
    ]
  );
in
{
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages =
    (with pkgs; [
      # System Packages
      google-chrome
    ])
    ++ [
      python-packages
    ];

  programs = {
    steam = {
      enable = false;
      gamescopeSession.enable = false;
      remotePlay.openFirewall = false;
      dedicatedServer.openFirewall = false;
    };
  };
}
