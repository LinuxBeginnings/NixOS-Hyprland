# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
English | [Español](./tmux.cheatsheet.es.md)

# Tmux — Summary & Cheatsheet

## 🚀 Summary of modules/home/terminals/tmux.nix

### ⌨️ What is the Tmux Prefix?

- The prefix is a special key you press before most tmux commands, so tmux can tell them apart from regular typing.
- Notation guide used below:
    - C-x = hold Control and press x (e.g., C-a means Control+a)
    - M-x = hold Alt/Meta and press x (sometimes shown as Alt+x)
    - S-x = hold Shift and press x (often implicit for uppercase letters)
- Tmux default prefix is C-b (Control+b). In this config it’s changed to C-a (Control+a), which mirrors the historical GNU Screen workflow many users prefer.

Quick examples (with prefix = C-a):

- New window: press C-a then c
- Next window: press C-a then n
- Split horizontally: press C-a then |
- Split vertically: press C-a then -
- Resize left: press C-a then C-h (hold Control and press h)

- Program
    - tmux enabled; prefix: C-a; key mode: vi; baseIndex: 1; pane-base-index: 1
        - baseIndex: window numbering starts at 1 instead of 0
        - pane-base-index: pane numbering inside a window starts at 1 instead of 0
    - Terminal overrides RGB; terminal set to "tmux-256color"; shell: zsh
    - Mouse: enabled; 12-hour clock; history-limit: 5000; renumber-windows: on

- Status/UX
    - Status bar at top; passthrough: on; confirmations reduced (kill-pane without prompt)

- Plugins
    - vim-tmux-navigator, sensible, catppuccin

---

## 🗝️ Keybindings Cheatsheet

Navigation

- Prefix h/j/k/l — select-pane Left/Down/Up/Right
- Prefix o — select next pane
- C-Tab — next-window
- C-S-Tab — previous-window
- M-Tab — new-window
- M-h/M-j/M-k/M-l — select-pane Left/Down/Up/Right (no prefix)

Splits

- Prefix | — split-window -h (cwd)
- Prefix \ — split-window -fh (cwd)
- Prefix - — split-window -v (cwd)
- Prefix \_ — split-window -fv (cwd)

Resize

- Prefix C-h/C-k/C-l — resize-pane 15 cols/rows in direction
- Prefix m — toggle zoom (resize-pane -Z)

Copy mode (vi)

- In copy mode (vi), use:
    - v — begin selection
    - C-v — toggle rectangle (block) selection
    - y — copy selection and exit copy mode

Windows

- Prefix c — new-window
- Prefix p — previous-window
- Prefix n - next-window
- M-1..M-9 — select window 1..9 (no prefix)
- Prefix t — clock-mode
- Prefix q — display-panes
- Prefix u — refresh-client

Session/Reload

- Prefix r — source-file ~/.config/tmux/tmux.conf
- Prefix x — kill-pane (no prompt)

Popups

- Prefix C-y — open lazygit in an 80% x 80% popup (current directory)
- Prefix C-n — create and switch to a new tmux session via popup prompt
- Prefix C-j — fuzzy session switcher popup (fzf over tmux sessions)
- Prefix C-r — open yazi file manager in a 90% x 90% popup (current directory)
- Prefix C-t — open a zsh shell in a 75% x 75% popup (current directory)

Notes

- Pane/Window indices start at 1.
- Terminal passthrough and RGB enabled for truecolor.
