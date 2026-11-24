#!/bin/bash

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYPR_DIR="$HOME/.config/hypr"
CONFIG="$HYPR_DIR/hyprland.lua"
SOURCE="$REPO/hypr/omarchy-cupertino.lua"
TARGET="$HYPR_DIR/omarchy-cupertino.lua"
REQUIRE='require("hypr.omarchy-cupertino")'
BACKUP_DIR="${CUPERTINO_BACKUP_DIR:-${TMPDIR:-/tmp}/omarchy-cupertino}"
PLUGIN_ID="$(jq -r .id "$REPO/manifest.json")"
PLUGIN_LINK="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
MENU_ID="$(jq -r .id "$REPO/menu/manifest.json")"
MENU_LINK="$HOME/.config/omarchy/plugins/$MENU_ID"
SWITCHER_ID="$(jq -r .id "$REPO/switcher/manifest.json")"
SWITCHER_LINK="$HOME/.config/omarchy/plugins/$SWITCHER_ID"
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"
SHELL_BACKUP="$BACKUP_DIR/shell.json.orig"
THEMES_DIR="$HOME/.config/omarchy/themes"
HOOK_SOURCE="$REPO/hooks/cupertino-wallpaper"
HOOK_LINK="$HOME/.config/omarchy/hooks/theme-set.d/cupertino-wallpaper"
LAST_THEME_FILE="$HOME/.local/state/omarchy/cupertino-last-theme"
APP_BIN="$HOME/.local/bin/cupertino-settings"
APP_DESKTOP="$HOME/.local/share/applications/cupertino-settings.desktop"
UNIT_DIR="$HOME/.config/systemd/user"

say() { echo -e "\e[32m==>\e[0m $*"; }

if [[ -f $SHELL_CONFIG && $(jq -r '.bar.id // ""' "$SHELL_CONFIG") == "$PLUGIN_ID" ]]; then
  if [[ -f $SHELL_BACKUP ]] &&
    [[ $(jq -S 'del(.bar.id)' "$SHELL_CONFIG") == "$(jq -S 'del(.bar.id)' "$SHELL_BACKUP")" ]]; then
    say "Restoring $SHELL_CONFIG from $SHELL_BACKUP"
    cp "$SHELL_BACKUP" "$SHELL_CONFIG"
  else
    say "Selecting the default Omarchy bar"
    omarchy-bar reset >/dev/null
  fi
fi

if omarchy-plugin-list | grep -qE "^$MENU_ID +enabled "; then
  say "Disabling the Spotlight menu"
  omarchy-plugin-disable "$MENU_ID" >/dev/null
fi

if [[ -L $MENU_LINK && $(readlink -f "$MENU_LINK") == "$REPO/menu" ]]; then
  say "Removing $MENU_LINK"
  rm "$MENU_LINK"
  omarchy-shell shell rescanPlugins >/dev/null
fi

if [[ -L $SWITCHER_LINK && $(readlink -f "$SWITCHER_LINK") == "$REPO/switcher" ]]; then
  say "Removing $SWITCHER_LINK"
  rm "$SWITCHER_LINK"
  omarchy-shell shell rescanPlugins >/dev/null
fi

if [[ -L $PLUGIN_LINK && $(readlink -f "$PLUGIN_LINK") == "$REPO" ]]; then
  say "Removing $PLUGIN_LINK"
  rm "$PLUGIN_LINK"
  omarchy-shell shell rescanPlugins >/dev/null
fi

if [[ -f $CONFIG ]] && grep -qxF "$REQUIRE" "$CONFIG"; then
  say "Removing $REQUIRE from $CONFIG"
  sed -i '/^require("hypr\.omarchy-cupertino")$/d' "$CONFIG"
fi

if [[ -L $TARGET && $(readlink -f "$TARGET") == "$(readlink -f "$SOURCE")" ]]; then
  say "Removing $TARGET"
  rm "$TARGET"
fi

for theme in "$REPO"/themes/*/; do
  theme="${theme%/}"
  link="$THEMES_DIR/$(basename "$theme")"
  if [[ -L $link && $(readlink -f "$link") == "$theme" ]]; then
    say "Removing $link"
    rm "$link"
  fi
done

if [[ -L $HOOK_LINK && $(readlink -f "$HOOK_LINK") == "$(readlink -f "$HOOK_SOURCE")" ]]; then
  say "Removing $HOOK_LINK"
  rm "$HOOK_LINK"
fi
rm -f "$LAST_THEME_FILE"

if [[ -f $UNIT_DIR/cupertino-auto.timer ]]; then
  say "Removing the Auto appearance timer"
  systemctl --user disable --now cupertino-auto.timer >/dev/null 2>&1 || true
fi

for file in "$APP_BIN" "$APP_DESKTOP" "$UNIT_DIR/cupertino-auto.timer" "$UNIT_DIR/cupertino-auto.service"; do
  if [[ -f $file ]]; then
    say "Removing $file"
    rm "$file"
  fi
done

systemctl --user daemon-reload || true

say "Reloading Hyprland"
hyprctl reload >/dev/null

say "Done."
