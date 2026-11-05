#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Common installer library for NixOS-Hyprland.
#
# This file is sourced, never executed:
#   install.sh       sources it from a clone of this repository
#   auto-install.sh  bootstraps the clone first, then sources it from there
#
# The whole interactive install sequence lives in `nhl_install_flow` so both
# entry points behave identically and stay small.

if [ -z "${BASH_VERSION:-}" ]; then
    printf '[ERROR] %s requires bash.\n' "${0##*/}" >&2
    # shellcheck disable=SC2317 # reached only when this file is executed directly
    return 1 2>/dev/null || exit 1
fi

# --- tunables (override from the environment if needed) ----------------------
NHL_DOTFILES_REPO="${NHL_DOTFILES_REPO:-https://github.com/LinuxBeginnings/Hyprland-Dots}"
NHL_DOTFILES_DIR="${NHL_DOTFILES_DIR:-$HOME/Hyprland-Dots}"
NHL_GTK_REPO="${NHL_GTK_REPO:-https://github.com/LinuxBeginnings/GTK-themes-icons}"
NHL_GO_MIN_VERSION="${NHL_GO_MIN_VERSION:-1.25.5}"
NHL_TEMP_SWAPFILE="${NHL_TEMP_SWAPFILE:-/swapfile_install}"
NHL_HW_ATTEMPTS="${NHL_HW_ATTEMPTS:-3}"
# Input source for interactive prompts. Point it at a file to drive the
# installer from a script; it defaults to the controlling terminal so prompts
# keep working when the script itself is piped into bash.
NHL_PROMPT_SOURCE="${NHL_PROMPT_SOURCE:-/dev/tty}"

# Plain fallbacks, upgraded to colours by nhl_init_ui when the terminal can do it.
: "${OK:=[OK]}" "${ERROR:=[ERROR]}" "${NOTE:=[NOTE]}" "${INFO:=[INFO]}" "${WARN:=[WARN]}" \
    "${ACTION:=[ACTION]}" "${MAGENTA:=}" "${RESET:=}"

# Answers are read through one persistent descriptor. Reopening the source for
# every prompt would restart at the first line for regular files, so a prompt
# loop could never consume new input (a terminal would be unaffected).
NHL_PROMPT_FD_READY=0
if { : <"$NHL_PROMPT_SOURCE"; } 2>/dev/null; then
    if exec 3<"$NHL_PROMPT_SOURCE"; then
        NHL_PROMPT_FD_READY=1
    fi
fi

# =============================================================================
# Output helpers
# =============================================================================

nhl_init_ui() {
    if [ -t 1 ] && [ -n "${TERM:-}" ] && command -v tput >/dev/null 2>&1 &&
        tput sgr0 >/dev/null 2>&1; then
        OK="$(tput setaf 2)[OK]$(tput sgr0)"
        ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
        NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
        INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
        WARN="$(tput setaf 1)[WARN]$(tput sgr0)"
        ACTION="$(tput setaf 6)[ACTION]$(tput sgr0)"
        MAGENTA="$(tput setaf 5)"
        RESET="$(tput sgr0)"
    else
        OK="[OK]" ERROR="[ERROR]" NOTE="[NOTE]" INFO="[INFO]" WARN="[WARN]" ACTION="[ACTION]"
        MAGENTA="" RESET=""
    fi
}

nhl_print_banner() {
    local year="${1:-2026}"
    printf '\n\n'
    printf '\033[35m\n\t╦╔═┌─┐┌─┐╦    ╦ ╦┬ ┬┌─┐┬─┐┬  ┌─┐┌┐┌┌┬┐\n\t╠╩╗│ ││ │║    ╠═╣└┬┘├─┘├┬┘│  ├─┤│││ ││ %s\n\t╩ ╩└─┘└─┘╩═╝  ╩ ╩ ┴ ┴  ┴└─┴─┘┴ ┴┘└┘─┴┘ \n\033[0m\n' "$year"
    printf '\n'
}

nhl_hr() { printf -- '-----\n'; }
nhl_ok() { printf '%s %s\n' "$OK" "$*"; }
nhl_note() { printf '%s %s\n' "$NOTE" "$*"; }
nhl_info() { printf '%s %s\n' "$INFO" "$*"; }
nhl_warn() { printf '%s %s\n' "$WARN" "$*" >&2; }
nhl_error() { printf '%s %s\n' "$ERROR" "$*" >&2; }
nhl_die() {
    nhl_error "$*"
    exit 1
}

# =============================================================================
# Validators (return 0 when the value is acceptable)
# =============================================================================

nhl_valid_hostname() {
    local value="${1:-}"
    [ -n "$value" ] && [ "${#value}" -le 63 ] &&
        [[ $value =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$ ]]
}

nhl_valid_username() {
    local value="${1:-}"
    [ -n "$value" ] && [ "${#value}" -le 32 ] &&
        [[ $value =~ ^[a-z_][a-z0-9_-]*$ ]]
}

nhl_valid_keymap() {
    [[ ${1:-} =~ ^[A-Za-z0-9][A-Za-z0-9_,+-]*$ ]]
}

nhl_valid_timezone() {
    [[ ${1:-} =~ ^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$ ]]
}

nhl_valid_timezone_or_blank() {
    [ -z "${1:-}" ] || nhl_valid_timezone "$1"
}

nhl_valid_yes_or_no() {
    [[ ${1:-} =~ ^[Yy]([Ee][Ss])?$|^[Nn]([Oo])?$ ]]
}

nhl_valid_gpu_profile() {
    case "${1:-}" in
        amd | intel | nvidia | nvidia-laptop | vm) return 0 ;;
        *) return 1 ;;
    esac
}

# =============================================================================
# Prompts
# =============================================================================

nhl_tty_available() {
    (: <"$NHL_PROMPT_SOURCE") 2>/dev/null
}

# Prints the answer on stdout (the prompt itself goes to stderr, like read -p).
# Every local is prefixed so it can never shadow the variable the caller targets:
# bash scoping is dynamic, so a local named like the caller's variable would
# silently swallow the answer.
nhl_read_line() {
    local __nhl_question="$1" __nhl_default="${2:-}" __nhl_answer="" __nhl_status=0

    printf '%s %s ' "$ACTION" "$__nhl_question" >&2
    if [ -n "$__nhl_default" ]; then
        printf '[%s] ' "$__nhl_default" >&2
    fi

    if [ "$NHL_PROMPT_FD_READY" -eq 1 ]; then
        IFS= read -r __nhl_answer <&3 || __nhl_status=$?
    else
        if ! nhl_tty_available; then
            nhl_error "This installer needs an interactive terminal, but $NHL_PROMPT_SOURCE is not available."
            nhl_error "Run it from a terminal session (not from cron, CI or a detached pipe)."
            return 1
        fi
        IFS= read -r __nhl_answer <"$NHL_PROMPT_SOURCE" || __nhl_status=$?
    fi

    if [ "$__nhl_status" -ne 0 ] && [ -z "$__nhl_answer" ]; then
        nhl_error "No more input available from $NHL_PROMPT_SOURCE."
        return 1
    fi
    __nhl_answer="${__nhl_answer%$'\r'}"
    printf '%s\n' "${__nhl_answer:-$__nhl_default}"
}

# nhl_prompt <variable> <question> <default> [validator]
nhl_prompt() {
    local __nhl_target="$1" __nhl_question="$2" __nhl_default="${3:-}" __nhl_validator="${4:-}"
    local __nhl_answer=""

    while :; do
        if ! __nhl_answer=$(nhl_read_line "$__nhl_question" "$__nhl_default"); then
            nhl_error "Input stream closed while waiting for an answer."
            return 1
        fi
        if [ -z "$__nhl_validator" ] || "$__nhl_validator" "$__nhl_answer"; then
            printf -v "$__nhl_target" '%s' "$__nhl_answer"
            return 0
        fi
        nhl_error "'$__nhl_answer' is not a valid answer, please try again."
    done
}

# =============================================================================
# Preflight checks
# =============================================================================

nhl_require_non_root() {
    if [ "$(id -u)" -eq 0 ]; then
        nhl_error "Do not run this installer as root."
        nhl_error "Run it as your normal user; sudo is used only for the commands that need it."
        nhl_error "Otherwise the flake and your dotfiles end up owned by root in /root."
        return 1
    fi
}

nhl_require_nixos() {
    local os_id=""
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        os_id=$(. /etc/os-release && printf '%s' "${ID:-}")
    fi
    if [ "$os_id" != "nixos" ]; then
        nhl_error "This installer only supports NixOS (detected: ${os_id:-unknown})."
        return 1
    fi
    nhl_ok "Verified this is NixOS."
}

nhl_require_command() {
    local command_name="$1" hint="${2:-}"
    if command -v "$command_name" >/dev/null 2>&1; then
        return 0
    fi
    nhl_error "$command_name is not installed."
    if [ -n "$hint" ]; then
        nhl_error "$hint"
    fi
    return 1
}

nhl_check_go_version() {
    local min_version="$NHL_GO_MIN_VERSION" nix_go_version="" go_version=""

    if command -v nix >/dev/null 2>&1; then
        nix_go_version=$(
            NIX_CONFIG="experimental-features = nix-command flakes" \
                nix eval --raw "nixpkgs#go.version" 2>/dev/null || true
        )
        # nix eval prints a trailing newline for --raw strings in some versions
        nix_go_version="${nix_go_version//[[:space:]]/}"
    fi

    if [ -n "$nix_go_version" ]; then
        if nhl_version_ge "$nix_go_version" "$min_version"; then
            nhl_ok "Go in nixpkgs is $nix_go_version (>= $min_version)."
            return 0
        fi
        nhl_error "Go in nixpkgs is $nix_go_version, but $min_version or newer is required."
        return 1
    fi

    if command -v go >/dev/null 2>&1; then
        go_version=$(go version 2>/dev/null | awk '{print $3}' || true)
        go_version="${go_version#go}"
        if [ -n "$go_version" ] && nhl_version_ge "$go_version" "$min_version"; then
            nhl_ok "Go is $go_version (>= $min_version)."
            return 0
        fi
        nhl_error "Go is ${go_version:-unknown}, but $min_version or newer is required."
        return 1
    fi

    nhl_error "Unable to determine the Go version; Go $min_version+ is needed to build waybar-weather."
    return 1
}

# nhl_version_ge <version> <minimum> -> 0 when version >= minimum
nhl_version_ge() {
    local version="$1" minimum="$2" index part_version part_minimum
    local -a version_parts=() minimum_parts=()

    IFS='.' read -r -a version_parts <<<"${version//[^0-9.]/}"
    IFS='.' read -r -a minimum_parts <<<"${minimum//[^0-9.]/}"

    for ((index = 0; index < ${#minimum_parts[@]}; index++)); do
        part_version="${version_parts[index]:-0}"
        part_minimum="${minimum_parts[index]:-0}"
        part_version=${part_version:-0}
        part_minimum=${part_minimum:-0}
        if [ "$part_version" -gt "$part_minimum" ]; then
            return 0
        fi
        if [ "$part_version" -lt "$part_minimum" ]; then
            return 1
        fi
    done
    return 0
}

# =============================================================================
# Nix file editing
# =============================================================================

# nhl_nix_set <file> <dotted option path> <nix value literal>
#
# Scope aware: matches `a.b.c = X;`, `a = { b.c = X; };` and
# `a = { b = { c = X; }; };` while ignoring same-named attributes that live in
# other attribute sets. The values are handed to awk through the environment so
# backslashes and ampersands are never reinterpreted.
nhl_nix_set() {
    local file="$1" path="$2" value="$3" temp=""

    [ -f "$file" ] || {
        nhl_error "Cannot update $path: $file does not exist."
        return 1
    }
    temp=$(mktemp -- "${file}.XXXXXX") || {
        nhl_error "Cannot create a temporary file next to $file."
        return 1
    }

    if NHL_NIX_PATH="$path" NHL_NIX_VALUE="$value" awk '
        BEGIN {
            path = ENVIRON["NHL_NIX_PATH"]
            value = ENVIRON["NHL_NIX_VALUE"]
            depth = 0
            found = 0
        }

        # A line that only closes an attribute set ends the current scope.
        $0 ~ /^[[:space:]]*}[[:space:]]*;?[[:space:]]*$/ {
            if (depth > 0) depth--
            print
            next
        }

        # `name = {` opens an attribute set; the name itself may be dotted.
        match($0, /^[[:space:]]*[A-Za-z0-9_.-]+[[:space:]]*=[[:space:]]*\{[[:space:]]*$/) {
            name = substr($0, RSTART, RLENGTH)
            gsub(/^[[:space:]]+/, "", name)
            sub(/[[:space:]]*=[[:space:]]*\{[[:space:]]*$/, "", name)
            depth++
            scope[depth] = (depth > 1) ? scope[depth - 1] "." name : name
            print
            next
        }

        # `name = value;` relative to the scope this line sits in.
        match($0, /^[[:space:]]*[A-Za-z0-9_.-]+[[:space:]]*=[[:space:]]*/) {
            name = substr($0, RSTART, RLENGTH)
            gsub(/^[[:space:]]+/, "", name)
            sub(/[[:space:]]*=[[:space:]]*$/, "", name)
            full = (depth > 0) ? scope[depth] "." name : name
            if (!found && full == path) {
                head = substr($0, 1, RSTART + RLENGTH - 1)
                tail = substr($0, RLENGTH + 1)
                sub(/^[^;]*;/, "", tail) # keep any trailing comment
                print head value ";" tail
                found = 1
                next
            }
        }

        { print }

        END { exit(found ? 0 : 1) }
    ' "$file" >"$temp"; then
        if mv -- "$temp" "$file"; then
            return 0
        fi
        rm -f -- "$temp"
        nhl_error "Could not write $file."
        return 1
    fi

    rm -f -- "$temp"
    nhl_error "Option '$path' was not found in $file; add it manually."
    return 1
}

# nhl_set_string_option <file> <option path> <value>
nhl_set_string_option() {
    nhl_nix_set "$1" "$2" "\"$3\""
}

# nhl_set_nix_bool <file> <option path> <true|false>
nhl_set_nix_bool() {
    case "$3" in
        true | false) ;;
        *)
            nhl_error "nhl_set_nix_bool: value must be 'true' or 'false' (got '$3')."
            return 1
            ;;
    esac
    nhl_nix_set "$1" "$2" "$3"
}

# nhl_insert_option <file> <nix line>
# Appends an option before the final closing brace of the attribute set.
nhl_insert_option() {
    local file="$1" line="$2" temp=""
    [ -f "$file" ] || {
        nhl_error "Cannot update $file: it does not exist."
        return 1
    }
    temp=$(mktemp -- "${file}.XXXXXX") || {
        nhl_error "Cannot create a temporary file next to $file."
        return 1
    }

    if awk -v line="$line" '
        { lines[NR] = $0 }
        END {
            last = 0
            for (i = NR; i >= 1; i--) {
                if (lines[i] ~ /^[[:space:]]*}[[:space:]]*$/) { last = i; break }
            }
            if (!last) exit 1
            for (i = 1; i <= NR; i++) {
                if (i == last) print "  " line
                print lines[i]
            }
        }
    ' "$file" >"$temp"; then
        mv -- "$temp" "$file" || {
            rm -f -- "$temp"
            nhl_error "Could not write $file."
            return 1
        }
        return 0
    fi

    rm -f -- "$temp"
    nhl_error "Could not find where to insert '$line' in $file."
    return 1
}

# nhl_remove_option <file> <option path>
nhl_remove_option() {
    local file="$1" path="$2" temp=""
    [ -f "$file" ] || return 0
    temp=$(mktemp -- "${file}.XXXXXX") || return 1
    if awk -v pattern="^[[:space:]]*${path//./\\.}[[:space:]]*=" '$0 !~ pattern' \
        "$file" >"$temp"; then
        mv -- "$temp" "$file" || {
            rm -f -- "$temp"
            return 1
        }
        return 0
    fi
    rm -f -- "$temp"
    return 1
}

# nhl_set_string_or_insert <file> <option path> <value>
# Updates an existing assignment, or adds the option when it is not there yet.
nhl_set_string_or_insert() {
    local file="$1" path="$2" value="$3"
    if nhl_set_string_option "$file" "$path" "$value" 2>/dev/null; then
        return 0
    fi
    nhl_insert_option "$file" "$path = \"$value\";"
}

# nhl_set_bool_or_insert <file> <option path> <true|false>
nhl_set_bool_or_insert() {
    local file="$1" path="$2" value="$3"
    if nhl_set_nix_bool "$file" "$path" "$value" 2>/dev/null; then
        return 0
    fi
    nhl_insert_option "$file" "$path = $value;"
}

# nhl_get_string_value <file> <attribute name>
# Prints the value of `name = "...";`, without the quotes. The name is matched
# without its parent attribute sets, so pass keys that are unique in the file
# (intelBusID, nvidiaBusID); use nhl_nix_set for scope aware writes.
# Returns 1 when the attribute is missing.
nhl_get_string_value() {
    local file="$1" name="$2"

    [ -f "$file" ] && [ -n "$name" ] || return 1
    NHL_NIX_NAME="$name" awk '
        BEGIN { name = ENVIRON["NHL_NIX_NAME"]; found = 0 }
        match($0, "^[[:space:]]*" name "[[:space:]]*=[[:space:]]*\"") {
            rest = substr($0, RSTART + RLENGTH)
            end = index(rest, "\"")
            if (end > 0 && !found) {
                print substr(rest, 1, end - 1)
                found = 1
            }
        }
        END { exit(found ? 0 : 1) }
    ' "$file"
}

# nhl_get_nix_value <file> <dotted option path>
# Prints the raw literal of `a.b.c = ...;`, honouring attribute set nesting the
# same way nhl_nix_set does. Returns 1 when the option is not set.
nhl_get_nix_value() {
    local file="$1" path="$2"

    [ -f "$file" ] && [ -n "$path" ] || return 1
    NHL_NIX_PATH="$path" awk '
        BEGIN { path = ENVIRON["NHL_NIX_PATH"]; depth = 0; found = 0 }

        $0 ~ /^[[:space:]]*}[[:space:]]*;?[[:space:]]*$/ {
            if (depth > 0) depth--
            next
        }

        match($0, /^[[:space:]]*[A-Za-z0-9_.-]+[[:space:]]*=[[:space:]]*\{[[:space:]]*$/) {
            name = substr($0, RSTART, RLENGTH)
            gsub(/^[[:space:]]+/, "", name)
            sub(/[[:space:]]*=[[:space:]]*\{[[:space:]]*$/, "", name)
            depth++
            scope[depth] = (depth > 1) ? scope[depth - 1] "." name : name
            next
        }

        match($0, /^[[:space:]]*[A-Za-z0-9_.-]+[[:space:]]*=[[:space:]]*/) {
            name = substr($0, RSTART, RLENGTH)
            gsub(/^[[:space:]]+/, "", name)
            sub(/[[:space:]]*=[[:space:]]*$/, "", name)
            full = (depth > 0) ? scope[depth] "." name : name
            if (!found && full == path) {
                value = substr($0, RSTART + RLENGTH)
                sub(/;.*/, "", value)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
                print value
                found = 1
            }
        }

        END { exit(found ? 0 : 1) }
    ' "$file"
}

# nhl_get_bool_value <file> <dotted option path> -> prints true/false, 1 if unset
nhl_get_bool_value() {
    local value=""

    value=$(nhl_get_nix_value "$1" "$2") || return 1
    case "$value" in
        true | false)
            printf '%s\n' "$value"
            return 0
            ;;
    esac
    return 1
}

# =============================================================================
# Repository helpers
# =============================================================================

nhl_is_repo() {
    local dir="${1:-}"
    [ -n "$dir" ] && [ -d "$dir" ] && [ -f "$dir/flake.nix" ] && [ -d "$dir/hosts/default" ]
}

# nhl_locate_repo [script dir] -> prints the repository root
nhl_locate_repo() {
    local candidate=""
    for candidate in "${1:-}" "$PWD" "$HOME/NixOS-Hyprland"; do
        if nhl_is_repo "$candidate"; then
            (cd -- "$candidate" && pwd)
            return 0
        fi
    done
    return 1
}

nhl_current_username() {
    local user="${USER:-}"
    if [ -z "$user" ]; then
        user=$(id -un 2>/dev/null || true)
    fi
    if [ -z "$user" ]; then
        nhl_error "Unable to determine the current user name."
        return 1
    fi
    if ! nhl_valid_username "$user"; then
        nhl_error "'$user' is not a valid NixOS user name (lowercase letters, digits, '_' and '-')."
        nhl_error "Set the user manually in flake.nix and hosts/<host>/users.nix."
        return 1
    fi
    printf '%s\n' "$user"
}

# nhl_create_host <hostname>
nhl_create_host() {
    local host_name="$1"
    local host_dir="./hosts/$host_name"

    nhl_is_repo "$PWD" || {
        nhl_error "Run the installer from the NixOS-Hyprland repository root."
        return 1
    }
    if [ "$host_name" = "default" ]; then
        nhl_note "Default hostname selected, using hosts/default as-is."
        return 0
    fi
    if [ -d "$host_dir" ]; then
        nhl_warn "$host_dir already exists; reusing it."
        return 0
    fi

    mkdir -p -- "$host_dir" || {
        nhl_error "Could not create $host_dir."
        return 1
    }
    cp -- hosts/default/*.nix "$host_dir"/ || {
        nhl_error "Could not copy the default host files into $host_dir."
        return 1
    }
    # hardware.nix must be generated for this machine, never inherited from default.
    rm -f -- "$host_dir/hardware.nix"
    nhl_ok "Created $host_dir from hosts/default."
}

# Stage the generated host so `nixos-rebuild --flake` can see untracked files.
nhl_stage_changes() {
    local host_name="$1"
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        nhl_warn "Not a git repository; skipping 'git add' (flakes use the git index)."
        return 0
    fi
    if git add -- flake.nix hosts >/dev/null 2>&1; then
        nhl_ok "Staged flake.nix and hosts/ for the rebuild."
        return 0
    fi
    nhl_error "Could not stage flake.nix and hosts/$host_name with git."
    return 1
}

# nhl_generate_hardware <hostname>
nhl_generate_hardware() {
    local host_name="$1" target="./hosts/$1/hardware.nix" attempt="" output=""
    local max_attempts="$NHL_HW_ATTEMPTS"

    [ -d "./hosts/$host_name" ] || {
        nhl_error "hosts/$host_name does not exist; cannot write hardware.nix."
        return 1
    }

    for ((attempt = 1; attempt <= max_attempts; attempt++)); do
        output=$(mktemp) || {
            nhl_error "Cannot create a temporary file for the hardware configuration."
            return 1
        }
        # Capture first and only move into place on success: a redirect alone
        # would leave an empty file behind on failure and look like success.
        # shellcheck disable=SC2024 # the file should be owned by the invoking user
        if sudo nixos-generate-config --show-hardware-config >"$output" 2>/dev/null &&
            [ -s "$output" ] && grep -q 'fileSystems' "$output"; then
            if mv -- "$output" "$target"; then
                nhl_ok "Hardware configuration written to $target."
                return 0
            fi
            nhl_error "Could not move the hardware configuration into $target."
            rm -f -- "$output"
            return 1
        fi
        rm -f -- "$output"
        nhl_warn "Failed to generate the hardware configuration (attempt $attempt of $max_attempts)."
        sleep 1
    done

    nhl_error "Unable to generate $target after $max_attempts attempts."
    return 1
}

# nhl_rebuild <hostname> <repo dir>
nhl_rebuild() {
    local host_name="$1" repo="$2" build_flags=""
    local -a flag_array=()

    build_flags=$(nhl_get_build_flags)
    if [ -n "$build_flags" ]; then
        read -r -a flag_array <<<"$build_flags"
    fi

    nhl_note "Rebuilding NixOS... this can take a while."
    nhl_info "In the meantime, go grab a coffee and stretch your legs."
    nhl_hr

    if sudo NIX_CONFIG="experimental-features = nix-command flakes" \
        nixos-rebuild switch "${flag_array[@]}" --flake "$repo/#$host_name"; then
        nhl_ok "System rebuilt and switched to the new generation."
        return 0
    fi

    nhl_warn "'nixos-rebuild switch' failed (e.g. a service inhibitor blocked activation)."
    nhl_note "Trying 'nixos-rebuild boot' so the new generation is at least available after a reboot..."
    if sudo NIX_CONFIG="experimental-features = nix-command flakes" \
        nixos-rebuild boot "${flag_array[@]}" --flake "$repo/#$host_name"; then
        nhl_ok "Boot configuration installed; reboot to activate it."
        return 0
    fi

    nhl_error "Both 'nixos-rebuild switch' and 'nixos-rebuild boot' failed."
    nhl_error "Fix the evaluation error above, then run:"
    nhl_error "  sudo nixos-rebuild switch --flake $repo/#$host_name"
    return 1
}

# =============================================================================
# Hardware detection and host configuration
# =============================================================================

nhl_is_vm() {
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        systemd-detect-virt --quiet --vm && return 0
        return 1
    fi
    if command -v hostnamectl >/dev/null 2>&1; then
        hostnamectl 2>/dev/null |
            awk '/Chassis:[[:space:]]*vm/ { found = 1 } END { exit(found ? 0 : 1) }'
        return
    fi
    return 1
}

# nhl_pci_bus_id <case-insensitive regex>
# Prints the bus ID of the first display device matching <regex>, in the form the
# NVIDIA driver expects: "PCI:1:0:0".
# lspci prints the address in hex ("0000:01:00.0") while the driver wants
# decimal, so 0x0a becomes 10; the PCI domain is dropped, as Xorg does.
nhl_pci_bus_id() {
    local pattern="$1" address=""

    command -v lspci >/dev/null 2>&1 || return 1
    address=$(lspci -D 2>/dev/null |
        grep -iE '(VGA|3D|Display)' |
        grep -iE -- "$pattern" |
        awk 'NR == 1 { print $1 }') || return 1

    if [[ $address =~ ^([0-9a-fA-F]{4}:)?([0-9a-fA-F]{2}):([0-9a-fA-F]{2})\.([0-7])$ ]]; then
        printf 'PCI:%d:%d:%d\n' "0x${BASH_REMATCH[2]}" "0x${BASH_REMATCH[3]}" "0x${BASH_REMATCH[4]}"
        return 0
    fi
    return 1
}

# nhl_set_prime_bus_ids <config file>
# Fills in drivers.nvidia-prime.{intelBusID,nvidiaBusID} from lspci. Offload
# silently breaks when those keep their empty/default values, and a wrong value
# only shows up as a black screen, so the result is reported either way.
# Values that are already set are never overwritten without an explicit answer.
nhl_set_prime_bus_ids() {
    local config_file="$1" intel_bus="" nvidia_bus=""
    local current_intel="" current_nvidia="" replace=false answer="" intel_final="" nvidia_final=""

    intel_bus=$(nhl_pci_bus_id 'intel') || intel_bus=""
    nvidia_bus=$(nhl_pci_bus_id 'nvidia') || nvidia_bus=""
    current_intel=$(nhl_get_string_value "$config_file" intelBusID) || current_intel=""
    current_nvidia=$(nhl_get_string_value "$config_file" nvidiaBusID) || current_nvidia=""

    if [ -z "$intel_bus" ] || [ -z "$nvidia_bus" ]; then
        if [ -n "$current_intel" ] && [ -n "$current_nvidia" ]; then
            nhl_warn "Could not detect the Prime offload bus IDs; keeping the configured ones."
            nhl_note "Intel $current_intel, NVIDIA $current_nvidia."
            return 0
        fi
        nhl_warn "Could not detect the Prime offload bus IDs automatically."
        nhl_note "Set drivers.nvidia-prime.intelBusID and nvidiaBusID in $config_file."
        nhl_note "Find them with: lspci | grep -E 'VGA|3D' (00:02.0 becomes \"PCI:0:2:0\")."
        return 1
    fi

    if [ -n "$current_intel" ] && [ -n "$current_nvidia" ]; then
        if [ "$current_intel" = "$intel_bus" ] && [ "$current_nvidia" = "$nvidia_bus" ]; then
            nhl_ok "Prime offload bus IDs already correct: Intel $intel_bus, NVIDIA $nvidia_bus."
            return 0
        fi
        nhl_note "Prime offload bus IDs are already set to Intel $current_intel, NVIDIA $current_nvidia."
        if ! nhl_prompt answer \
            "Detected Intel $intel_bus, NVIDIA $nvidia_bus. Replace the configured values? (y/n)" \
            "n" nhl_valid_yes_or_no; then
            nhl_note "Keeping the configured bus IDs."
            return 0
        fi
        case "${answer,,}" in
            y | yes) replace=true ;;
            *)
                nhl_note "Keeping the configured bus IDs."
                return 0
                ;;
        esac
    fi

    # Write only what is missing, unless the user asked for a full replacement.
    if [ -z "$current_intel" ] || [ "$replace" = true ]; then
        nhl_set_string_or_insert "$config_file" drivers.nvidia-prime.intelBusID "$intel_bus" || return 1
    fi
    if [ -z "$current_nvidia" ] || [ "$replace" = true ]; then
        nhl_set_string_or_insert "$config_file" drivers.nvidia-prime.nvidiaBusID "$nvidia_bus" || return 1
    fi

    intel_final=$(nhl_get_string_value "$config_file" intelBusID) || intel_final="$intel_bus"
    nvidia_final=$(nhl_get_string_value "$config_file" nvidiaBusID) || nvidia_final="$nvidia_bus"
    nhl_ok "Prime offload: Intel at $intel_final, NVIDIA at $nvidia_final."
}

nhl_detect_gpu_and_toggle() {
    local host_name="$1"
    local config_file="./hosts/$host_name/config.nix"
    local has_vm=false has_nvidia=false has_amd=false has_intel=false
    local detected="" profile="" answer="" applied=true
    local -a toggles=(
        drivers.amdgpu.enable
        drivers.intel.enable
        drivers.nvidia.enable
        drivers.nvidia-prime.enable
        vm.guest-services.enable
    )

    if [ ! -f "$config_file" ]; then
        config_file="./hosts/default/config.nix"
    fi
    if [ ! -f "$config_file" ]; then
        nhl_error "Cannot find a config.nix for host '$host_name'."
        return 1
    fi

    if nhl_is_vm; then
        has_vm=true
    fi
    if command -v lspci >/dev/null 2>&1; then
        local line=""
        while IFS= read -r line; do
            case "${line,,}" in
                *nvidia*) has_nvidia=true ;;
                *"advanced micro devices"* | *amd*) has_amd=true ;;
                *intel*) has_intel=true ;;
            esac
        done < <(lspci 2>/dev/null | grep -iE '(VGA|3D|Display)' || true)
    else
        nhl_warn "lspci is not available; the GPU cannot be detected automatically."
    fi

    if [ "$has_vm" = true ]; then
        detected="vm"
    elif [ "$has_nvidia" = true ] && [ "$has_intel" = true ]; then
        detected="nvidia-laptop"
    elif [ "$has_nvidia" = true ]; then
        detected="nvidia"
    elif [ "$has_amd" = true ]; then
        detected="amd"
    elif [ "$has_intel" = true ]; then
        detected="intel"
    fi

    if [ -n "$detected" ]; then
        nhl_prompt answer "Detected GPU profile '$detected'. Use it? (y/n)" "y" nhl_valid_yes_or_no || return 1
        case "${answer,,}" in
            y | yes) profile="$detected" ;;
        esac
    else
        nhl_warn "Could not detect a GPU profile."
    fi

    if [ -z "$profile" ]; then
        nhl_prompt profile "Enter your GPU profile (amd|intel|nvidia|nvidia-laptop|vm)" "amd" nhl_valid_gpu_profile || return 1
    fi

    # Reset every toggle first so a re-run cannot leave two profiles enabled.
    for option in "${toggles[@]}"; do
        nhl_set_nix_bool "$config_file" "$option" false ||
            nhl_warn "Could not reset $option in $config_file."
    done

    case "$profile" in
        vm)
            nhl_set_nix_bool "$config_file" vm.guest-services.enable true || applied=false
            ;;
        nvidia-laptop)
            nhl_set_nix_bool "$config_file" drivers.nvidia-prime.enable true || applied=false
            nhl_set_nix_bool "$config_file" drivers.intel.enable true || applied=false
            nhl_set_prime_bus_ids "$config_file" || true
            ;;
        nvidia)
            nhl_set_nix_bool "$config_file" drivers.nvidia.enable true || applied=false
            ;;
        amd)
            nhl_set_nix_bool "$config_file" drivers.amdgpu.enable true || applied=false
            ;;
        intel)
            nhl_set_nix_bool "$config_file" drivers.intel.enable true || applied=false
            ;;
        *)
            nhl_error "Unknown GPU profile '$profile'."
            return 1
            ;;
    esac

    if [ "$applied" != true ]; then
        nhl_error "Could not enable the '$profile' profile in $config_file; edit it manually."
        return 1
    fi
    NHL_GPU_PROFILE="$profile"
    nhl_ok "Enabled the '$profile' driver profile in $config_file."
}

nhl_prompt_timezone_console() {
    local host_name="$1" default_keymap="${2:-us}"
    local config_file="./hosts/$host_name/config.nix"
    local time_zone="" console_keymap=""

    if [ ! -f "$config_file" ]; then
        config_file="./hosts/default/config.nix"
    fi
    if [ ! -f "$config_file" ]; then
        nhl_error "Cannot find a config.nix for host '$host_name'."
        return 1
    fi

    nhl_prompt time_zone "Enter your timezone (e.g. America/New_York), blank for automatic" \
        "" nhl_valid_timezone_or_blank

    if [ -z "$time_zone" ]; then
        nhl_set_bool_or_insert "$config_file" services.automatic-timezoned.enable true ||
            nhl_warn "Could not enable automatic timezoned in $config_file."
        nhl_remove_option "$config_file" time.timeZone ||
            nhl_warn "Could not remove the existing time.timeZone line."
        nhl_ok "Timezone will be detected automatically."
    else
        if command -v timedatectl >/dev/null 2>&1; then
            if ! timedatectl list-timezones 2>/dev/null |
                awk -v tz="$time_zone" '$0 == tz { found = 1 } END { exit(found ? 0 : 1) }'; then
                nhl_warn "'$time_zone' is not in the system timezone list; double-check the spelling."
            fi
        fi
        if ! nhl_set_string_or_insert "$config_file" time.timeZone "$time_zone"; then
            nhl_error "Could not set time.timeZone in $config_file."
            return 1
        fi
        nhl_set_bool_or_insert "$config_file" services.automatic-timezoned.enable false ||
            nhl_warn "Could not disable automatic timezoned in $config_file."
        nhl_ok "Timezone set to $time_zone."
    fi

    nhl_prompt console_keymap "Enter your console keymap" "$default_keymap" nhl_valid_keymap
    if ! nhl_set_string_or_insert "$config_file" console.keyMap "$console_keymap"; then
        nhl_error "Could not set console.keyMap in $config_file."
        return 1
    fi
    nhl_ok "Console keymap set to $console_keymap."
}

# =============================================================================
# Build resources
# =============================================================================

nhl_memory_mb() {
    local key="$1" fallback="$2" value=""
    value=$(free -m 2>/dev/null | awk -v key="$key" '$1 == key ":" { print $2; exit }' || true)
    case "$value" in
        '' | *[!0-9]*) value="$fallback" ;;
    esac
    printf '%s\n' "$value"
}

nhl_print_hardware_summary() {
    local host_name="$1" repo_dir="$2" profile="${NHL_GPU_PROFILE:-unknown}"
    local cpu="" total_mem="" available_mem="" intel_bus="" nvidia_bus=""
    local line="" found_gpu=0 user_name=""

    cpu=$(awk -F ': ' '/^model name/ { print $2; exit }' /proc/cpuinfo 2>/dev/null || true)
    [ -n "$cpu" ] || cpu="unknown"
    user_name=$(nhl_current_username 2>/dev/null || true)
    [ -n "$user_name" ] || user_name="unknown"
    total_mem=$(nhl_memory_mb Mem 0)
    available_mem=$(free -m 2>/dev/null | awk '$1 == "Mem:" { print $7; exit }' || true)
    if [ "${total_mem:-0}" -le 0 ]; then
        total_mem="unknown"
    fi
    [ -n "$available_mem" ] || available_mem="unknown"

    nhl_hr
    nhl_info "Install summary for host '$host_name'"
    printf '  %-17s %s\n' "User:" "$user_name"
    printf '  %-17s %s\n' "CPU:" "$cpu"
    printf '  %-17s %s MB total, %s MB available\n' "Memory:" "$total_mem" "$available_mem"

    if command -v lspci >/dev/null 2>&1; then
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            found_gpu=1
            printf '  %-17s %s\n' "GPU:" "$line"
        done < <(lspci 2>/dev/null | grep -iE '(VGA|3D|Display)' || true)
    fi
    if [ "$found_gpu" -eq 0 ]; then
        printf '  %-17s %s\n' "GPU:" "none detected (no lspci or no display device)"
    fi

    printf '  %-17s %s\n' "Driver profile:" "$profile"
    if [ "$profile" = "nvidia-laptop" ]; then
        intel_bus=$(nhl_pci_bus_id 'intel') || intel_bus=""
        nvidia_bus=$(nhl_pci_bus_id 'nvidia') || nvidia_bus=""
        printf '  %-17s Intel %s, NVIDIA %s\n' "Prime bus IDs:" \
            "${intel_bus:-unknown}" "${nvidia_bus:-unknown}"
    fi
    printf '  %-17s %s\n' "Flake target:" "$repo_dir/#$host_name"
    nhl_hr
}

nhl_ensure_build_memory() {
    local total_swap="" total_mem=""
    total_swap=$(nhl_memory_mb Swap 0)
    total_mem=$(nhl_memory_mb Mem 0)

    if [ "$total_swap" -ne 0 ] || [ "$total_mem" -ge 16000 ]; then
        return 0
    fi

    nhl_note "Low memory detected ($((total_mem / 1024))GB RAM, no swap)."
    nhl_note "Adding temporary swap so the build does not run out of memory..."
    if nhl_add_temp_swap; then
        nhl_ok "Temporary swap is active."
    else
        nhl_warn "Could not create a swapfile; the build will run with reduced concurrency."
    fi
}

nhl_add_temp_swap() {
    if command -v btrfs >/dev/null 2>&1 &&
        sudo btrfs filesystem mkswapfile --size 8G "$NHL_TEMP_SWAPFILE" 2>/dev/null &&
        sudo swapon "$NHL_TEMP_SWAPFILE" 2>/dev/null; then
        return 0
    fi

    if ! { sudo fallocate -l 4G "$NHL_TEMP_SWAPFILE" 2>/dev/null ||
        sudo dd if=/dev/zero of="$NHL_TEMP_SWAPFILE" bs=1M count=4096 2>/dev/null; }; then
        return 1
    fi
    sudo chmod 600 "$NHL_TEMP_SWAPFILE" 2>/dev/null || true
    sudo mkswap "$NHL_TEMP_SWAPFILE" >/dev/null 2>&1 || return 1
    sudo swapon "$NHL_TEMP_SWAPFILE" 2>/dev/null
}

nhl_release_temp_swap() {
    [ -e "$NHL_TEMP_SWAPFILE" ] || return 0
    if swapon --show=NAME --noheadings 2>/dev/null |
        awk -v file="$NHL_TEMP_SWAPFILE" '$1 == file { found = 1 } END { exit(found ? 0 : 1) }'; then
        nhl_note "Removing the temporary install swapfile at $NHL_TEMP_SWAPFILE."
        sudo swapoff "$NHL_TEMP_SWAPFILE" 2>/dev/null || true
        sudo rm -f -- "$NHL_TEMP_SWAPFILE" 2>/dev/null || nhl_warn "Could not delete $NHL_TEMP_SWAPFILE."
    fi
    return 0
}

nhl_get_build_flags() {
    local total_mem=""
    total_mem=$(nhl_memory_mb Mem 16000)
    if [ "$total_mem" -lt 12000 ]; then
        printf '%s\n' "--max-jobs 2 --cores 4"
    fi
}

# =============================================================================
# Post-install steps
# =============================================================================

nhl_setup_zshrc() {
    local target="$HOME/.zshrc"
    if [ -L "$target" ]; then
        nhl_note "$target is a symlink (managed by Home Manager), leaving it alone."
        return 0
    fi
    if [ -f "$target" ]; then
        cp -f -- "$target" "${target}-backup" || nhl_warn "Could not back up $target."
    fi
    if [ ! -f assets/.zshrc ]; then
        nhl_warn "assets/.zshrc is missing; skipping the shell configuration."
        return 0
    fi
    if cp -f -- assets/.zshrc "$target"; then
        nhl_ok "Installed assets/.zshrc as $target."
    else
        nhl_error "Could not copy assets/.zshrc to $target."
    fi
}

nhl_install_gtk_themes() {
    local checkout="GTK-themes-icons"
    rm -rf -- "$checkout"

    nhl_note "Cloning GTK themes and icons..."
    if ! git clone --depth 1 "$NHL_GTK_REPO" "$checkout"; then
        nhl_error "Failed to download $NHL_GTK_REPO."
        return 1
    fi

    if [ ! -f "$checkout/auto-extract.sh" ]; then
        nhl_error "$checkout/auto-extract.sh is missing; skipping the extraction."
        rm -rf -- "$checkout"
        return 1
    fi

    if (cd -- "$checkout" && bash ./auto-extract.sh); then
        nhl_ok "Extracted GTK themes and icons into ~/.icons and ~/.themes."
    else
        nhl_error "The GTK themes and icons extraction script failed."
    fi
    rm -rf -- "$checkout"
}

nhl_copy_assets() {
    local folder="" source_dir="" target_dir=""
    mkdir -p -- "$HOME/.config" || {
        nhl_error "Could not create $HOME/.config."
        return 1
    }
    for folder in gtk-3.0 Thunar xfce4; do
        source_dir="assets/$folder"
        target_dir="$HOME/.config/$folder"
        if [ ! -d "$source_dir" ]; then
            nhl_warn "$source_dir does not exist; skipping."
            continue
        fi
        if [ -d "$target_dir" ]; then
            nhl_note "Config for $folder already exists, leaving it untouched."
            continue
        fi
        if cp -r -- "$source_dir" "$HOME/.config/"; then
            nhl_ok "Copied the $folder config."
        else
            nhl_error "Failed to copy the $folder config."
        fi
    done
}

nhl_install_dotfiles() {
    local checkout="$NHL_DOTFILES_DIR"

    if [ -d "$checkout/.git" ]; then
        nhl_note "Updating the existing dotfiles checkout at $checkout..."
        if ! (
            cd -- "$checkout" && git stash >/dev/null 2>&1
            git pull --ff-only
        ); then
            nhl_warn "Could not update $checkout; continuing with the existing checkout."
        fi
    elif [ -d "$checkout" ]; then
        nhl_warn "$checkout exists but is not a git checkout; leaving it untouched."
    else
        nhl_note "Cloning the Hyprland dotfiles into $checkout..."
        if ! git clone --depth 1 "$NHL_DOTFILES_REPO" "$checkout"; then
            nhl_error "Failed to download $NHL_DOTFILES_REPO."
            return 1
        fi
    fi

    if [ ! -f "$checkout/copy.sh" ]; then
        nhl_error "$checkout/copy.sh is missing; the dotfiles were not installed."
        return 1
    fi
    if (cd -- "$checkout" && bash ./copy.sh); then
        nhl_ok "Hyprland dotfiles installed."
        return 0
    fi
    nhl_error "copy.sh failed; review its output above and re-run it manually if needed."
    return 1
}

nhl_copy_fastfetch() {
    local target_dir="$HOME/.config/fastfetch"
    if [ -f "$target_dir/nixos.png" ] || [ -f "$target_dir/images/nixos.png" ]; then
        return 0
    fi
    if [ ! -d assets/fastfetch ]; then
        return 0
    fi
    mkdir -p -- "$HOME/.config" || return 0
    if [ -d "$target_dir" ]; then
        cp -r -- assets/fastfetch/. "$target_dir"/ || nhl_warn "Could not update the fastfetch config."
    else
        cp -r -- assets/fastfetch "$HOME/.config/" || nhl_warn "Could not copy the fastfetch config."
    fi
}

nhl_mask_user_waybar() {
    if ! command -v systemctl >/dev/null 2>&1; then
        return 0
    fi
    if ! systemctl --user list-unit-files --no-pager 2>/dev/null | grep -q '^waybar\.service'; then
        nhl_info "No user waybar.service unit detected."
        return 0
    fi
    nhl_note "Found user waybar.service; masking it to avoid duplicate bars with the dotfiles."
    systemctl --user stop waybar.service >/dev/null 2>&1 || true
    systemctl --user disable waybar.service >/dev/null 2>&1 || true
    if systemctl --user mask waybar.service >/dev/null 2>&1; then
        nhl_ok "waybar.service has been masked for the user session."
    else
        nhl_warn "Could not mask waybar.service; you may get two bars."
    fi
}

nhl_post_install() {
    local repo_dir="${1:-$PWD}" user_name=""

    user_name="${USER:-$(id -un 2>/dev/null || printf 'user')}"
    # Make binaries from the new generation usable without logging out first.
    export PATH="/run/current-system/sw/bin:/nix/var/nix/profiles/system/sw/bin:/etc/profiles/per-user/$user_name/bin:$PATH"

    nhl_hr
    nhl_setup_zshrc
    nhl_hr
    nhl_install_gtk_themes || true
    nhl_hr
    nhl_copy_assets || true
    nhl_hr
    nhl_install_dotfiles || true
    nhl_copy_fastfetch || true
    nhl_mask_user_waybar
    nhl_release_temp_swap

    cd -- "$repo_dir" 2>/dev/null || true
    return 0
}

# nhl_hyprland_version -> prints the installed Hyprland version (or "unknown")
nhl_hyprland_version() {
    local output="" version=""

    if ! command -v Hyprland >/dev/null 2>&1; then
        printf '%s\n' "not found"
        return 0
    fi
    output=$(Hyprland --version 2>/dev/null || true)
    # "Tag: v0.44.1, commits: 1234" is the most precise line in the banner.
    version=$(printf '%s\n' "$output" | sed -n 's/^.*Tag:[[:space:]]*\(v[0-9][^,[:space:]]*\).*$/\1/p' | head -n 1)
    if [ -z "$version" ]; then
        # Fall back to the version in parentheses: "... dirty (0.44.1)."
        version=$(printf '%s\n' "$output" | sed -n '1s/^.*(\([0-9][0-9.]*\)).*$/\1/p' | head -n 1)
    fi
    printf '%s\n' "${version:-unknown}"
}

# nhl_enabled_drivers <host config file> -> comma separated enabled GPU modules
nhl_enabled_drivers() {
    local config_file="$1" name="" joined=""

    if [ ! -f "$config_file" ]; then
        printf '%s\n' "unknown"
        return 0
    fi
    for name in amdgpu intel nvidia nvidia-prime; do
        if [ "$(nhl_get_bool_value "$config_file" "drivers.$name.enable" || true)" != "true" ]; then
            continue
        fi
        case "$name" in
            amdgpu) name="amd" ;;
        esac
        joined="${joined:+$joined, }$name"
    done
    if [ -z "$joined" ]; then
        printf '%s\n' "none enabled (software rendering)"
        return 0
    fi
    printf '%s\n' "$joined"
}

nhl_finish() {
    local host_name="${1:-}" repo_dir="${2:-$PWD}" answer="" config_file=""

    printf '\n\n'
    if ! command -v Hyprland >/dev/null 2>&1; then
        nhl_warn "Hyprland was not found on PATH; the installation probably failed."
        nhl_warn "Check the rebuild output above and re-run the installer if needed."
        return 1
    fi

    config_file="$repo_dir/hosts/${host_name:-default}/config.nix"
    nhl_hr
    nhl_ok "Installation completed."
    printf '  %-17s %s\n' "Hyprland:" "$(nhl_hyprland_version)"
    printf '  %-17s %s\n' "Enabled drivers:" "$(nhl_enabled_drivers "$config_file")"
    nhl_hr
    nhl_note "It is highly recommended that you reboot your system now."

    if ! answer=$(nhl_read_line "Would you like to reboot now? (y/n)" "n"); then
        nhl_warn "Could not read from the terminal; reboot manually when ready."
        return 0
    fi
    case "${answer,,}" in
        y | yes)
            nhl_note "Rebooting..."
            systemctl reboot
            ;;
        *)
            nhl_note "Reboot skipped; run 'systemctl reboot' when you are ready."
            ;;
    esac
    return 0
}

# =============================================================================
# Shared install flow
# =============================================================================

# nhl_install_flow <repo dir>
nhl_install_flow() {
    local repo_dir="${1:-$PWD}" host_name="" keyboard_layout="" user_name=""

    nhl_init_ui

    nhl_require_non_root || return 1
    nhl_require_nixos || return 1
    nhl_require_command git "Example: nix-shell -p git" || return 1
    nhl_require_command lspci "Install pciutils so the GPU can be detected: nix-shell -p pciutils" || return 1
    nhl_check_go_version || return 1

    nhl_is_repo "$repo_dir" || {
        nhl_error "$repo_dir is not the NixOS-Hyprland repository."
        return 1
    }
    cd -- "$repo_dir" || {
        nhl_error "Cannot enter $repo_dir."
        return 1
    }

    nhl_hr
    nhl_note "Default options are shown in brackets []; press ENTER to accept them."
    sleep 1
    nhl_hr

    nhl_prompt host_name "Enter your new hostname:" "default" nhl_valid_hostname || return 1

    nhl_hr
    nhl_create_host "$host_name" || return 1
    nhl_detect_gpu_and_toggle "$host_name" || return 1
    nhl_hr

    nhl_prompt keyboard_layout "Enter your keyboard layout:" "us" nhl_valid_keymap || return 1
    nhl_set_string_option "./hosts/$host_name/variables.nix" keyboardLayout "$keyboard_layout" || {
        nhl_error "Could not set keyboardLayout in hosts/$host_name/variables.nix."
        return 1
    }
    nhl_ok "Keyboard layout set to $keyboard_layout."

    nhl_prompt_timezone_console "$host_name" "$keyboard_layout" || return 1
    nhl_hr

    user_name=$(nhl_current_username) || return 1
    nhl_set_string_option ./flake.nix username "$user_name" || {
        nhl_error "Could not set the user name in flake.nix."
        return 1
    }
    nhl_set_string_option ./flake.nix host "$host_name" || {
        nhl_error "Could not set the host name in flake.nix."
        return 1
    }
    nhl_ok "flake.nix configured for host '$host_name' and user '$user_name'."

    nhl_note "Generating the hardware configuration..."
    nhl_generate_hardware "$host_name" || return 1
    nhl_stage_changes "$host_name" || return 1
    nhl_hr

    nhl_print_hardware_summary "$host_name" "$repo_dir"
    nhl_ensure_build_memory
    nhl_rebuild "$host_name" "$repo_dir" || return 1
    nhl_post_install "$repo_dir"
    nhl_finish "$host_name" "$repo_dir"
}
