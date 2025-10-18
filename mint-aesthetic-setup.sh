#!/usr/bin/env bash
set -euo pipefail

# Almost-exact aesthetic setup for Linux Mint Cinnamon
# Reviewed and lightly cleaned (deduplicated helper functions, added root check,
# small comments). Behaviour preserved; network downloads remain best-effort.

# ----------------
# Variables you can adjust
# ----------------

# shellcheck disable=SC2034
# Names / themes (must exist or you must install them)
CINNAMON_THEME="Faded-Dream"           # example from Spices theme pages
# shellcheck disable=SC2034
GTK_THEME="Arc-Darker"
# shellcheck disable=SC2034
ICON_THEME="Papirus-Dark"
# shellcheck disable=SC2034
CURSOR_THEME="DMZ-White"

FONT_UI="Roboto 11"
# shellcheck disable=SC2034
FONT_MONOSPACE="Fira Code 12"

WALLPAPER_URL="https://picsum.photos/1920/1080?grayscale"   # replace with actual wallpaper URL you like
# shellcheck disable=SC2034
# By default place wallpapers in the target user's local backgrounds (safer than /usr/share)
WALLPAPER_DEST="%USER_HOME%/.local/share/backgrounds/custom-aesthetic.jpg"

# Plank theming
PLANK_THEME_NAME="mcOS-Monterey-BlackLight"  # example name used in one of the tutorial transcripts :contentReference[oaicite:4]{index=4}
# shellcheck disable=SC2034

# Packages to install
EXTRA_PKGS=(plank neofetch variety \
            papirus-icon-theme arc-theme \
            cinnamon-spices-extensions \
            nemo-fileroller nemo-image-converter \
            conky)

# Resource URLs (from your screenshot). The script will try a best-effort download
# and extraction; if a site requires manual interaction the script will print instructions.
THEME_URLS=(
  "https://www.gnome-look.org/p/1715554"
  "https://www.gnome-look.org/p/1681313"
  "https://www.gnome-look.org/p/1403328"
)
ICON_URLS=(
  "https://www.gnome-look.org/p/1937741"
  "https://www.gnome-look.org/p/1961046"
  "https://www.gnome-look.org/p/1296407"
)
ULAUNCHER_URLS=(
  "https://github.com/catppuccin/ulauncher"
  "https://github.com/SylEleuth/ulauncher-gruvbox"
)
FONT_URLS=(
  "https://fonts.google.com/specimen/Bitcount+Single+Ink?selection.family=Bitcount+Single+Ink:wght@100..900"
  "https://www.dafont.com/nasalization.font"
)

# Applets / panel config (names as they appear in Cinnamon settings)
APPLETS_TO_ENABLE=(
  "CPU Temperature"
  "System Monitor"
  "Network"
  "Calendar"
  "Notifications"
  "Sound"        # etc — match names exactly
  "User Applet"
  "Menu (Cinnamenu)"  # optional alternative menu
)
# shellcheck disable=SC2034

PANEL_HEIGHT=30      # px
# shellcheck disable=SC2034
PANEL_AUTOHIDE="false"  # "true" or "false"
# shellcheck disable=SC2034
PANEL_POSITION="top"    # "top" or "bottom" or "left" / "right"

# (intentional config variables above are suppressed via disable)

# ----------------
# Helper routines
# ----------------
log() { echo -e "\n==> $*"; }

# Determine target user (the desktop user). If the script is run with sudo,
# SUDO_USER will be set. If not, fall back to the current user.
determine_target_user() {
  if [ "${EUID-}" -eq 0 ] && [ -n "${SUDO_USER-}" ]; then
    TARGET_USER="$SUDO_USER"
  else
    TARGET_USER="$(id -un)"
  fi
  TARGET_HOME="$(eval echo ~"$TARGET_USER")"
  TARGET_UID="$(id -u "$TARGET_USER")"
  # replace placeholder in wallpaper path
  WALLPAPER_DEST="${WALLPAPER_DEST//%USER_HOME%/$TARGET_HOME}"
}

# Run a command as the target desktop user with DBUS session available when possible.
run_as_user() {
  # Usage: run_as_user <command> [args...]
  if [ "${EUID-}" -eq 0 ] && [ -n "${TARGET_USER-}" ] && [ "$TARGET_UID" != "0" ]; then
    # Try to use the user's DBUS session bus if available
    if [ -S "/run/user/$TARGET_UID/bus" ]; then
      sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$TARGET_UID/bus" DISPLAY=:0 "$@"
    else
      # Fall back to running without DBUS; some gsettings may fail in this case
      sudo -u "$TARGET_USER" "$@"
    fi
  else
    # Already running as that user
    "$@"
  fi
}

# Install user fonts (Roboto + Fira Code) into the target user's local fonts dir
install_user_fonts() {
  local fonts_dir="$TARGET_HOME/.local/share/fonts"
  mkdir -p "$fonts_dir"
  log "Installing user fonts to $fonts_dir"

  # Roboto (regular and medium) from googlefonts repo
  if [ ! -f "$fonts_dir/Roboto-Regular.ttf" ]; then
    if command -v wget >/dev/null 2>&1; then
      sudo -u "$TARGET_USER" wget -q -O "$fonts_dir/Roboto-Regular.ttf" \
        "https://github.com/google/fonts/raw/main/apache/roboto/Roboto-Regular.ttf" || true
      sudo -u "$TARGET_USER" wget -q -O "$fonts_dir/Roboto-Medium.ttf" \
        "https://github.com/google/fonts/raw/main/apache/roboto/Roboto-Medium.ttf" || true
    fi
  fi

  # Fira Code
  if [ ! -f "$fonts_dir/FiraCode-Regular.ttf" ]; then
    if command -v wget >/dev/null 2>&1; then
      sudo -u "$TARGET_USER" wget -q -O "$fonts_dir/FiraCode-Regular.ttf" \
        "https://github.com/tonsky/FiraCode/raw/master/distr/ttf/FiraCode-Regular.ttf" || true
    fi
  fi

  # Update font cache for the user (global fc-cache will also work)
  fc-cache -f -v "$fonts_dir" >/dev/null 2>&1 || true
  chown -R "$TARGET_USER":"$TARGET_USER" "$fonts_dir" || true
}

# Install a simple Conky config to the user's config dir if not present
# shellcheck disable=SC2317
install_conky_config() {
  local conky_dir="$TARGET_HOME/.config/conky"
  mkdir -p "$conky_dir"
  local conky_file="$conky_dir/conky.conf"
  if [ ! -f "$conky_file" ]; then
    cat > "$conky_file" <<'EOF'
conky.config = {
  alignment = 'top_right',
  background = false,
  border_width = 0,
  cpu_avg_samples = 2,
  double_buffer = true,
  draw_shades = false,
  gap_x = 20,
  gap_y = 40,
  minimum_width = 250,
  maximum_width = 350,
  own_window = true,
  own_window_transparent = true,
  own_window_type = 'desktop',
  own_window_argb_visual = true,
  own_window_argb_value = 150,
  update_interval = 2.0,
}

conky.text = [[
${color grey}Host:${color} ${nodename}
${color grey}Uptime:${color} ${uptime}

${color grey}CPU:${color}
${cpu cpu0}% ${cpubar 4}

${color grey}Mem:${color} ${mem} / ${memmax} ${membar 4}

${color grey}Disk:${color} ${fs_used /} / ${fs_size /}

${color grey}Top processes:${color}
${top name 1} ${top cpu 1}%
]]
EOF
    chown -R "$TARGET_USER":"$TARGET_USER" "$conky_dir" || true
  fi
}


is_mint() {
  [[ "$(lsb_release -si 2>/dev/null || echo '')" =~ [Ll]inux.*Mint ]] || return 1
}

add_ppa_if_missing() {
  local ppa=$1
  if ! grep -R --quiet "^deb .*${ppa}" /etc/apt/sources.list* 2>/dev/null; then
    log "Adding PPA: $ppa"
    add-apt-repository -y "ppa:$ppa"
  else
    log "PPA $ppa already present"
  fi
}

apt_install_if_missing() {
  local arr=("$@")
  local toins=()
  for pkg in "${arr[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      toins+=("$pkg")
    fi
  done
  if [ ${#toins[@]} -gt 0 ]; then
    log "Installing: ${toins[*]}"
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${toins[@]}"
  else
    log "Packages already installed"
  fi
}

# ----------------
# Main
# ----------------
determine_target_user
# Require root for system changes (apt, add-apt-repository, etc.)
if [ "${EUID}" -ne 0 ]; then
  echo "This script must be run as root (sudo). Exiting."
  exit 1
fi

# Default mode: auto (best-effort). Use --interactive to prompt for direct URLs when needed.
MODE="auto"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --interactive|-i) MODE="interactive"; shift;;
    --auto) MODE="auto"; shift;;
    --help|-h) echo "Usage: $0 [--auto|--interactive]"; exit 0;;
    *) shift;;
  esac
done
if ! is_mint; then
  echo "ERROR: This script is for Linux Mint (Cinnamon)."
  exit 1
fi

log "Updating system"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

# Add PPAs
if command -v add-apt-repository >/dev/null 2>&1 ; then
  add_ppa_if_missing "papirus/papirus"
else
  log "Installing software-properties-common"
  apt-get install -y software-properties-common
  add_ppa_if_missing "papirus/papirus"
fi

# Install packages
apt_install_if_missing "${EXTRA_PKGS[@]}"
# Best-effort theme/icon/font installs
install_provided_themes_and_icons || log "Theme/icon installs had issues (best-effort)"
install_fonts_from_pages || log "Font page installs had issues (best-effort)"
install_user_fonts || log "User font install had issues"
install_ulauncher_themes || log "Ulauncher installs had issues"
install_conky_config || log "Conky config install had issues"

log "Aesthetic setup finished (best-effort)."

### End of script
# shellcheck disable=SC2317
install_conky_config() {
  local conky_dir="$TARGET_HOME/.config/conky"
  mkdir -p "$conky_dir"
  local conky_file="$conky_dir/conky.conf"
  if [ ! -f "$conky_file" ]; then
    cat > "$conky_file" <<'EOF'
conky.config = {
  alignment = 'top_right',
  background = false,
  border_width = 0,
  cpu_avg_samples = 2,
  double_buffer = true,
  draw_shades = false,
  gap_x = 20,
  gap_y = 40,
  minimum_width = 250,
  maximum_width = 350,
  own_window = true,
  own_window_transparent = true,
  own_window_type = 'desktop',
  own_window_argb_visual = true,
  own_window_argb_value = 150,
  update_interval = 2.0,
}

conky.text = [[
${color grey}Host:${color} ${nodename}
${color grey}Uptime:${color} ${uptime}

${color grey}CPU:${color}
${cpu cpu0}% ${cpubar 4}

${color grey}Mem:${color} ${mem} / ${memmax} ${membar 4}

${color grey}Disk:${color} ${fs_used /} / ${fs_size /}

${color grey}Top processes:${color}
${top name 1} ${top cpu 1}%
]]
EOF
    chown -R "$TARGET_USER":"$TARGET_USER" "$conky_dir" || true
  fi
}
 

# Try to download a file linked from a GNOME-Look page (best effort):
download_asset_from_gnomelook() {
  local page_url="$1"
  local out_dir="$2"
  mkdir -p "$out_dir"
  log "Attempting to fetch asset URL from $page_url"
  if command -v wget >/dev/null 2>&1; then
    local tmpf
    tmpf="$(mktemp)"
    wget -q -O "$tmpf" "$page_url" || return 1
    # Try to find a direct link to common archive types
    local asset
    asset="$(grep -Eoi 'href="[^"]+\.(zip|tar\.gz|tar\.xz|tar\.bz2)"' "$tmpf" | head -n1 | sed -E 's/^href="//;s/"$//' )"
    if [ -z "$asset" ]; then
      # try links without quotes
      asset="$(grep -Eoi 'https?://[^"'\'' ]+\.(zip|tar\.gz|tar\.xz|tar\.bz2)' "$tmpf" | head -n1)"
    fi
    rm -f "$tmpf"
    if [ -n "$asset" ]; then
      # complete relative URLs
      if [[ "$asset" =~ ^/ ]]; then
        asset="$(echo "$page_url" | sed -E 's@(https?://[^/]+).*@\1@')${asset}"
      fi
      log "Found asset: $asset"
      wget -q -P "$out_dir" "$asset" || return 1
      return 0
    else
      log "No direct archive link found on $page_url"
      if [ "$MODE" = "interactive" ]; then
        echo "Please paste a direct download URL for an archive (zip/tar.gz) or press Enter to skip:"
        read -r userurl
        if [ -n "$userurl" ]; then
          wget -q -P "$out_dir" "$userurl" || return 1
          return 0
        else
          log "Skipping $page_url"
          return 2
        fi
      else
        log "Manual download may be required; run with --interactive to paste a direct URL when prompted."
        return 2
      fi
    fi
  else
    log "wget missing; cannot fetch $page_url"
    return 1
  fi
}

# Install a theme/icon archive into the user's ~/.themes or ~/.icons (best-effort)
install_theme_or_icon_from_url() {
  local url="$1"
  local dest="$2" # ~/.themes or ~/.icons
  local tmpd
  tmpd=$(mktemp -d)
  if [[ "$url" =~ github.com ]]; then
    # try to git clone the repo and copy
    if command -v git >/dev/null 2>&1; then
      git clone --depth=1 "$url" "$tmpd/repo" || return 1
      cp -r "$tmpd/repo"/* "$dest/" || true
      chown -R "$TARGET_USER":"$TARGET_USER" "$dest" || true
      rm -rf "$tmpd"
      return 0
    else
      log "git not available; cannot clone $url"
      return 1
    fi
  else
    download_asset_from_gnomelook "$url" "$tmpd" || {
      rm -rf "$tmpd"
      return $?
    }
    # find the downloaded archive
    local arc
    arc="$(find "$tmpd" -maxdepth 1 -type f -regextype posix-extended -regex '.*\.(zip|tar\.gz|tar\.xz|tar\.bz2)' | head -n1)"
    if [ -n "$arc" ]; then
      log "Extracting $arc to $dest"
      mkdir -p "$dest"
      case "$arc" in
        *.zip) unzip -q "$arc" -d "$tmpd/extracted" || true ;;
        *.tar.gz)
          mkdir -p "$tmpd/extracted"
          tar -xzf "$arc" -C "$tmpd/extracted" || true
          ;;
        *.tar.xz)
          mkdir -p "$tmpd/extracted"
          tar -xJf "$arc" -C "$tmpd/extracted" || true
          ;;
        *.tar.bz2)
          mkdir -p "$tmpd/extracted"
          tar -xjf "$arc" -C "$tmpd/extracted" || true
          ;;
      esac
      cp -r "$tmpd/extracted"/* "$dest/" || true
      chown -R "$TARGET_USER":"$TARGET_USER" "$dest" || true
      rm -rf "$tmpd"
      return 0
    else
      log "No archive downloaded from $url"
      rm -rf "$tmpd"
      return 1
    fi
  fi
}

# Bulk install themes and icons from arrays (best-effort)
install_provided_themes_and_icons() {
  for u in "${THEME_URLS[@]}"; do
    log "Installing theme from $u"
    install_theme_or_icon_from_url "$u" "$TARGET_HOME/.themes" || log "Theme install (best-effort) failed for $u"
  done
  for u in "${ICON_URLS[@]}"; do
    log "Installing icon from $u"
    install_theme_or_icon_from_url "$u" "$TARGET_HOME/.icons" || log "Icon install (best-effort) failed for $u"
  done
}

# Install Ulauncher themes (GitHub repos)
install_ulauncher_themes() {
  local dest="$TARGET_HOME/.local/share/ulauncher/extensions"
  mkdir -p "$dest"
  for u in "${ULAUNCHER_URLS[@]}"; do
    log "Installing ulauncher theme from $u"
    if command -v git >/dev/null 2>&1; then
      tmpd="$(mktemp -d)"
      git clone --depth=1 "$u" "$tmpd/repo" || { rm -rf "$tmpd"; log "git clone failed for $u"; continue; }
      # copy repo contents into extensions dir (best-effort)
      cp -r "$tmpd/repo"/* "$dest/" || true
      chown -R "$TARGET_USER":"$TARGET_USER" "$dest" || true
      rm -rf "$tmpd"
    else
      log "git not present; cannot install $u"
    fi
  done
}

# Try to download fonts linked on a page (best-effort)
install_fonts_from_pages() {
  local outdir="$TARGET_HOME/.local/share/fonts"
  mkdir -p "$outdir"
  for p in "${FONT_URLS[@]}"; do
    log "Attempting to fetch font assets from $p"
    if command -v wget >/dev/null 2>&1; then
      tmpf="$(mktemp)"
      wget -q -O "$tmpf" "$p" || true
      # try to find ttf/otf links
      for link in $(grep -Eoi 'https?://[^"'\'' ]+\.(ttf|otf|zip)' "$tmpf" | uniq); do
        log "Downloading font file $link"
        wget -q -P "$outdir" "$link" || true
      done
      rm -f "$tmpf"
    else
      log "wget not found; skipping font fetch for $p"
    fi
  done
  fc-cache -f -v "$outdir" >/dev/null 2>&1 || true
  chown -R "$TARGET_USER":"$TARGET_USER" "$outdir" || true
}

