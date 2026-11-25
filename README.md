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
- The Omarchy menu drawn as macOS Spotlight. Super+Space, the bar's menu
  button and `omarchy-menu` open one search field that ranks apps first,
  then menu rows with their path. A math expression such as `2^10` or
  `sqrt(2)*pi` shows its result in the field and on a card above the
  filters, and Enter or the copy button copies it. A submenu shows as a chip
  in the field, and Backspace on an empty field goes back. A row of filter buttons above
  the results opens Apps, as an icon grid, or a menu section. Ctrl+1 to
  Ctrl+9 pick a filter, because Super+1 to Super+9 switch workspaces. Scripts
  that use the menu as a picker, such as `omarchy-menu-keybindings`, keep
  working.
- Two Omarchy themes in macOS system colors: OSX Light and OSX Dark. Pick
  them in the Omarchy theme menu or with `omarchy-theme-set "osx light"`.
  Each has the Yaru blue icons and an original gradient background.

It also adds macOS shortcuts on Super:

- Super+Tab opens an app switcher like Cmd+Tab: one icon per app in
  most-recently-used order, in a rounded strip in the middle of the screen.
  Hold Super, press Tab or Shift+Tab or point at an icon to move, release
  Super to switch, click an icon to switch at once, or press Esc to cancel.
  Switching to a minimized app brings its window back.
  It replaces Omarchy's next and previous workspace bindings on Super+Tab and
  Super+Shift+Tab. It is its own shell plugin, so it keeps working when you
  switch back to the Omarchy bar.
- Super+Q quits the app: it closes every window of the focused window's class,
  on all workspaces. Super+W still closes only the window.
- Super+M minimizes the window to the dock (Omarchy's binding, unchanged).
- Super+` cycles between windows of the same app, skipping minimized
  windows.
- The Quake console moves from Super+` to Super+Alt+`.

## Cupertino Settings

Cupertino Settings is a small app in the style of macOS System Settings.
Open it from the app launcher. It has these sections:

- Appearance: switch between Light, Dark and Auto, pick the light and the
  dark theme from the installed Omarchy themes, see the colors of the current
  theme, and turn window shadows on or off. Auto picks the light theme at
  sunrise and the dark theme at sunset.
- Wallpaper: the current wallpaper, a switch that keeps it when the theme
  changes, and the pictures of the theme, of
  `~/.config/omarchy/backgrounds/<theme>` and of folders you add. Add Photo
  copies a picture into `~/.config/omarchy/backgrounds/<theme>`.
- Desktop & Dock: traffic lights on title bars, grey traffic lights on
  unfocused windows, icons in the traffic lights on hover, and the window
  title alignment.
- Menu Bar: the Cupertino menu bar itself, desktops in the bar (after the
  menus, in the center or before the status icons, as numbers or dots), the
  bar background opacity and the clock format.
- Keyboard: turn Quit app, Cycle windows, the app switcher and the Quake
  console keys on or off, and record new shortcuts for them. Omarchy's own
  bindings show as read-only.
- Spotlight: turn Cupertino Spotlight off to get the Omarchy menu back.
- Cupertino: options that macOS does not have, such as rounded corners and
  their radius and shape, the thin border, the shadow, the traffic light size
  and the bar size.

Each part of the plugin has a switch. Turning one off gives back Omarchy's own
behavior: the Omarchy bar, title bar buttons, square corners, colored border,
menu, or its Super+Q, Super+`, Super+Shift+`, Super+Tab and Super+Shift+Tab
bindings.

Changes apply at once. The app saves them to
`~/.config/omarchy-cupertino/settings.toml`, which the Hyprland config and the
bar read. Without that file, every option keeps its default.

The app is written in Rust with [cxx-qt](https://github.com/KDAB/cxx-qt) and
QML. To build it by hand you need Rust (`cargo`) and Qt 6:

```sh
cargo build --release --manifest-path app/Cargo.toml
```

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
It links `switcher/` into `~/.config/omarchy/plugins` and enables it. It
links `menu/` into `~/.config/omarchy/plugins` and enables it, which turns off
the Omarchy menu.
It links `themes/osx-light` and `themes/osx-dark` into
`~/.config/omarchy/themes`, and links a `theme-set` hook into
`~/.config/omarchy/hooks/theme-set.d` that keeps the current wallpaper on a
theme switch unless you turn that off. Finally, it builds Cupertino Settings
with `cargo` and installs it to `~/.local/bin/cupertino-settings`, with a
launcher entry in `~/.local/share/applications`.
It also installs the `cupertino-auto` systemd user timer, which runs
`cupertino-settings --auto` every minute for Auto appearance. Auto reads your
location from `~/.local/state/omarchy/settings/weather.json`, else from
`https://geo.omarchy.org/`, and computes sunrise and sunset on your computer.
Running the script again changes nothing.

Turn a workspace floating with Omarchy's workspace layout toggle to see the
title bars.

## Uninstall

```sh
./uninstall.sh
```

It restores `shell.json` from the backup (or selects the default bar when
the file changed since), disables the Spotlight menu so the Omarchy menu
comes back, removes the plugin links, the theme links, the hook
link, the `require` line, the Hyprland link, the Cupertino Settings binary
and launcher entry and the `cupertino-auto` timer, then reloads Hyprland. It
keeps your settings file.

## Credits

The title bar code is based on the
[macOS Dock plugin](https://github.com/rafabertholdo/omarchy-macos) by Rafael Bertholdo
(MIT). The app switcher is based on Renan Tonheiro's Switch Magic plugin
(MIT). See `LICENSE`.
