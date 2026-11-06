# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
{
  description = "KoolDots -- NixOS-Hyprland";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixvim = {
      url = "github:nix-community/nixvim/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #  To build from source, not recommended
    # hyprland = {
    #   url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    waybar = {
      url = "github:alexays/waybar";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ags = {
      type = "github";
      owner = "aylur";
      repo = "ags";
      ref = "v1";
    };

    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #  ghee - git, as a place you leave open (packaged by upstream)
    ghee = {
      url = "git+https://justaguy.dev/drew/ghee";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #  butterpal - wallpaper palette generator for the butter setups
    butterpal = {
      url = "git+https://justaguy.dev/drew/butterpal";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #  quickshell = {
    #    url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
    #    inputs.nixpkgs.follows = "nixpkgs";
    #  };

    #  hyprmod - GTK4/libadwaita settings app for Hyprland.
    #  Consumed through its own flake overlay (pkgs.hyprmod), see
    #  modules/overlays.nix. It packages the hyprland-* Python bindings inline
    #  with pinned hashes, so there is no local derivation to maintain here.
    hyprmod = {
      url = "github:BlueManCZ/hyprmod";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    ags,
    ...
  }: let
    system = "x86_64-linux";
    host = "jak-hl";
    username = "dwilliams";

    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
      };
    };
    waybarWeatherPkg = pkgs.callPackage ./pkgs/waybar-weather.nix {};
  in {
    packages.${system} = {
      waybar-weather = waybarWeatherPkg;
      #  Re-exported from the hyprmod flake so `nix build .#hyprmod` still works
      #  standalone; the system gets it through pkgs.hyprmod (overlay).
      hyprmod = inputs.hyprmod.packages.${system}.default;
    };
    #  `nix flake check` builds these. Nix evaluates the nixosConfigurations
    #  output by itself, so the system is covered without a toplevel build.
    checks.${system} = {
      #  The derivation the overlay hands to modules; a bad upstream rev fails
      #  here instead of at activation time.
      hyprmod = self.packages.${system}.hyprmod;

      #  Fails when a .nix file is not Alejandra-formatted. Only the .nix files
      #  are copied into the store, not the assets.
      formatting = let
        nixSources = nixpkgs.lib.fileset.toSource {
          root = ./.;
          fileset = nixpkgs.lib.fileset.fileFilter (file: file.hasExt "nix") ./.;
        };
      in
        pkgs.runCommand "check-alejandra" {
          nativeBuildInputs = [pkgs.alejandra];
        } ''
          alejandra --check ${nixSources}
          touch $out
        '';
    };
    nixosConfigurations = {
      "${host}" = nixpkgs.lib.nixosSystem rec {
        specialArgs = {
          inherit system;
          inherit inputs;
          inherit username;
          inherit host;
        };
        modules = [
          ./hosts/${host}/config.nix
          # inputs.distro-grub-themes.nixosModules.${system}.default
          ./modules/overlays.nix # nixpkgs overlays (CMake policy fixes)
          ./modules/quickshell.nix # quickshell module
          ./modules/hyprland.nix # Hyprland session (enable, polkit agent, session pkgs)
          ./modules/packages.nix # Software packages
          # Allow broken packages (temporary fix for broken CUDA in nixos-unstable)
          {nixpkgs.config.allowBroken = true;}
          ./modules/fonts.nix # Fonts packages
          ./modules/portals.nix # portal
          ./modules/theme.nix # Set dark theme
          ./modules/ly.nix # ly greater with matrix animation
          ./modules/nh.nix # nix helper
          inputs.catppuccin.nixosModules.catppuccin
          # Integrate Home Manager as a NixOS module
          inputs.home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-bak";

            # Ensure HM modules can access flake inputs (e.g., inputs.nixvim)
            home-manager.extraSpecialArgs = {
              inherit
                inputs
                system
                username
                host
                ;
            };

            home-manager.users.${username} = {
              home.username = username;
              home.homeDirectory = "/home/${username}";
              home.stateVersion = "24.05";

              # Import your copied HM modules
              imports = [
                ./modules/home/default.nix
              ];
            };
          }
        ];
      };
    };
    # Code formatter (the same Alejandra run by checks.${system}.formatting)
    formatter.x86_64-linux = pkgs.alejandra;
  };
}
