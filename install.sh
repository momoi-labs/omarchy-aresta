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
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"

say() { echo -e "\e[32m==>\e[0m $*"; }
fail() { echo -e "install.sh: $*" >&2; exit 1; }

[[ -f $CONFIG ]] || fail "$CONFIG not found"
grep -qxF "$TOGGLES" "$CONFIG" || grep -qxF "$REQUIRE" "$CONFIG" ||
  fail "can't find $TOGGLES in $CONFIG; add $REQUIRE before it by hand"

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

if [[ $(jq -r '.bar.id // ""' "$SHELL_CONFIG" 2>/dev/null) != "$PLUGIN_ID" ]]; then
  if [[ -f $SHELL_CONFIG ]]; then
    mkdir -p "$BACKUP_DIR"
    cp "$SHELL_CONFIG" "$BACKUP_DIR/shell.json.orig"
    say "Backed up $SHELL_CONFIG to $BACKUP_DIR/shell.json.orig"
  fi
  say "Selecting the Cupertino bar"
  omarchy-bar use "$PLUGIN_ID" >/dev/null
fi

say "Done."
