#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# 💫 https://github.com/LinuxBeginnings 💫 #
#
# Installer for an existing clone of this repository.
# It never re-downloads the repository; the whole install sequence lives in
# scripts/lib/install-common.sh (shared with auto-install.sh).

set -euo pipefail

SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -e "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd) || SCRIPT_DIR=""
fi

# Locate the shared installer library.
NHL_LIB=""
for candidate in \
    "${SCRIPT_DIR:+$SCRIPT_DIR/scripts/lib/install-common.sh}" \
    "$PWD/scripts/lib/install-common.sh" \
    "$HOME/NixOS-Hyprland/scripts/lib/install-common.sh"; do
    if [ -n "$candidate" ] && [ -r "$candidate" ]; then
        NHL_LIB="$candidate"
        break
    fi
done

if [ -z "$NHL_LIB" ]; then
    printf '[ERROR] scripts/lib/install-common.sh was not found.\n' >&2
    printf '[ERROR] Run ./install.sh from the root of the NixOS-Hyprland repository.\n' >&2
    exit 1
fi

# shellcheck source=scripts/lib/install-common.sh
. "$NHL_LIB"

nhl_init_ui
nhl_print_banner 2026

repo_dir=""
if ! repo_dir=$(nhl_locate_repo "${SCRIPT_DIR}"); then
    nhl_die "This does not look like the NixOS-Hyprland repository (flake.nix and hosts/default are required)."
fi

nhl_install_flow "$repo_dir" || exit 1
