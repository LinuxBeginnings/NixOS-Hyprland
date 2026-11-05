#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# 💫 https://github.com/LinuxBeginnings 💫 #
#
# Self-contained bootstrap installer (safe to pipe into bash):
#   bash <(curl -L https://github.com/LinuxBeginnings/NixOS-Hyprland/raw/refs/heads/main/auto-install.sh)
#
# It only does the preflight checks and the clone itself; everything after that
# is the shared flow in scripts/lib/install-common.sh, which ships with the
# repository that is cloned below.

set -euo pipefail

REPO_URL="https://github.com/LinuxBeginnings/NixOS-Hyprland.git"
INSTALLER_URL="https://github.com/LinuxBeginnings/NixOS-Hyprland/raw/refs/heads/main/auto-install.sh"
REPO_DIR="$HOME/NixOS-Hyprland"
BACKUP_ROOT="$HOME/NixOS-Hyprland-backups"

# The library is not available until the repository has been cloned.
bootstrap_die() {
    printf '[ERROR] %s\n' "$*" >&2
    exit 1
}

bootstrap_print_banner() {
    if [ -t 1 ] && command -v clear >/dev/null 2>&1; then
        clear
    fi
    printf '\n\n\033[35m\n\t╦╔═┌─┐┌─┐╦    ╦ ╦┬ ┬┌─┐┬─┐┬  ┌─┐┌┐┌┌┬┐\n\t╠╩╗│ ││ │║    ╠═╣└┬┘├─┘├┬┘│  ├─┤│││ ││ 2026\n\t╩ ╩└─┘└─┘╩═╝  ╩ ╩ ┴ ┴  ┴└─┴─┘┴ ┴┘└┘─┴┘ \n\033[0m\n\n'
}

bootstrap_print_banner

# --- preflight (duplicated from the library on purpose: it does not exist yet) ---
if [ -z "${BASH_VERSION:-}" ]; then
    bootstrap_die "This installer requires bash. Run it with: bash <(curl -L $INSTALLER_URL)"
fi

if [ "$(id -u)" -eq 0 ]; then
    bootstrap_die "Do not run this installer as root; run it as your normal user."
fi

os_id=""
if [ -r /etc/os-release ]; then
    os_id=$(. /etc/os-release && printf '%s' "${ID:-}")
fi
if [ "$os_id" != "nixos" ]; then
    bootstrap_die "This installer only supports NixOS (detected: ${os_id:-unknown})."
fi

command -v git >/dev/null 2>&1 || bootstrap_die "git is not installed. Example: nix-shell -p git"
command -v lspci >/dev/null 2>&1 ||
    bootstrap_die "pciutils is not installed (needed to detect your GPU). Example: nix-shell -p pciutils"
if ! (: </dev/tty) 2>/dev/null; then
    bootstrap_die "This installer needs an interactive terminal."
fi

# --- fresh checkout -----------------------------------------------------------
cd -- "$HOME" || bootstrap_die "Cannot change to $HOME."

if [ -e "$REPO_DIR" ]; then
    backup_dir="$BACKUP_ROOT/$(date +%Y-%m-%d-%H-%M-%S)"
    if [ -e "$backup_dir" ]; then
        backup_dir="$backup_dir-$$"
    fi
    printf '[NOTE] Backing up %s to %s\n' "$REPO_DIR" "$backup_dir"
    mkdir -p -- "$BACKUP_ROOT" || bootstrap_die "Could not create $BACKUP_ROOT."
    mv -- "$REPO_DIR" "$backup_dir" || bootstrap_die "Could not move $REPO_DIR out of the way."
else
    printf '[OK] Thank you for choosing KooL'"'"'s NixOS-Hyprland\n'
fi

printf '[NOTE] Cloning NixOS-Hyprland into %s...\n' "$REPO_DIR"
git clone --depth 1 "$REPO_URL" "$REPO_DIR" ||
    bootstrap_die "Failed to clone $REPO_URL; check your network connection and try again."

NHL_LIB="$REPO_DIR/scripts/lib/install-common.sh"
if [ ! -r "$NHL_LIB" ]; then
    bootstrap_die "$NHL_LIB is missing; the clone looks incomplete."
fi

# shellcheck source=/dev/null
. "$NHL_LIB"

nhl_install_flow "$REPO_DIR" || exit 1
