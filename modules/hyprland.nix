# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#  Hyprland session (NixOS level).
#
#  Only what has to exist outside a user session lives here: the session
#  itself, its login/portal wiring, and the polkit authentication agent.
#  User-facing Hyprland/Wayland tooling lives in modules/home/hyprland.nix.
#
#  The Hyprland configuration is NOT managed by Nix. The KoolDots dotfiles are
#  copied into ~/.config/hypr by the installer and use hyprland.lua as their
#  entry point, so Home Manager's wayland.windowManager.hyprland module must
#  stay disabled: it always writes ~/.config/hypr/hyprland.conf, which Hyprland
#  would then load in preference to hyprland.lua.
{
  pkgs,
  lib,
  inputs,
  ...
}: {
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    # package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland; # hyprland-git
    # portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland; # xdph-git
    xwayland.enable = true;
  };

  programs.hyprlock.enable = true;

  # Waybar is started by the Hyprland dotfiles. Enabling the module starts a
  # second bar on top of the dotfiles' one.
  programs.waybar.enable = false;

  # Polkit authentication agent for the Hyprland session.
  # Prefers hyprpolkitagent, falls back to mate-polkit.
  systemd.user.services.polkit-agent = let
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
  in {
    description = "Polkit authentication agent";
    after = ["graphical-session.target"];
    partOf = ["graphical-session.target"];
    wantedBy = ["default.target"];
    serviceConfig = {
      ExecStart = polkitAgentScript;
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  # Session-level helpers that the programs.hyprland module does not provide on
  # its own, plus the agents the unit above falls back to. Everything else that
  # is Hyprland/Wayland related is in modules/home/hyprland.nix.
  environment.systemPackages = with pkgs; [
    uwsm # session launcher behind programs.hyprland.withUWSM
    hyprpolkitagent # primary agent used by the unit above
    mate-polkit # fallback agent used by the unit above
    kdePackages.polkit-kde-agent-1 # alternative agent kept available
  ];

  # TODO: package hyprland-config, hyprland-monitors, hyprland-schema,
  # hyprland-socket and hyprland-state on PyPI or as local overlays, then expose
  # them through the flake's customPkgs. See docs/HYPRMOD.md.
}
