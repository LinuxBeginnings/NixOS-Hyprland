# Changelog 📓

A technical record of notable changes. Dates are in UTC.

## Nov 2026

- Added:
    - `modules/hyprland.nix` for the system-level Hyprland session
        - `programs.hyprland` with UWSM and XWayland, and `programs.hyprlock`
        - `programs.waybar.enable = false`, since the dotfiles start Waybar themselves
        - `polkit-agent` systemd user unit, preferring `hyprpolkitagent` and falling
          back to `mate-polkit`
        - Session packages: `uwsm`, `hyprpolkitagent`, `mate-polkit`,
          `kdePackages.polkit-kde-agent-1`
        - Records why Home Manager's `wayland.windowManager.hyprland` must stay
          disabled: it writes `~/.config/hypr/hyprland.conf`, which Hyprland loads
          in preference to the dotfiles' `hyprland.lua`
    - `modules/home/hyprland.nix` for user-session Hyprland and Wayland tooling
        - Home Manager packages only: the bar and its modules, the Hyprland
          ecosystem, Wayland desktop tooling, Qt theming and dotfile helpers
        - Now owns the waybar `libcava` vendoring shim, including the cava 1.0.0
          fetch and the `postUnpack` copy into `subprojects/libcava`
    - `modules/home/cli/freebuff-cli.nix` for the freebuff coding agent
        - Now a portable Home Manager module, shared with ddubsos:
          `programs.freebuff-cli.{enable,notifications.enable,checkForUpdates.enable,checkForUpdates.interval}`
        - A `freebuff-cli-check` systemd user timer checks every four hours and
          reports new npm releases through `notify-send` (`--notify`), one
          notification per published version
        - Bar wiring stays with each project: `--status` still emits one JSON
          line for a Noctalia stdout widget or a Waybar custom module, and no
          bar configuration is generated
        - Installs a `freebuff-cli` wrapper that runs `npx --yes freebuff`, with
          `pkgs.nodejs` pinned into the wrapper's `PATH`
        - `freebuff` ships to npm as a thin launcher package whose `index.js` and
          `launcher.js` download the sha256-verified native binary into
          `~/.config/manicode` on first run, so there is no self-contained
          derivation to build here
        - Named `freebuff-cli` and routed through `npx` because a global install
          or a desktop build called `freebuff` can shadow the CLI, while
          `npx freebuff` always resolves the npm CLI package
        - The wrapper now exits with an explanation when nix-ld is missing,
          instead of letting the downloaded binary die with the stub-ld message
        - It tests `/run/current-system/sw/share/nix-ld/lib/ld.so`, not
          `command -v nix-ld`: the nix-ld module puts only a buildEnv of
          libraries in `systemPackages`, so there is no `nix-ld` binary on `PATH`
        - npm stays at the version bundled with `pkgs.nodejs` (11.19.0 today)
          and cannot self-update under Nix, so the npm notice is not actionable
    - `programs.nix-ld` in `modules/packages.nix`
        - NixOS defaults `environment.ldso` to `stub-ld`, which refuses to start
          foreign ELF binaries, and the freebuff launcher unpacks exactly such a
          binary into `~/.config/manicode`
        - `nixos/modules/config/ldso.nix` links the configured loader to
          `/lib64/ld-linux-x86-64.so.2` with a systemd-tmpfiles `L+` rule, so
          nothing appears in the activation script
        - Libraries: `alsa-lib`, `libpulseaudio`, `glib`, `libsecret`
            - `listOf` options merge, so they add to the module's default set
              (zlib, zstd, `stdenv.cc.cc`, curl, openssl, util-linux, xz,
              systemd) rather than replacing it
    - `file` to system packages, for identifying foreign binaries
    - Verified the nix-ld wiring and the wrapper guard
        - Built system carries `sw/bin/file` -> `file-5.48` and
          `sw/share/nix-ld/lib/ld.so` -> `glibc-2.44-57/lib/ld-linux-x86-64.so.2`
        - After activation `freebuff-cli --version` prints `0.2.35`, and
          `file --version` reports `file-5.48`
        - Negative case: the same wrapper with the loader path pointed at a
          missing file prints the nix-ld message and exits 1
        - `NIX_LD` and `NIX_LD_LIBRARY_PATH` are empty outside a PAM session,
          since the module sets them with `environment.sessionVariables`
        - TODO: confirm which loader serves foreign binaries here, because
          `/lib64/ld-linux-x86-64.so.2` resolves to the glibc loader rather
          than to nix-ld's `libexec/nix-ld`
    - NVIDIA Prime bus IDs are detected automatically by the installers
        - `nhl_pci_bus_id` takes the first VGA/3D/Display device per vendor from
          `lspci` and converts the hex `BB:DD.F` address to Xorg's decimal
          `PCI:bus:dev:func` form, dropping the PCI domain the same way
          `modules/nvidia-prime-drivers.nix` already did
        - `nhl_set_prime_bus_ids` fills `drivers.nvidia-prime.{intelBusID,nvidiaBusID}`
          for the `nvidia-laptop` profile, and never rewrites a value that is
          already set: matching IDs are reported as already correct, different
          ones need a `y` (default `n`), and a half-filled pair only gets the
          empty side filled
        - When detection fails the configured IDs are kept; with both IDs empty
          the installer warns and prints the manual `lspci` command instead of
          guessing
    - Hardware summary printed before the rebuild
        - `nhl_print_hardware_summary` reports user, CPU, RAM total/available,
          every display device, the driver profile, the Prime bus IDs (hybrid
          only) and the flake target once the host files are staged
        - Missing `lspci` or `free` degrade to `none detected` / `unknown` rather
          than aborting under `set -e`
    - The completion message reports the installed Hyprland version and the
      driver modules enabled in `hosts/<host>/config.nix`
        - `nhl_hyprland_version` prefers the `Tag:` line of `Hyprland --version`
          and falls back to the version in parentheses in the build banner
        - `nhl_enabled_drivers` reads `drivers.{amdgpu,intel,nvidia,nvidia-prime}.enable`
          through the new scope-aware `nhl_get_nix_value` / `nhl_get_bool_value`
    - `rebuild-boot` and `update-boot` generated scripts
        - Same shape as `rebuild` / `update`, but they call `nh os boot` instead of
          `nh os switch`, so the new generation is made the boot default without
          activating it in the running session
        - `update-boot` keeps the `-u` flake update that `update` does
        - Written for the case where a change should land on the next reboot and
          not in the session that is currently running

- Updated:
    - `flake.nix` imports `./modules/hyprland.nix` and is reformatted
    - `modules/home/default.nix` imports `./hyprland.nix` and `./cli/freebuff-cli.nix`
    - `modules/packages.nix` no longer carries the Hyprland packages
        - `programs.hyprland`, `programs.hyprlock`, `programs.waybar.enable` and the
          `polkit-agent` unit moved to `modules/hyprland.nix`
        - The Hyprland, Wayland, Qt theming and helper packages moved to
          `modules/home/hyprland.nix`
        - The module signature no longer takes `lib` or `customPkgs`
    - `README.md` Hyprland config references now describe the Lua workflow
        - The dotfiles are Lua-based (Hyprland 0.57+), not hyprlang `.conf`
        - Documents the `hyprland.lua` entrypoint, `configs/system_*.lua` defaults
          and `UserConfigs/user_*.lua` user settings
        - Notes runtime writes go through `hyprctl eval`, and that legacy `.conf`
          files are archived under `LegacyConfigs/<timestamp>`
    - `modules/home/overview/README.md` converted to Hyprland's Lua config API
        - Keybind example is now `hl.bind("SUPER + TAB", hl.dsp.exec_cmd(...))`
        - Autostart example is now `hl.on("hyprland.start", ...)` calling `hl.exec_cmd`
        - Added a `Hyprland Lua integration` section covering the KooLDots keybind,
          autostart and the `quickshell:overview` layer rule
    - Installers consolidated onto one shared flow
        - `install.sh` and `auto-install.sh` are now thin entry points that resolve
          the repository and call `nhl_install_flow`; `auto-install.sh` keeps only
          its inline preflight, backup and clone bootstrap before sourcing the
          library from the clone
        - Settings live in `NHL_*` tunables, and prompts read from
          `NHL_PROMPT_SOURCE` so the flow can also be driven non-interactively
        - `nhl_nix_set` edits `hosts/<host>/*.nix` scope-awarely, replacing the
          dotted `sed` patterns that assumed one option per line
        - `README.md` install command uses `bash <(curl ...)`, matching the
          `BASH_SOURCE` handling in the scripts

- Fixed:
    - `modules/home/overview/README.md` file tree no longer lists `hyprland-config.conf`
        - The file does not exist in the module, and a Hyprland config does not
          belong in the Quickshell config directory
        - Added the missing `assets/` directory and the five `qmldir` files
        - Tree verified against the module contents
    - Installer GPU/driver toggles never matched `hosts/default/config.nix`
        - The old `sed` patterns expected one option per line, but the shipped
          config uses `amdgpu.enable = true;` inside `drivers = { ... }`, so the
          detected GPU profile was silently not applied to the host config
    - Unsafe shell handling in the installers
        - Unquoted expansions, `echo -e` and `cd` without a failure check are gone
          in favour of `[[ ]]`, arrays, `printf` and `cd ... ||`
        - Nix file edits go through `mktemp` and only replace the target on
          success, so a failed edit cannot truncate `config.nix`
        - The installers no longer run `git config --global user.name/email`, and
          `git add` is scoped to `flake.nix` and `hosts/`
    - `typescript-language-server` build failure after the flake update
        - The update moved nixpkgs to `1d060086` (nixos-unstable, Nov 3 2026),
          which ships `typescript-language-server` 6.0.3 built against a newer
          pnpm lockfile (pnpm 12.9.0, `fetcherVersion = 5`)
        - `modules/overlays.nix` still forced the 6.0.2 `pnpmDeps` hash
          (`sha256-xR/EF60lVBsITKgH7wCM2wHM46PFQevD51KfCENSUH4=`), so the fetcher
          reused the 6.0.2 store and the build died in `configurePhase` with
          `ERR_PNPM_NO_OFFLINE_TARBALL` for `ansi-regex@6.5.0`, taking the
          `nixvim`/`neovim` wrapper and the system closure down with it
        - Dropped the override, because the pinned nixpkgs now declares the
          correct hash (`sha256-klxImN6Bp5/t6V0LfsmYNBvSzYq9Qz9dIU2mkvScx5k=`);
          verified by building `pkgs.typescript-language-server` unpatched
        - `nixpkgs.pkgs = pkgs` in `modules/home/editors/nixvim.nix` stays, since
          it is what keeps nixvim on the host `pkgs` instance
        - Reverting `flake.lock` to the previous revision brings back the 6.0.2
          package, which still needs the override

## Oct 2026

- Added:
    - `hyprland-qtutils` to system packages (provides `hyprland-dialog`)
    - Verified `lua` (provides `luac`) is included in default system packages
    - `ghee` and `butterpal` to system packages, from two new flake inputs
        - `ghee` 0.1.3 - git TUI over every repo in a folder (Zig), `git+https://justaguy.dev/drew/ghee`
        - `butterpal` 0.3.1 - prints a wallpaper's 24-colour palette (C), `git+https://justaguy.dev/drew/butterpal`
        - Both are packaged by upstream and exposed as `pkgs.ghee` / `pkgs.butterpal`
          by `modules/overlays.nix`, so `modules/packages.nix` only refers to `pkgs`
        - `inputs.nixpkgs.follows = "nixpkgs"` on both, so neither pulls in a
          second nixpkgs revision

- Fixed:
    - Build failure from a stale pnpm dependency hash for `typescript-language-server` 6.0.2
        - Nixpkgs `7fd4004` (nixos-unstable, Oct 11 2026) declares the wrong `pnpmDeps` hash,
          so the fixed-output derivation failed with a hash mismatch and the
          `nixvim`/`neovim` wrapper could not build
        - `modules/overlays.nix` now overrides that hash with the value the fetcher
          produces, matching the upstream fix (NixOS/nixpkgs@ac7b1aa)
        - `modules/home/editors/nixvim.nix` now sets `nixpkgs.pkgs = pkgs` instead of
          `nixpkgs.source`, so nixvim reuses the host `pkgs` instance
            - It previously evaluated a second nixpkgs without `nixpkgs.overlays`,
              pulling an unpatched `typescript-language-server` into the wrapper
              alongside the patched one
    - Build failure for `waybar` `0.15.0+date=2026-10-28_f6f73c8` after updating the flake
        - The `alexays/waybar` input changed `subprojects/libcava.wrap` from a
          `[wrap-file]` tarball (`directory = cava-1.0.0`) to a `[wrap-git]` clone with
          no `directory` key, so meson now looks for `subprojects/libcava`
        - Nix builds meson with `--wrap-mode=nodownload` and nixpkgs' `waybar` passes
          `-Dcava=enabled`, so `dependency('libcava', version: '>=1.0.0')` could not fall
          back to the subproject and `configurePhase` failed with
          "Automatic wrap-based subproject downloading is disabled"
        - `modules/packages.nix` now vendors the cava 1.0.0 sources into
          `subprojects/libcava` in `postUnpack`, so cava support stays enabled
        - TODO: drop this shim once the `alexays/waybar` flake vendors cava under
          `subprojects/libcava`

## Sep 2026

- Fixed:
    - Refactored auto-install.sh (as well as install.sh for consistency)
    - To check whether ~/.zshrc is a symbolic link before attempting to copy assets/.zshrc.
- Quickshell now nixpkg
    - Removed flake input
    - No more building from source
- Removed old overlay
    - Caused long source builds
    - Moved to `ioseka-bin` also
- Removed anitgravity-cli flake
- Trimmed pkgs
- Added qt6ct
- Removed QT5
## Aug 2026

- Fixed:
    - Build error during install
        - `awww` now a nixpkg, not built from source
        - `alejandra` also now nixpkg
        - No swap causes OOM errors
            - zram doesn't take effect until reboot
            - `install.sh` checks for zero swap and < 16GB RAM
            - Creates temp swapfile
            - Limits `--max-jobs 2` and `--max-cores 4`

- Added:
    - Overlay for `dwarfs` needed by `gearlever`
        - Disabled `gearlever` it causes large source build
    - `nwg-dock-hyprland` and created `Dock.sh` `CTRL+ALT+D`
    - `brave-origin`

- Removed:
    - gtk-marrine
    - Uses GTK2 which is unsupported
    - Old entries in `modules/overlays.nix`

- Updated:
    - The shebang wasn't on first line
    - Year in banner to 2026
    - Flake to get current kernel and Hyprland

## Jul 2026

- Added:
    - `qt5compact.GrahicalEffects` to support `qs-hyprview`

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
