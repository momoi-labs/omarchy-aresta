# omarchy-cupertino

A macOS look for [Omarchy](https://omarchy.org) 4.5 or newer.

It has:

- A Mac-style top bar that replaces the Omarchy bar: the Omarchy menu button
  and the focused app's name on the left, your status widgets (third-party
  ones too) and the date and time on the right, sized and spaced like the
  macOS menu bar. It has white text on a translucent, unblurred background
  in your theme colors, and uses SF Pro when it is installed, or Inter.
- Windows on floating workspaces get a title bar with traffic lights: close,
  minimize and maximize on the left, grey when the window is unfocused, icons
  on hover, and the title centered.
- Tiled windows get no title bar.
- Every window gets rounded corners, a soft shadow and a thin neutral outline
  instead of a colored border.

## Install

```sh
./install.sh
```

It links `hypr/omarchy-cupertino.lua` into `~/.config/hypr`, adds
`require("hypr.omarchy-cupertino")` to `~/.config/hypr/hyprland.lua` before
`require("default.hypr.toggles")`, and reloads Hyprland. Before it edits
`hyprland.lua`, it copies the file to `$CUPERTINO_BACKUP_DIR/hyprland.lua.orig`
(default `/tmp/omarchy-cupertino`). It also links the repository into
`~/.config/omarchy/plugins` and selects the Cupertino bar, after it copies
`~/.config/omarchy/shell.json` to `$CUPERTINO_BACKUP_DIR/shell.json.orig`.
Running it again changes nothing.

Turn a workspace floating with Omarchy's workspace layout toggle to see the
title bars.

## Uninstall

```sh
./uninstall.sh
```

It restores `shell.json` from the backup (or selects the default bar when
the file changed since), removes the plugin link, the `require` line and the
Hyprland link, then reloads Hyprland.

## Credits

The title bar code is based on the
[macOS Dock plugin](https://github.com/rafabertholdo/omarchy-macos) by Rafael Bertholdo
(MIT). See `LICENSE`.
