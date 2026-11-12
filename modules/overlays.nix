# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
{inputs, ...}: {
  nixpkgs.overlays = [
    (final: prev: {
      waybar-weather = final.callPackage ../pkgs/waybar-weather.nix {};
    })

    #  Packages from the justaguylinux flake inputs (justaguy.dev/drew).
    #  Exposed through pkgs so modules consume pkgs.ghee / pkgs.butterpal
    #  instead of reaching into inputs.* directly.
    (final: prev: {
      ghee = inputs.ghee.packages.${final.stdenv.hostPlatform.system}.ghee;
      butterpal = inputs.butterpal.packages.${final.stdenv.hostPlatform.system}.butterpal;
    })

    #  hyprmod: GTK4/libadwaita settings app for Hyprland, taken from its own
    #  flake overlay so pkgs.hyprmod is available everywhere. The overlay builds
    #  hyprmod from the flake source and pins the five hyprland-* Python
    #  bindings inline, which keeps them in sync with hyprmod's version floors.
    inputs.hyprmod.overlays.default

    #  nixpkgs 26.11 made rustPlatform.cargoSetupHook export
    #  ZSTD_SYS_USE_PKG_CONFIG, AWS_LC_SYS_USE_SYSTEM, OPENSSL_NO_VENDOR and
    #  friends for every Rust build (release note rl-2611). A package that does
    #  not add pkg-config plus the matching system library to its build inputs
    #  then dies in a crate's build script ("AWS_LC_SYS_USE_SYSTEM=1 requires a
    #  system-installed AWS-LC") even though it built fine while the crates
    #  vendored their own copies. dontCargoUseSystemLibs is the opt-out: it
    #  skips cargoUseSystemLibs for this package, so the crates build bundled
    #  again. Drop an entry once nixpkgs fixes the package upstream.
    (final: prev: {
      mcat-unwrapped = prev.mcat-unwrapped.overrideAttrs {dontCargoUseSystemLibs = true;};
      #  mcat is a makeWrapper script with the unwrapped store path baked in, so
      #  it needs rebuilding against the patched package too.
      mcat = prev.mcat.override {mcat-unwrapped = final.mcat-unwrapped;};
    })
  ];
}
