# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# freebuff-cli -- the freebuff coding agent, always run through npx.
#
# freebuff ships to npm as a thin launcher package: index.js and launcher.js
# download the platform native binary (sha256-verified against binaryChecksums
# in its package.json) into ~/.config/manicode on first run, so there is no
# self-contained derivation to build here and no flake input to wire up.
#
# That download is a generic dynamically linked ELF (interpreter
# /lib64/ld-linux-x86-64.so.2, DT_NEEDED only glibc), so it needs
# programs.nix-ld, which every host that imports this module must enable.
# Without nix-ld, NixOS' stub-ld refuses to start it with "Could not start
# dynamically linked executable".
#
# The wrapper is named freebuff-cli and resolves the package through npx on
# purpose: a globally installed or desktop build called `freebuff` can shadow
# the CLI, while `npx freebuff` always resolves the npm CLI package.
#
# Updates -- nothing here pins a version, and freebuff itself has no --update
# flag. Two layers keep themselves current:
#   * npx re-resolves the bare `freebuff` spec against the npm `latest` tag on
#     each run and reinstalls its cached copy under ~/.npm/_npx when a newer
#     release is published.
#   * freebuff's launcher checks the registry shortly after startup, verifies
#     the platform binary's sha256 against the release's binaryChecksums, and
#     installs it when the session exits (or on the next launch).
# `freebuff-cli --update` forces both now: it drops the npx cache entry and the
# downloaded binary, then reruns the launcher, whose ensureBinaryReady()
# re-downloads the current release synchronously. --version is the one flag
# that completes that download and exits instead of starting the TUI.
#
# A short run can exit before the binary reads the terminal's OSC 11 colour
# reply, so the --update and --version paths drain it before returning.
#
# A normal launch also compares the downloaded binary's recorded version with
# the npm `latest` tag and warns when it is behind, because the launcher stages
# its own update silently and only installs it on exit. `--check` prints the
# installed and latest versions and exits without launching anything.
# `--notify` sends one desktop notification per new release, which is how the
# timer below surfaces updates on any bar or bare session.
# `--status` prints one compact JSON line a bar can poll: Noctalia's
# `tordex/stdout` widget and a Waybar custom module can both read it. The module
# deliberately writes no bar configuration, because the Noctalia TOML and the
# many Waybar layouts differ per project; bar wiring stays with each repo and
# notifications are the portable default.
#
# The registry answer is cached under $XDG_CACHE_HOME/freebuff-cli (default
# ~/.cache), so only a cache miss pays for the bounded lookup. The cache lives
# for six hours by default; set FREEBUFF_CLI_CACHE_TTL to a number of seconds
# to change that, or 0 to always ask the registry. The user timer below also
# runs a check every four hours, so the cache stays warm between launches.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.freebuff-cli;

  freebuffCli = pkgs.writeShellScriptBin "freebuff-cli" ''
                # Ensure npm/npx and the notifier are available regardless of
                # the caller's PATH. A missing notify-send is ignored later, so
                # the check never fails because of it.
                export PATH=${pkgs.lib.makeBinPath [pkgs.coreutils pkgs.libnotify pkgs.nodejs]}:$PATH
                export FREEBUFF_CLI_NOTIFY_SEND=''${FREEBUFF_CLI_NOTIFY_SEND:-${pkgs.libnotify}/bin/notify-send}

                # Compare the downloaded binary's recorded version with the npm
                # `latest` tag. A normal launch warns when the binary is behind;
                # --check prints both versions, --status prints one JSON line for a
                # bar widget, and --notify raises a desktop notification. Every
                # failure (offline, bad registry response, no metadata) is silent on
                # a normal launch because the launcher does the authoritative
                # update check itself.
                #
                # The registry answer is cached (six hours by default,
                # FREEBUFF_CLI_CACHE_TTL seconds to override, 0 to disable), so
                # only a cache miss pays for the bounded request timeout.
                #
                # The heredoc terminator must stay at column 0, hence the
                # unindented `NODE`.
                report_versions() {
                  node <<'NODE'
                  const fs = require('fs')
                  const os = require('os')
                  const https = require('https')
                  const path = require('path')
                  const { spawnSync } = require('child_process')

                  // --check reports even when nothing is installed yet; --status
                  // emits the bar-widget JSON contract; --notify keeps the
                  // portable notify-send surface quiet unless a release landed.
                  const mode = process.env.FREEBUFF_CLI_MODE || 'warn'
                  const checkMode = mode === 'check'
                  const statusMode = mode === 'status'
                  const notifyMode = mode === 'notify'

                  // Default six hours; a value of 0 disables the cache entirely.
                  const ttlEnv = process.env.FREEBUFF_CLI_CACHE_TTL
                  const ttlSeconds =
                    typeof ttlEnv === 'string' &&
                    ttlEnv.trim().length > 0 &&
                    Number.isFinite(Number(ttlEnv)) &&
                    Number(ttlEnv) >= 0
                      ? Number(ttlEnv)
                      : 6 * 60 * 60
                  const cacheTtl = ttlSeconds * 1000

                  const meta = path.join(
                    os.homedir(),
                    '.config',
                    'manicode',
                    'freebuff-metadata.json'
                  )
                  let current = null
                  try {
                    current = JSON.parse(fs.readFileSync(meta, 'utf8')).version
                  } catch (error) {}
                  if (typeof current !== 'string' || current.length === 0) current = null

                  // A normal launch stays quiet when there is nothing to compare.
                  if (mode === 'warn' && current === null) process.exit(0)

                  function newer(candidate, installed) {
                    const core = (version) => version.split('-')[0].split('.').map(Number)
                    const a = core(candidate)
                    const b = core(installed)
                    for (let i = 0; i < 3; i++) {
                      const left = a[i] || 0
                      const right = b[i] || 0
                      if (left !== right) return left > right
                    }
                    const aPre = candidate.includes('-')
                    const bPre = installed.includes('-')
                    if (aPre === bPre) return false
                    return !aPre
                  }

                  let finished = false

                  // latest === null means the registry answer is unavailable.
                  function report(latest) {
                    if (finished) return
                    finished = true

                    const known = typeof latest === 'string' && latest.length > 0
                    const updateAvailable =
                      current !== null && known && newer(latest, current)

                    if (statusMode) {
                      if (!updateAvailable) {
                        process.stdout.write('{"visible":false}\n')
                        return
                      }
                      process.stdout.write(
                        JSON.stringify({
                          visible: true,
                          glyph: 'arrow-up',
                          text: latest,
                          tips: [
                            ['Installed', current],
                            ['Latest', latest],
                            ['Update', 'freebuff-cli --update']
                          ]
                        }) + '\n'
                      )
                      return
                    }

                    if (notifyMode) {
                      if (!updateAvailable) {
                        // Back on the latest release: arm the marker again so a
                        // later release notifies immediately.
                        clearNotified()
                        return
                      }
                      // One notification per published version, no matter how
                      // often the timer runs. notify-send needs a running
                      // notification daemon; if it fails, try again next run.
                      if (readNotified() === latest) return
                      try {
                        const result = spawnSync(
                          process.env.FREEBUFF_CLI_NOTIFY_SEND || 'notify-send',
                          [
                            '--app-name=freebuff-cli',
                            '--urgency=normal',
                            '--icon=software-update-available',
                            'freebuff update available',
                            'Installed ' +
                              current +
                              ', npm latest ' +
                              latest +
                              '. Run freebuff-cli --update to refresh.'
                          ],
                          { stdio: 'ignore' }
                        )
                        if (result.status === 0) writeNotified(latest)
                      } catch (error) {}
                      return
                    }

                    if (checkMode) {
                      const installed = current === null ? 'unknown' : current
                      if (!known) {
                        process.stdout.write(
                          'freebuff-cli: installed ' + installed + ', npm latest unavailable\n'
                        )
                        return
                      }
                      process.stdout.write(
                        'freebuff-cli: installed ' + installed + ', npm latest ' + latest + '\n'
                      )
                      if (updateAvailable) {
                        process.stdout.write('An update is available: freebuff-cli --update\n')
                      }
                      return
                    }

                    if (current === null || !known) return
                    if (!newer(latest, current)) return
                    process.stderr.write(
                      'freebuff-cli: freebuff ' +
                        current +
                        ' is behind npm latest ' +
                        latest +
                        '.\n' +
                        'It updates when a session exits, or refresh now with: ' +
                        'freebuff-cli --update\n'
                    )
                  }

                  function unavailable() {
                    report(null)
                  }

                  // Cache the registry answer so a normal launch does no network I/O
                  // at all. A stale entry can only delay a warning, never invent one:
                  // it may miss a release for up to one TTL, but never names a
                  // version that does not exist.
                  const cacheDir = path.join(
                    process.env.XDG_CACHE_HOME || path.join(os.homedir(), '.cache'),
                    'freebuff-cli'
                  )
                  const cacheFile = path.join(cacheDir, 'npm-latest.json')
                  const notifiedFile = path.join(cacheDir, 'notified.json')

                  function clearNotified() {
                    try {
                      fs.unlinkSync(notifiedFile)
                    } catch (error) {}
                  }

                  function readNotified() {
                    try {
                      const data = JSON.parse(fs.readFileSync(notifiedFile, 'utf8'))
                      return typeof data.latest === 'string' ? data.latest : null
                    } catch (error) {
                      return null
                    }
                  }

                  function writeNotified(latest) {
                    try {
                      fs.mkdirSync(cacheDir, { recursive: true })
                      const tmp = notifiedFile + '.' + process.pid
                      fs.writeFileSync(tmp, JSON.stringify({ latest }) + '\n')
                      fs.renameSync(tmp, notifiedFile)
                    } catch (error) {
                      // A failed marker only risks one repeat notification.
                    }
                  }

                  function readCache() {
                    if (cacheTtl <= 0) return null
                    try {
                      const data = JSON.parse(fs.readFileSync(cacheFile, 'utf8'))
                      if (typeof data.latest !== 'string' || data.latest.length === 0) return null
                      if (typeof data.checkedAt !== 'number') return null
                      if (Date.now() - data.checkedAt > cacheTtl) return null
                      return data.latest
                    } catch (error) {
                      return null
                    }
                  }

                  function writeCache(latest) {
                    if (cacheTtl <= 0) return
                    try {
                      fs.mkdirSync(cacheDir, { recursive: true })
                      const tmp = cacheFile + '.' + process.pid
                      fs.writeFileSync(
                        tmp,
                        JSON.stringify({ latest, checkedAt: Date.now() }) + '\n'
                      )
                      fs.renameSync(tmp, cacheFile)
                    } catch (error) {
                      // An unwritable cache only costs a future lookup; it must
                      // never break the launch.
                    }
                  }

                  const cached = readCache()
                  if (cached !== null) {
                    report(cached)
                  } else {
                    const req = https.get(
                      'https://registry.npmjs.org/freebuff/latest',
                      { headers: { accept: 'application/json' } },
                      (res) => {
                        if (res.statusCode !== 200) {
                          res.resume()
                          unavailable()
                          return
                        }
                        let body = ""
                        res.setEncoding('utf8')
                        res.on('data', (chunk) => {
                          body += chunk
                        })
                        res.on('end', () => {
                          let latest = null
                          try {
                            latest = JSON.parse(body).version
                          } catch (error) {
                            unavailable()
                            return
                          }
                          if (typeof latest !== 'string' || latest.length === 0) {
                            unavailable()
                            return
                          }
                          writeCache(latest)
                          report(latest)
                        })
                      }
                    )
                    req.setTimeout(1000, () => {
                      req.destroy()
                      unavailable()
                    })
                    req.on('error', unavailable)
                  }
    NODE
                }

                # freebuff's native binary asks the terminal for its background
                # colour (OSC 11). A short run can exit before reading the answer,
                # leaving bytes like "11;rgb:..." for the caller's shell to print.
                # Read and discard whatever reply is still queued, then restore
                # the terminal settings exactly as they were.
                drain_terminal_reply() {
                  [ -t 0 ] || return 0
                  local saved
                  saved=$(stty -g 2>/dev/null) || return 0
                  stty -icanon min 0 time 2 2>/dev/null || return 0
                  dd bs=256 count=1 of=/dev/null 2>/dev/null || true
                  stty "$saved" 2>/dev/null || true
                }

                # None of --check, --status or --notify needs nix-ld or npx: read
                # the metadata and the cached registry answer, then exit.
                case "$1" in
                  --check)
                    FREEBUFF_CLI_MODE=check report_versions
                    exit $?
                    ;;
                  --status)
                    FREEBUFF_CLI_MODE=status report_versions
                    exit $?
                    ;;
                  --notify)
                    FREEBUFF_CLI_MODE=notify report_versions
                    exit $?
                    ;;
                esac

                # Fail fast when the system cannot start foreign ELF binaries.
                #
                # NixOS points /lib64/ld-linux-x86-64.so.2 at stub-ld, which refuses to
                # start them, so the binary this package downloads would otherwise die
                # with "Could not start dynamically linked executable". programs.nix-ld
                # (configuration.nix) points that path at nix-ld instead and links the
                # real loader into the system profile.
                #
                # Test the loader file rather than `command -v nix-ld`: the nix-ld
                # module puts only a buildEnv of libraries in systemPackages, so there is
                # no nix-ld binary on PATH to find.
                if [ ! -x /run/current-system/sw/share/nix-ld/lib/ld.so ]; then
                  printf '%s\n' \
                    "freebuff-cli: nix-ld is not enabled on this system." \
                    "The freebuff binary is a generic dynamically linked executable," \
                    "and NixOS' stub-ld refuses to start those." \
                    "" \
                    "Enable it in configuration.nix and rebuild:" \
                    "  programs.nix-ld.enable = true;" \
                    "  sudo nixos-rebuild switch --flake ." >&2
                  exit 1
                fi

                # Force both update layers immediately instead of waiting for npx's
                # registry check and the launcher's deferred install.
                if [ "$1" = "--update" ]; then
                  printf '%s\n' \
                    "freebuff-cli: refreshing the npx wrapper and the downloaded binary..." >&2

                  # npx keys its cache by the spec string, so a stale copy would
                  # otherwise be reused. Drop every cached copy of this package (other
                  # npx packages in the same cache are untouched).
                  for cached in "$HOME"/.npm/_npx/*/node_modules/freebuff; do
                    [ -d "$cached" ] || continue
                    rm -rf "$cached"
                    rm -f "$(dirname "$cached")/.bin/freebuff"
                  done

                  # Without metadata the launcher cannot consider the binary current, so
                  # ensureBinaryReady() downloads the latest release before the first
                  # spawn. Credentials and history in the same directory are preserved.
                  rm -f "$HOME/.config/manicode/freebuff" \
                    "$HOME/.config/manicode/freebuff-metadata.json"

                  # Reinstalls the wrapper (resolving `latest` again) and lets the
                  # launcher download the matching binary; --version prints it and exits.
                  npx --yes --prefer-online freebuff --version
                  status=$?
                  drain_terminal_reply
                  exit "$status"
                fi

                # --version/--help are answered by the installed binary and must stay
                # quiet, so only a normal launch pays for the staleness check.
                case "$1" in
                  -v | --version | -h | --help) ;;
                  *) report_versions ;;
                esac

                # --version and --help print and exit before the binary reads the terminal's
                # OSC 11 reply, so it cannot be exec'd if the wrapper is to clean up
                # after it. Capture the status, drain, then exit the same way.
                case "$1" in
                  -v | --version | -h | --help)
                    npx --yes freebuff "$@"
                    status=$?
                    drain_terminal_reply
                    exit "$status"
                    ;;
                esac

                # `--yes` skips npx's interactive "Ok to proceed?" install prompt so the
                # first run also works from scripts and non-interactive shells.
                exec npx --yes freebuff "$@"
  '';
in {
  options.programs.freebuff-cli = {
    enable = lib.mkEnableOption "the freebuff coding agent wrapper (resolved through npx)";

    notifications.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Send a desktop notification when a newer npm release is published.
        This is the portable update surface: it writes no bar configuration and
        behaves the same under Noctalia, Waybar or a bare session. No Waybar
        module is generated because its config formats differ per project; call
        `freebuff-cli --status` from a custom module if a bar indicator is
        wanted instead, or in addition.
      '';
    };

    checkForUpdates = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Run the update check from a systemd user timer.";
      };

      interval = lib.mkOption {
        type = lib.types.str;
        default = "4h";
        description = ''
          How often the timer checks for a newer release. Keep this shorter than
          FREEBUFF_CLI_CACHE_TTL so a missed run cannot leave the cache stale.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [freebuffCli];

    # A four-hour check is shorter than the six-hour cache TTL on purpose: even
    # if one run is missed (suspend, offline), the next launch still finds a
    # fresh entry.
    systemd.user.services.freebuff-cli-check = lib.mkIf cfg.checkForUpdates.enable {
      Unit.Description = "Check freebuff-cli for a newer npm release";
      Service = {
        Type = "oneshot";
        ExecStart =
          "${freebuffCli}/bin/freebuff-cli "
          + (
            if cfg.notifications.enable
            then "--notify"
            else "--check"
          );
        StandardOutput = "null";
        StandardError = "null";
      };
    };

    systemd.user.timers.freebuff-cli-check = lib.mkIf cfg.checkForUpdates.enable {
      Unit.Description = "Check freebuff-cli for a newer npm release every ${cfg.checkForUpdates.interval}";
      Timer = {
        OnStartupSec = "2min";
        OnUnitActiveSec = cfg.checkForUpdates.interval;
        Unit = "freebuff-cli-check.service";
      };
      Install.WantedBy = ["timers.target"];
    };
  };
}
