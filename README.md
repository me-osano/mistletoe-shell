# Mistletoe Shell

A beautiful, minimal Wayland shell built on [Quickshell](https://quickshell.outfoxxed.me/) (Qt/QML).

```
████        ███╗█████████╗█████████╗█████████╗███╗      █████████╗█████████╗█████████╗█████████╗
█████     █████║   ███╔══╝███╔═════╝   ███╔══╝███║      ███╔═════╝   ███╔══╝███╔══███║███╔═════╝
██████   ██████║   ███║   ███║         ███║   ███║      ███║         ███║   ███║  ███║███║
███║███ ███║███║   ███║   █████████╗   ███║   ███║      █████████╗   ███║   ███║  ███║█████████╗
███║ █████║ ███║   ███║         ███║   ███║   ███║      ███╔═════╝   ███║   ███║  ███║███╔═════╝
███║  ███║  ███║   ███║         ███║   ███║   ███║      ███║         ███║   ███║  ███║███║
███║  ╚══╝  ███║█████████╗█████████║   ███║   █████████╗█████████╗   ███║   █████████║█████████╗
╚══╝        ╚══╝╚════════╝╚════════╝   ╚══╝   ╚════════╝╚════════╝   ╚══╝   ╚════════╝╚════════╝
```

## ✨ Features

- 🪟 Native support for Niri, Hyprland, Sway, Scroll, Labwc, and MangoWC
- 🎨 Extensive theming and wallpaper-driven color generation
- 🔔 Notifications with history + Do Not Disturb
- 🧩 Desktop widgets, lock screen, and OSD components
- 🖥️ Multi-monitor aware UI

## 📁 Project Layout

- `quickshell/` — main shell QML source and modules
- `bin/` — helper/update scripts
- `Assets/` — logos, defaults, templates, and static resources
- `Config/` — app/config templates
- `setup.sh` — Arch-focused installer/bootstrap script

## 📋 Requirements

- Arch Linux (or Arch-based distro with `pacman`)
- Wayland compositor (Niri, Hyprland, Sway, Labwc, MangoWC recommended)
- Quickshell

## 🧱 Prerequisites

- `Arch Linux`: Base operating system and package ecosystem used by Mistletoe scripts
- `Niri`: Wayland compositor/window manager targeted by default workflow and keybindings.
- `btrfs`: Filesystem used for snapshot-capable system state management.
- `snapper`: Snapshot manager (commonly paired with `btrfs`) for creating/restoring rollback points.
- `limine`: Bootloader integrated with snapshot/rollback boot entries.

Required for the default workflow: `Arch Linux`, `Niri`, `Quickshell`.

Optional (snapshot/rollback stack): `btrfs`, `snapper`, `limine`.

## 🚀 Quick Start (Arch)

```bash
git clone https://github.com/me-osano/mistletoe-shell.git
cd mistletoe-shell
chmod +x setup.sh
./setup.sh
```

Non-interactive mode:

```bash
./setup.sh --yes
```

## 🛠️ What `setup.sh` does

1. Syncs source repo to `${XDG_DATA_HOME:-$HOME/.local/share}/mistletoe`
2. Installs available dependencies from official repos via `pacman`
3. Deploys shell config to `${XDG_CONFIG_HOME:-$HOME/.config}/quickshell`
4. Creates launcher at `~/.local/bin/mistletoe-shell`

If `quickshell` is not yet in `PATH`, a placeholder launcher is created and a follow-up hint is shown.

## ⚙️ Installer Environment Variables

- `MISTLETOE_REPO` — repo slug to clone (default: `me-osano/mistletoe-shell`)
- `MISTLETOE_REF` — branch/tag/commit to checkout (default: `master`)
- `XDG_DATA_HOME` — controls repo sync location
- `XDG_CONFIG_HOME` — controls deployed quickshell config location

Example:

```bash
MISTLETOE_REPO=me-osano/mistletoe-shell MISTLETOE_REF=main ./setup.sh
```

## ▶️ Running Manually

Run directly from source:

```bash
quickshell quickshell/shell.qml
```

Run deployed config:

```bash
quickshell "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/shell.qml"
```

## 📄 License

MIT License — see [LICENSE](./LICENSE).
