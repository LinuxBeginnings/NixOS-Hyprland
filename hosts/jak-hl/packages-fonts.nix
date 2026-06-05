# 💫 https://github.com/LinuxBeginnings 💫 #
# Packages for this host only
{ inputs, pkgs, ... }:
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

      inputs.antigravity-cli-repo.packages.${pkgs.stdenv.hostPlatform.system}.antigravity-cli

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
