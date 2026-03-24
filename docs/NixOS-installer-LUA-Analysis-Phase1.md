# 🧭 NixOS Hyprland Installer → Lua Migration Analysis (Phase 1)
<span style="color:#7dd3fc">Focus: identify installer steps that **write Hyprland configs** or invoke writers (Hyprland‑Dots).</span>

---

## 📌 Table of Contents
- [🎯 Scope & Assumptions](#-scope--assumptions)
- [🧩 Hyprland Config Entry Points](#-hyprland-config-entry-points)
- [✍️ Direct Hyprland Config Writers (in this repo)](#️-direct-hyprland-config-writers-in-this-repo)
- [🧪 Indirect Writers via Hyprland‑Dots](#-indirect-writers-via-hyprlanddots)
- [🧰 Other File Writers (non‑Hyprland)](#-other-file-writers-nonhyprland)
- [📟 Runtime‑Only Files (no file writes)](#-runtime-only-files-no-file-writes)
- [📝 Notes / Follow‑ups](#-notes--follow-ups)

---

## 🎯 Scope & Assumptions
<span style="color:#fbbf24">Scope:</span> this repo is a **NixOS installer + flake**, not the Hyprland dotfiles themselves.

<span style="color:#a3e635">Out of scope:</span> the new Lua syntax.

---

## 🧩 Hyprland Config Entry Points
The README explicitly states this repo **does not contain Hyprland config files**.

Hyprland configs are installed via **Hyprland‑Dots**:
- `install.sh` / `auto-install.sh` clone `Hyprland-Dots` and run `copy.sh`.

---

## ✍️ Direct Hyprland Config Writers (in this repo)
No direct writes to `~/.config/hypr/*.conf` inside this repo.

---

## 🧪 Indirect Writers via Hyprland‑Dots
### 🧩 Hyprland dotfiles installation
- `install.sh`
  - **Clones/Pulls:** `https://github.com/LinuxBeginnings/Hyprland-Dots`
  - **Runs:** `Hyprland-Dots/copy.sh`

- `auto-install.sh`
  - **Clones/Pulls:** `https://github.com/LinuxBeginnings/Hyprland-Dots`
  - **Runs:** `Hyprland-Dots/copy.sh`

➡️ **Lua migration impact:** Hyprland‑Dots is the actual writer of Hyprland configs.

---

## 🧰 Other File Writers (non‑Hyprland)
These scripts write files or modify repo/system state:
- `auto-install.sh`
  - **Modifies:** `flake.nix` (updates `host` via `sed -i`)
  - Copies GTK/Thunar/XFCE configs into `~/.config/`
- `install.sh`
  - Copies GTK/Thunar/XFCE configs into `~/.config/`
- `scripts/lib/install-common.sh`
  - Shared helper logic (file writes / installs)

---

## 📟 Runtime‑Only Files (no file writes)
None detected in this repo’s `.sh` scripts (all are file writers).

---

## 📝 Notes / Follow‑ups
- Nix modules in `modules/` mainly define packages/options; they do **not** ship Hyprland config files.
- For Lua migration, the actionable config writers remain in **Hyprland‑Dots**.
