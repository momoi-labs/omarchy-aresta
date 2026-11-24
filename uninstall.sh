#!/bin/bash

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYPR_DIR="$HOME/.config/hypr"
CONFIG="$HYPR_DIR/hyprland.lua"
SOURCE="$REPO/hypr/omarchy-cupertino.lua"
TARGET="$HYPR_DIR/omarchy-cupertino.lua"
REQUIRE='require("hypr.omarchy-cupertino")'

say() { echo -e "\e[32m==>\e[0m $*"; }

if [[ -f $CONFIG ]] && grep -qxF "$REQUIRE" "$CONFIG"; then
  say "Removing $REQUIRE from $CONFIG"
  sed -i '/^require("hypr\.omarchy-cupertino")$/d' "$CONFIG"
fi

if [[ -L $TARGET && $(readlink -f "$TARGET") == "$(readlink -f "$SOURCE")" ]]; then
  say "Removing $TARGET"
  rm "$TARGET"
fi

say "Reloading Hyprland"
hyprctl reload >/dev/null

say "Done."
