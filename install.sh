#!/bin/bash

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYPR_DIR="$HOME/.config/hypr"
CONFIG="$HYPR_DIR/hyprland.lua"
SOURCE="$REPO/hypr/omarchy-cupertino.lua"
TARGET="$HYPR_DIR/omarchy-cupertino.lua"
REQUIRE='require("hypr.omarchy-cupertino")'
TOGGLES='require("default.hypr.toggles")'
BACKUP_DIR="${CUPERTINO_BACKUP_DIR:-${TMPDIR:-/tmp}/omarchy-cupertino}"
PLUGIN_ID="$(jq -r .id "$REPO/manifest.json")"
PLUGIN_LINK="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
MENU_ID="$(jq -r .id "$REPO/menu/manifest.json")"
MENU_LINK="$HOME/.config/omarchy/plugins/$MENU_ID"
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"
THEMES_DIR="$HOME/.config/omarchy/themes"
HOOK_SOURCE="$REPO/hooks/cupertino-wallpaper"
HOOK_LINK="$HOME/.config/omarchy/hooks/theme-set.d/cupertino-wallpaper"
LAST_THEME_FILE="$HOME/.local/state/omarchy/cupertino-last-theme"
APP_BIN="$HOME/.local/bin/cupertino-settings"
APP_DESKTOP="$HOME/.local/share/applications/cupertino-settings.desktop"
UNIT_DIR="$HOME/.config/systemd/user"

say() { echo -e "\e[32m==>\e[0m $*"; }
fail() { echo -e "install.sh: $*" >&2; exit 1; }

[[ -f $CONFIG ]] || fail "$CONFIG not found"
grep -qxF "$TOGGLES" "$CONFIG" || grep -qxF "$REQUIRE" "$CONFIG" ||
  fail "can't find $TOGGLES in $CONFIG; add $REQUIRE before it by hand"
command -v cargo >/dev/null || fail "cargo not found; it builds Cupertino Settings"

say "Building Cupertino Settings"
cargo build --release --locked --manifest-path "$REPO/app/Cargo.toml"

if [[ -L $TARGET && $(readlink -f "$TARGET") == "$(readlink -f "$SOURCE")" ]]; then
  :
elif [[ -e $TARGET || -L $TARGET ]]; then
  fail "$TARGET already exists and is not a link to $SOURCE"
else
  say "Linking $TARGET"
  ln -s "$SOURCE" "$TARGET"
fi

if ! grep -qxF "$REQUIRE" "$CONFIG"; then
  mkdir -p "$BACKUP_DIR"
  cp "$CONFIG" "$BACKUP_DIR/hyprland.lua.orig"
  say "Backed up $CONFIG to $BACKUP_DIR/hyprland.lua.orig"
  say "Adding $REQUIRE to $CONFIG"
  sed -i "s/^require(\"default\.hypr\.toggles\")\$/require(\"hypr.omarchy-cupertino\")\n&/" "$CONFIG"
fi

say "Reloading Hyprland"
hyprctl reload >/dev/null
sleep 1
errors="$(hyprctl configerrors)"
[[ -z ${errors//[[:space:]]/} ]] || fail "Hyprland reported config errors:\n$errors"

if [[ -L $PLUGIN_LINK && $(readlink -f "$PLUGIN_LINK") == "$REPO" ]]; then
  :
elif [[ -e $PLUGIN_LINK || -L $PLUGIN_LINK ]]; then
  fail "$PLUGIN_LINK already exists and is not a link to $REPO"
else
  say "Linking $PLUGIN_LINK"
  mkdir -p "$(dirname "$PLUGIN_LINK")"
  ln -s "$REPO" "$PLUGIN_LINK"
  omarchy-shell shell rescanPlugins >/dev/null
fi

if [[ -L $MENU_LINK && $(readlink -f "$MENU_LINK") == "$REPO/menu" ]]; then
  :
elif [[ -e $MENU_LINK || -L $MENU_LINK ]]; then
  fail "$MENU_LINK already exists and is not a link to $REPO/menu"
else
  say "Linking $MENU_LINK"
  ln -s "$REPO/menu" "$MENU_LINK"
  omarchy-shell shell rescanPlugins >/dev/null
fi

if ! omarchy-plugin-list | grep -qE "^$MENU_ID +enabled "; then
  say "Enabling the Spotlight menu"
  omarchy-plugin-enable "$MENU_ID" >/dev/null
fi

if [[ $(jq -r '.bar.id // ""' "$SHELL_CONFIG" 2>/dev/null) != "$PLUGIN_ID" ]]; then
  if [[ -f $SHELL_CONFIG ]]; then
    mkdir -p "$BACKUP_DIR"
    cp "$SHELL_CONFIG" "$BACKUP_DIR/shell.json.orig"
    say "Backed up $SHELL_CONFIG to $BACKUP_DIR/shell.json.orig"
  fi
  say "Selecting the Cupertino bar"
  omarchy-bar use "$PLUGIN_ID" >/dev/null
fi

for theme in "$REPO"/themes/*/; do
  theme="${theme%/}"
  link="$THEMES_DIR/$(basename "$theme")"
  if [[ -L $link && $(readlink -f "$link") == "$theme" ]]; then
    :
  elif [[ -e $link || -L $link ]]; then
    fail "$link already exists and is not a link to $theme"
  else
    say "Linking $link"
    mkdir -p "$THEMES_DIR"
    ln -s "$theme" "$link"
  fi
done

if [[ -L $HOOK_LINK && $(readlink -f "$HOOK_LINK") == "$(readlink -f "$HOOK_SOURCE")" ]]; then
  :
elif [[ -e $HOOK_LINK || -L $HOOK_LINK ]]; then
  fail "$HOOK_LINK already exists and is not a link to $HOOK_SOURCE"
else
  say "Linking $HOOK_LINK"
  mkdir -p "$(dirname "$HOOK_LINK")"
  ln -s "$HOOK_SOURCE" "$HOOK_LINK"
fi

if [[ ! -f $LAST_THEME_FILE && -f $HOME/.local/state/omarchy/current/theme.name ]]; then
  cp "$HOME/.local/state/omarchy/current/theme.name" "$LAST_THEME_FILE"
fi

say "Installing $APP_BIN"
install -Dm755 "$REPO/app/target/release/cupertino-settings" "$APP_BIN"
mkdir -p "$(dirname "$APP_DESKTOP")"
cat >"$APP_DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=Cupertino Settings
Comment=Settings for the Omarchy Cupertino plugin
Exec=$APP_BIN
Icon=preferences-system
Categories=Settings;
StartupWMClass=cupertino-settings
EOF

say "Installing the Auto appearance timer"
mkdir -p "$UNIT_DIR"
cat >"$UNIT_DIR/cupertino-auto.service" <<EOF
[Unit]
Description=Cupertino Settings Auto appearance

[Service]
Type=oneshot
KillMode=process
ExecStart=$APP_BIN --auto
EOF
cat >"$UNIT_DIR/cupertino-auto.timer" <<EOF
[Unit]
Description=Cupertino Settings Auto appearance

[Timer]
OnCalendar=minutely
OnStartupSec=15
AccuracySec=1s
Persistent=true

[Install]
WantedBy=timers.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now cupertino-auto.timer >/dev/null 2>&1

say "Done."
