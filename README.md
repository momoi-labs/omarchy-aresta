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
- Two Omarchy themes in macOS system colors: OSX Light and OSX Dark. Pick
  them in the Omarchy theme menu or with `omarchy-theme-set "osx light"`.
  Each has the Yaru blue icons and an original gradient background, which
  is only the fallback: switching to an OSX theme keeps the wallpaper you
  had before.

It also adds macOS shortcuts on Super:

- Super+Tab opens an app switcher like Cmd+Tab: one icon per app in
  most-recently-used order, in a rounded strip in the middle of the screen.
  Hold Super, press Tab or Shift+Tab or point at an icon to move, release
  Super to switch, click an icon to switch at once, or press Esc to cancel.
  Switching to a minimized app brings its window back.
  It replaces Omarchy's next and previous workspace bindings on Super+Tab and
  Super+Shift+Tab, and runs while the Cupertino bar is selected.
- Super+Q quits the app: it closes every window of the focused window's class,
  on all workspaces. Super+W still closes only the window.
- Super+M minimizes the window to the dock (Omarchy's binding, unchanged).
- Super+` cycles between windows of the same app, skipping minimized
  windows.
- The Quake console moves from Super+` to Super+Alt+`.

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
It links `themes/osx-light` and `themes/osx-dark` into
`~/.config/omarchy/themes`, and links a `theme-set` hook into
`~/.config/omarchy/hooks/theme-set.d` that keeps the current wallpaper on a
switch to an OSX theme. Running it again changes nothing.

Turn a workspace floating with Omarchy's workspace layout toggle to see the
title bars.

## Uninstall

```sh
./uninstall.sh
```

It restores `shell.json` from the backup (or selects the default bar when
the file changed since), removes the plugin link, the theme links, the hook
link, the `require` line and the Hyprland link, then reloads Hyprland.

## Credits

The title bar code is based on the
[macOS Dock plugin](https://github.com/rafabertholdo/omarchy-macos) by Rafael Bertholdo
(MIT). The app switcher is based on Renan Tonheiro's Switch Magic plugin
(MIT). See `LICENSE`.
