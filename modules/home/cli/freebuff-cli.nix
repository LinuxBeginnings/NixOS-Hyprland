# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#  freebuff-cli -- the freebuff coding agent, always run through npx.
#
#  freebuff is published to npm as a thin launcher package: index.js and
#  launcher.js download the platform native binary (sha256-verified against
#  binaryChecksums in its package.json) into ~/.config/manicode on first run,
#  so there is no self-contained derivation to build here.
#
#  That download is a generic dynamically linked ELF (interpreter
#  /lib64/ld-linux-x86-64.so.2, DT_NEEDED only glibc), so it depends on
#  programs.nix-ld in modules/packages.nix. Without nix-ld, NixOS' stub-ld
#  refuses to start it with "Could not start dynamically linked executable".
#
#  The wrapper deliberately resolves the package through npx and is named
#  freebuff-cli rather than freebuff: a globally installed or desktop build
#  called `freebuff` can shadow the CLI, while `npx freebuff` always resolves
#  the npm CLI package.
{pkgs, ...}: let
  binPath = pkgs.lib.makeBinPath [
    pkgs.nodejs # provides npm/npx
  ];
in {
  home.packages = [
    (pkgs.writeShellScriptBin "freebuff-cli" ''
      # Fail fast when the system cannot start foreign ELF binaries.
      #
      # NixOS points /lib64/ld-linux-x86-64.so.2 at stub-ld, which refuses to
      # start them, so the binary this package downloads would otherwise die
      # with "Could not start dynamically linked executable". programs.nix-ld
      # (modules/packages.nix) points that path at nix-ld instead and links
      # the real loader into the system profile.
      #
      # Test the loader file rather than `command -v nix-ld`: the nix-ld
      # module puts only a buildEnv of libraries in systemPackages, so there
      # is no nix-ld binary on PATH to find.
      if [ ! -x /run/current-system/sw/share/nix-ld/lib/ld.so ]; then
        printf '%s\n' \
          "freebuff-cli: nix-ld is not enabled on this system." \
          "The freebuff binary is a generic dynamically linked executable," \
          "and NixOS' stub-ld refuses to start those." \
          "" \
          "Enable it and rebuild:" \
          "  programs.nix-ld.enable = true;  # modules/packages.nix" \
          "  sudo nixos-rebuild switch --flake ~/NixOS-Hyprland/#<host>" >&2
        exit 1
      fi

      # Ensure npm/npx are available regardless of the caller's PATH
      export PATH=${binPath}:$PATH

      # `--yes` skips npx's interactive "Ok to proceed?" install prompt so the
      # first run also works from scripts and non-interactive shells.
      exec npx --yes freebuff "$@"
    '')
  ];
}
