# omarchy-cupertino

A macOS look for [Omarchy](https://omarchy.org) 4.5 or newer.

This first version styles windows:

- Windows on floating workspaces get a title bar with traffic lights: close,
  minimize and maximize on the left, grey when the window is unfocused, icons
  on hover, and the title centered.
- Tiled windows get no title bar.
- Every window gets rounded corners, a soft shadow and no colored border.

## Install

```sh
./install.sh
```

It links `hypr/omarchy-cupertino.lua` into `~/.config/hypr`, adds
`require("hypr.omarchy-cupertino")` to `~/.config/hypr/hyprland.lua` before
`require("default.hypr.toggles")`, and reloads Hyprland. Before it edits
`hyprland.lua`, it copies the file to `$CUPERTINO_BACKUP_DIR/hyprland.lua.orig`
(default `/tmp/omarchy-cupertino`). Running it again changes nothing.

Turn a workspace floating with Omarchy's workspace layout toggle to see the
title bars.

## Uninstall

```sh
./uninstall.sh
```

It removes the `require` line and the link, then reloads Hyprland.

## Credits

The title bar code is based on the
[macOS Dock plugin](https://github.com/rafabertholdo/omarchy-macos) by Rafael Bertholdo
(MIT). See `LICENSE`.
