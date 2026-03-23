#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════╗
# ║          Mistletoe Shell — Arch Linux Installer          ║
# ║  Installs deps via pacman + deploys to ~/.config         ║
# ╚══════════════════════════════════════════════════════════╝
set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────────

PKGS=(
  quickshell
  qt6-wayland
  qt6-declarative
  qt6-quickcontrols2
  qt6-graphicaleffects
  qt6-tools
  wl-clipboard
  brightnessctl
  wlsunset
  ddcutil
  power-profiles-daemon
  cava
  cliphist
  gum
  git
)

# Resolve the real script directory regardless of how it was invoked
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Quickshell's native config location — QML entry point lands directly here
INSTALL_PREFIX="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
QML_ENTRY="${INSTALL_PREFIX}/shell.qml"

# Launcher goes on the standard XDG bin path
BIN_DIR="${HOME}/.local/bin"
LAUNCHER_PATH="${BIN_DIR}/mistletoe-shell"

# Git sync settings — override via env vars if needed
REPO_WORKDIR="${XDG_DATA_HOME:-$HOME/.local/share}/mistletoe"
MISTLETOE_REPO="${MISTLETOE_REPO:-me-osano/mistletoe-shell}"
MISTLETOE_REF="${MISTLETOE_REF:-master}"

# Will be updated to $REPO_WORKDIR after sync_repo_source runs
SOURCE_REPO_DIR="$SRC_DIR"

# ── Flags ──────────────────────────────────────────────────────────────────────

NONINTERACTIVE=0
[[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]] && NONINTERACTIVE=1

GUM_AVAILABLE=0
command -v gum >/dev/null 2>&1 && GUM_AVAILABLE=1

# ── Colours (fallback when gum is absent) ─────────────────────────────────────

_c() {
  case "$1" in
    red)     printf '\033[1;31m' ;;
    green)   printf '\033[1;32m' ;;
    yellow)  printf '\033[1;33m' ;;
    blue)    printf '\033[1;34m' ;;
    magenta) printf '\033[1;35m' ;;
    cyan)    printf '\033[1;36m' ;;
    dim)     printf '\033[2m'    ;;
    bold)    printf '\033[1m'    ;;
    reset)   printf '\033[0m'    ;;
  esac
}

# ── Logging ────────────────────────────────────────────────────────────────────

info() {
  if [[ $GUM_AVAILABLE -eq 1 ]]; then gum log --level info  "$*"
  else printf "%s[INFO]%s  %s\n" "$(_c blue)"    "$(_c reset)" "$*"; fi
}
success() {
  if [[ $GUM_AVAILABLE -eq 1 ]]; then gum log --level info "✓ $*"
  else printf "%s[ OK ]%s  %s\n" "$(_c green)"   "$(_c reset)" "$*"; fi
}
warn() {
  if [[ $GUM_AVAILABLE -eq 1 ]]; then gum log --level warn  "$*"
  else printf "%s[WARN]%s  %s\n" "$(_c yellow)"  "$(_c reset)" "$*"; fi
}
err() {
  if [[ $GUM_AVAILABLE -eq 1 ]]; then gum log --level error "$*"
  else printf "%s[ERR ]%s  %s\n" "$(_c red)"     "$(_c reset)" "$*" >&2; fi
}

divider() {
  if [[ $GUM_AVAILABLE -eq 1 ]]; then
    gum style --faint "$(printf '─%.0s' {1..62})"
  else
    printf "%s%s%s\n" "$(_c dim)" "$(printf '─%.0s' {1..62})" "$(_c reset)"
  fi
}

section() {
  printf '\n'
  if [[ $GUM_AVAILABLE -eq 1 ]]; then
    gum style --bold --foreground="#cba6f7" --border-foreground="#6c7086" "  ◆  $1"
  else
    printf "%s  ◆  %s%s\n" "$(_c magenta)" "$1" "$(_c reset)"
  fi
  divider
}

# ── Spinner ────────────────────────────────────────────────────────────────────

spinner_run() {
  # Usage: spinner_run "Message" cmd [args...]
  # Command is passed as real arguments — no sh -c quoting hazards.
  # Exit code is captured and propagated correctly under set -e.
  local msg="$1"; shift
  if [[ $GUM_AVAILABLE -eq 1 ]]; then
    gum spin --title "$msg" --spinner dot -- "$@"
    return $?
  fi
  local exit_code=0
  ( set +e; "$@"; exit $? ) &
  local pid=$! spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r%s %s" "${spinstr:i++%${#spinstr}:1}" "$msg"
    sleep 0.08
  done
  printf "\r\033[K"
  wait "$pid" || exit_code=$?
  return $exit_code
}

# ── Confirm ────────────────────────────────────────────────────────────────────

confirm() {
  local prompt="$1"
  [[ $NONINTERACTIVE -eq 1 ]] && return 0
  if [[ $GUM_AVAILABLE -eq 1 ]]; then
    gum confirm "$prompt"; return $?
  fi
  printf "%s%s%s [y/N] " "$(_c bold)" "$prompt" "$(_c reset)"
  local ans; read -r ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

# ── Guards ─────────────────────────────────────────────────────────────────────

if ! command -v pacman >/dev/null 2>&1; then
  err "pacman not found — this script targets Arch Linux. Aborting."
  exit 1
fi

# Robust self-clobber check: resolve real parent + basename so the comparison
# works even when either path doesn't exist yet.
_realish() {
  local p="$1"
  local parent; parent="$(cd "$(dirname "$p")" 2>/dev/null && pwd)" || parent="$(dirname "$p")"
  printf '%s/%s' "$parent" "$(basename "$p")"
}

SRC_REAL="$(_realish "$SRC_DIR")"
DEST_REAL="$(_realish "$INSTALL_PREFIX")"
if [[ "$SRC_REAL" == "$DEST_REAL" ]]; then
  err "Script is running from the install prefix ($INSTALL_PREFIX)."
  err "Run it from the cloned repository directory instead."
  exit 1
fi

SUDO=
[[ "$EUID" -ne 0 ]] && SUDO=sudo

# ── Banner ─────────────────────────────────────────────────────────────────────

banner() {
  printf '\n'
  if [[ -f "$SRC_DIR/Assets/logo.txt" ]]; then
    if [[ $GUM_AVAILABLE -eq 1 ]]; then
      gum style --foreground="#cba6f7" < "$SRC_DIR/Assets/logo.txt"
    else
      printf "%s" "$(_c magenta)"; cat "$SRC_DIR/Assets/logo.txt"; printf "%s" "$(_c reset)"
    fi
    printf '\n'
  fi
  if [[ $GUM_AVAILABLE -eq 1 ]]; then
    gum style \
      --bold --foreground="#cdd6f4" \
      --border double --border-foreground="#cba6f7" \
      --padding "0 2" --margin "0 1" \
      "Mistletoe Shell  ·  Arch Linux Installer"
  else
    printf "%s  ┌──────────────────────────────────────────────┐\n" "$(_c cyan)"
    printf   "  │   Mistletoe Shell  ·  Arch Linux Installer   │\n"
    printf   "  └──────────────────────────────────────────────┘%s\n\n" "$(_c reset)"
  fi
}

# ── Source sync ────────────────────────────────────────────────────────────────

sync_repo_source() {
  section "Source sync"
  info "Remote   : https://github.com/${MISTLETOE_REPO}.git"
  info "Ref      : ${MISTLETOE_REF}"
  info "Workdir  : ${REPO_WORKDIR}"

  if ! command -v git >/dev/null 2>&1; then
    info "git not found — installing it first…"
    spinner_run "Installing git…" $SUDO pacman -S --noconfirm --needed git
  fi

  mkdir -p "$(dirname "$REPO_WORKDIR")"

  if [[ -d "$REPO_WORKDIR/.git" ]]; then
    info "Updating existing local clone…"
    spinner_run "Fetching updates…" git -C "$REPO_WORKDIR" fetch --prune origin
  else
    info "Cloning repository…"
    rm -rf "$REPO_WORKDIR"
    spinner_run "Cloning…" git clone "https://github.com/${MISTLETOE_REPO}.git" "$REPO_WORKDIR"
  fi

  # Prefer a remote tracking branch; fall back to a tag or commit hash
  if git -C "$REPO_WORKDIR" rev-parse --verify "origin/${MISTLETOE_REF}" >/dev/null 2>&1; then
    spinner_run "Checking out ${MISTLETOE_REF}…" \
      git -C "$REPO_WORKDIR" checkout -B "$MISTLETOE_REF" "origin/$MISTLETOE_REF"
  else
    spinner_run "Checking out ${MISTLETOE_REF}…" \
      git -C "$REPO_WORKDIR" checkout -f "$MISTLETOE_REF"
  fi

  SOURCE_REPO_DIR="$REPO_WORKDIR"
  success "Source ready: $SOURCE_REPO_DIR"
}

# ── Package resolution ─────────────────────────────────────────────────────────

available_pkgs=()
missing_pkgs=()

resolve_packages() {
  # Single pacman -Si call for all packages; parse error lines to classify.
  available_pkgs=()
  missing_pkgs=()
  local output
  output=$(pacman -Si "${PKGS[@]}" 2>&1 || true)
  for pkg in "${PKGS[@]}"; do
    if printf '%s\n' "$output" | grep -q "^error: package '$pkg' was not found"; then
      missing_pkgs+=("$pkg")
    else
      available_pkgs+=("$pkg")
    fi
  done
}

print_package_summary() {
  section "Packages"
  if [[ ${#available_pkgs[@]} -gt 0 ]]; then
    if [[ $GUM_AVAILABLE -eq 1 ]]; then
      printf '%s\n' "${available_pkgs[@]}" | gum style --foreground="#a6e3a1" --padding "0 2"
    else
      for p in "${available_pkgs[@]}"; do
        printf "  %s●%s  %s\n" "$(_c green)" "$(_c reset)" "$p"
      done
    fi
  fi
  if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
    printf '\n'
    warn "Not found in official repos (AUR / manual install required):"
    if [[ $GUM_AVAILABLE -eq 1 ]]; then
      printf '%s\n' "${missing_pkgs[@]}" | gum style --foreground="#f38ba8" --padding "0 2"
    else
      for p in "${missing_pkgs[@]}"; do
        printf "  %s○%s  %s\n" "$(_c red)" "$(_c reset)" "$p"
      done
    fi
    printf '\n'
    warn "This script does not use the AUR. Install missing packages manually if needed."
  fi
}

# ── Pacman install ─────────────────────────────────────────────────────────────

run_pacman_install() {
  spinner_run "Installing packages…" \
    $SUDO pacman -Syu --noconfirm --needed "$@"
}

# ── Launcher ───────────────────────────────────────────────────────────────────

create_launcher() {
  mkdir -p "$BIN_DIR"
  tee "$LAUNCHER_PATH" > /dev/null <<EOF
#!/usr/bin/env bash
exec quickshell "${QML_ENTRY}" "\$@"
EOF
  chmod +x "$LAUNCHER_PATH"
  success "Launcher created at $LAUNCHER_PATH"

  if [[ ":${PATH}:" != *":${BIN_DIR}:"* ]]; then
    warn "'$BIN_DIR' is not in your PATH."
    printf '\n'
    if [[ $GUM_AVAILABLE -eq 1 ]]; then
      gum style --faint "  Add to your shell config:  export PATH=\"${BIN_DIR}:\$PATH\""
    else
      printf "%s  Add to your shell config:  export PATH=\"%s:\$PATH\"%s\n" \
        "$(_c dim)" "$BIN_DIR" "$(_c reset)"
    fi
    printf '\n'
  fi
}

create_placeholder_launcher() {
  # Created when quickshell isn't in PATH yet so the user gets a clear error
  # message after installing quickshell, rather than a missing-command failure.
  mkdir -p "$BIN_DIR"
  cat > "$LAUNCHER_PATH" <<'LAUNCHEREOF'
#!/usr/bin/env bash
printf 'Error: quickshell not found in PATH. Install quickshell to run Mistletoe Shell.\n' >&2
exit 1
LAUNCHEREOF
  chmod +x "$LAUNCHER_PATH"
  warn "Placeholder launcher created at $LAUNCHER_PATH"
  warn "Re-run this script once quickshell is installed to replace it."
}

# ══════════════════════════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════════════════════════

banner
sync_repo_source

section "Environment"
info "Script dir : $SRC_DIR"
info "Source dir : $SOURCE_REPO_DIR"
info "Config dir : $INSTALL_PREFIX"
info "Launcher   : $LAUNCHER_PATH"
info "QML entry  : $QML_ENTRY"

if [[ ! -f "$SOURCE_REPO_DIR/quickshell/shell.qml" ]]; then
  err "Expected entrypoint not found: $SOURCE_REPO_DIR/quickshell/shell.qml"
  exit 1
fi

section "Resolving packages"
info "Querying pacman for package availability…"
resolve_packages
print_package_summary

# ── Step 1: Install packages ──────────────────────────────────────────────────

section "Step 1 — Install packages"

if [[ ${#available_pkgs[@]} -gt 0 ]]; then
  if confirm "Install ${#available_pkgs[@]} package(s) via pacman?"; then
    run_pacman_install "${available_pkgs[@]}" \
      || { err "pacman install failed."; exit 1; }
    success "All available packages installed"
  else
    warn "Skipping pacman install."
  fi
else
  warn "No requested packages are available in the official repositories — nothing to install."
fi

# ── Step 2: Deploy quickshell config ─────────────────────────────────────────

section "Step 2 — Deploy to $INSTALL_PREFIX"

if confirm "Deploy quickshell config to $INSTALL_PREFIX and create launcher?"; then
  # Back up any existing config before overwriting
  if [[ -d "$INSTALL_PREFIX" ]] && [[ -n "$(ls -A "$INSTALL_PREFIX" 2>/dev/null)" ]]; then
    backup_path="${INSTALL_PREFIX}.bak.$(date +%Y%m%d-%H%M%S)"
    info "Existing config found — backing up to: $backup_path"
    mv "$INSTALL_PREFIX" "$backup_path"
  fi

  mkdir -p "$INSTALL_PREFIX"
  spinner_run "Copying quickshell config…" \
    cp -a "$SOURCE_REPO_DIR/quickshell/." "$INSTALL_PREFIX/"

  if [[ -f "$SOURCE_REPO_DIR/VERSION" ]]; then
    cp -a "$SOURCE_REPO_DIR/VERSION" "$INSTALL_PREFIX/VERSION"
  else
    warn "VERSION file not found in source repo; installed version may show as Unknown."
  fi

  success "Config deployed to $INSTALL_PREFIX"

  if command -v quickshell >/dev/null 2>&1; then
    create_launcher
  else
    warn "'quickshell' not found in PATH."
    create_placeholder_launcher
    warn "Once quickshell is installed, run manually:"
    warn "  quickshell \"$QML_ENTRY\""
  fi
else
  info "Skipping deployment. Run in-place with:"
  info "  quickshell \"$SOURCE_REPO_DIR/quickshell/shell.qml\""
fi

# ── Done ──────────────────────────────────────────────────────────────────────

printf '\n'
if [[ $GUM_AVAILABLE -eq 1 ]]; then
  gum style \
    --bold --foreground="#a6e3a1" \
    --border normal --border-foreground="#a6e3a1" \
    --padding "0 2" --margin "0 1" \
    "✓  All done. Mistletoe Shell is ready."
else
  printf "%s  ✓  All done. Mistletoe Shell is ready.%s\n" "$(_c green)" "$(_c reset)"
fi

cat <<EOF

$(printf '%s' "$(_c dim)")Quick reference:
  Run in-place    →  quickshell "$SOURCE_REPO_DIR/quickshell/shell.qml"
  Deployed config →  $INSTALL_PREFIX
  Launcher        →  $LAUNCHER_PATH
  Non-interactive →  ./setup.sh --yes
$(printf '%s' "$(_c reset)")
EOF

exit 0