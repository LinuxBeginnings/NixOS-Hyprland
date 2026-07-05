# Changelog 📓

A technical record of notable changes. Dates are in UTC.

## Jul 2026

- Fixed:
    - `fzf` eval warnings
    - Home Manager activation errors on rebuilds
    - Build errors on `pkgs = pkgs` in `nixvim.nix` no longer supported

## Jun 2026

- Added:
    - `modules/home/editors/micro.nix`
    - `modules/home/editors/nano.nix`
        - Lightly themed w/syntax highlighting
    - `nixvim.nix` now follows NixPkgs

- Updated:
    - `flake.nix` to NixOS v26.11 current unstable branch
    - `README.md` clarified and updated text
    - `nixvim.nix` Removed `pkgs = pkgs` option not longer supported

- Fixed:
    - Eval warnings:
        - `alejandra` formatter pkg name
        - `catppuccin` in `modules/theme.nix`

            ```nix
               # Catppuccin theme configuration
               catppuccin.enable = true;
               catppuccin.autoEnable = true;
            ```

    - Lightly themed w/syntax highlighting

- Updated to NixOS v26.11
- Fixed eval warnings for `catppuccin` in `modules/theme.nix`

    ```nix
       # Catppuccin theme configuration
       catppuccin.enable = true;
       catppuccin.autoEnable = true;
    ```

## May 2026

## Added:

    - `hyprshutdown`
    - `luacheck`
    - `lua`
    - `stylua`
    - `lua-language-server`
    - `socat` to fix `Tak0` scripts
    - `ddcutil` to support external monitor brightness
    - `gearlever` for managing  `AppImages`
    -  Check for user `waybar` service
       - If found it will stop, disable, then mask it

## Updated:

    - `yazi` config files now in `Hyprland-Dots`
    - Hyprland built from NixPkgs not source
       - Hyprland 0.55.2 now available
       - Much faster rebuild, update times
       - Source build config is just commented out just in case

## Disabled:

    - Hyprland being built from source
    - Hyprland cacheix servers, not needed for Hyprland from NixPkgs
    - Discord
    - cpu id utils
    - serie
    - hyfetch
    - caligula
    - google-chrome

## Misc:

- Packages like Chrome, etc, should be added per host

## April 2026

- Added `socat` needed for `Tak0` scripts
- Disabled `noice` to remove prompt when staring NVIM
    - Startup might tell you to migrate nvim projects
    - Go `~/.local/share/nvim/project_nvim/` and remove the `.json` file there
- Updated flake to prevent `deno` from being built from source
    - Takes MANY hours to compile otherwise
    - I.e. if you just did a rebuild instead of updating flake
- Disabled `webdavd` fails to build - upstream issue
- Set default kernel to `latest` instead of `zen`
    - 7.0 kernel is better than 6.19.zen
    - This won't change existing hosts
- Fixed `nixvim` LuaLines error
- Stopped `install.sh` from overwritting fastfetch config
- Changed `swww` to `awww`
    - `swww` no longer maintained
- Fixed polkit issue with QT kvantum apps
    - Added: `qt5.qtdeclarative qt5.qtquickcontrols2 #kdePackages.qtdeclarative`
    - `swww` wallpaper engine no longer maintained

## March 2026

- Fixed policy kit issue preventing permssion escalation
    - The solution b/c of the way `ly` works requires `UWSM`
        - Make sure the session type is `hyprland-uwsm`
        - I will continue to look for another solution
- Fixed eval warnings
    - `git.signing.format` to `null`
    - `lualine` theme to `auto`
- Added `awww` flake for future upgrade from `swww`
- Fixed bad package name, caused build failure
- Removed `neofetch` and `light` they are unmaintained
- Disabled `modulces/home/terminals/ghostty.nix`
    - Hyprland-Dots now has dynamic config for ghostty

## February 2026

- Enabled `zsh`, `fish`, `bash` shells in `eza.nix`
    - This resolved issues of `homeshell.aliases` not being created/updated

## January 2026

- Updated to unstable branch
    - To get Hyprland to v0.53.x
    - Needed for feature parity with dotfiles

## December 2025

- Added additional nerd fonts
- Added Spanish Translations
    - `CODE_OF_CONDUCT.es.md`
    - `COMMIT_MESSAGE_GUIDELINES.es.md`
    - `CONTRIBUTING.es.md`
- Added color and clock to `ly` login manager
- Added `nh` NIX helper for rebuilds, cleanup
- Added `alejandra` nix formatter to flake
    - Ran `nix fmt ./` to properly NIX format all files
    - Provides consistent and NIX standard formatting for merges
- Added `power-profiles-daemon` service and package
- Pinned `nixvim` to stable branch, v25.11
- Pinned NixOS to v25.11 Stable Branch
- Updated quickshell `overview` code to newest version
    - Gets updated by `Hyprland-Dots` after initial install

## November 2025

- Updated Flake
- Updated: Hyprland now v0.52.1

- Added TMUX config from @tony,btw
    - I merged exiting with his best features
    - Tokyo Night theme
    - More VIM motions
    - No plugins!
    - Updated English and Sponish tmux cheatsheets

- ZSH
    - Added plugins
    - `zsh-syntax-highlighting`
    - `zsh-auto-suggestion`

- Home Manager
    - Enabled backup of conflicting files on rebuilds

- Updated GTK theming config

- quickshell: use pkgs.stdenv.hostPlatform.system instead of deprecated pkgs.system

- revert: drop XDG_DATA_DIRS overrides to fix NixOS eval conflicts; keep theming via dconf and Qt vars

- Fixed: poor output formating in install scripts
- Fixed: path issue in auto-install.sh and install.sh scripts
- Removed `greetd-tui`, replaced with `ly` login manager
- Added Home Manager for a small subset of apps
    - NeoVim via NIXVIM
    - Ghostty
    - bat
    - bottom
    - btop
    - eza
    - fzf
    - git
    - tealdir
    - yazi

- Added cheatsheets for TMUX and NeoVIM in English and Spanish.

## October 2025

- Changed from `nixos-rebuild switch` to `nixos-rebuild boot`
- Modified both `auto-install.sh` and `install.sh`
- This is a best practice especially if currently running a Login Display Mgr
- The switch will reload services and common result is black screen

## September 2025

- Added
    - AGS re-added; quickshell updates were failing on some non-NixOS environments
      after recent upstream changes.
    - pyprland re-added by user request. It is present but not enabled by default.

- Changed
    - Consolidated common packages under modules/packages.nix; extracted fonts to
      modules/fonts.nix.
    - Removed duplicated packages and a stray programs-level xwayland flag
      (Hyprland’s own xwayland setting remains).
    - Installers refactored to use a shared library scripts/lib/install-common.sh
      with:
        - GPU profile detection (amd | intel | nvidia | nvidia-laptop | vm) with
          user confirmation.
        - pciutils check before use; robust host update in flake.nix.
        - Timezone prompt defaults to auto-detect
          (services.automatic-timezoned.enable = true) unless a manual TZ is set.
        - Console keymap prompt; keyboard layout still written to
          hosts/<host>/variables.nix.
        - fupdate/frebuild scripts fixed to target the active host via nh os switch
          -H ${host} .
    - Zsh defaults: enable programs.zsh at the system level; enable oh-my-zsh for
      the primary user; ensure ~/.zshrc sources /etc/zshrc.

- Fixed
    - Dark mode defaults are applied via system dconf (prefer-dark, Adwaita-dark,
      Papirus-Dark, Bibata cursor) with correct activation ordering.
    - Removed global GTK_THEME and QT_STYLE_OVERRIDE so nwg-look and apps can
      preview/apply themes dynamically; retained QT_QPA_PLATFORMTHEME=gtk3 and
      cursor variables.
    - Installers now toggle drivers/vm settings on the selected host rather than
      the default.

## July 2025

- switched to unstable channel
- removed AGS from the option
- return to main Hyprland-Dots repo
- Diverted KooLs Dots to download from specific branch until I figure out how to
  install quickshell on NixOS

## March 2025

- added findutils as dependencies
- Dropped pyprland in favor of hyprland built in tool for a drop down like
  terminal and Desktop magnifier
- replaced eza with lsd

## Feb 2025

- added Victor Mono Font for proper hyprlock font rendering for Dots v2.3.12
- added Fantasque Sans Mono Nerd for Kitty
- replaced eog with loupe
- Returning AGS overview option :)
- disabled AGS permanently as it is trying to install version 2.2.1 even I set
  override
- switched to latest kernel (from zen kernel) to unstable channel (from 24.11)

## Jan 2025

- AGS (aylurs gtk shell) v1 is now optional
- switched to zen kernel for now until NixOS team fix the Kernel 6.13 plague
- time will now be based via location
- switched to full stable branch
- switch to final version of aylurs-gtk-shell-v1
- default oh-my-zsh theme was changed to `funky`
- switched to non-development Hyprland

### Dec 2024

- moved Packages and Fonts in a separate.nix. Thanks to @dwilliam62 for the lead

### Oct 2024

- added brightnessctl
- updated packages names

### Sep 2024

- removed neovim
- nvim config will be downloaded or copied into ~/.config anymore
- added zram
