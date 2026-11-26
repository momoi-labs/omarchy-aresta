pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "dev.momoi-labs.omarchy-cupertino.control-center"

  property var info: ({})
  property bool open: false
  property bool pinned: false

  property var queue: []
  property bool stale: false

  readonly property var options: settings || ({})
  readonly property var panelSettings: {
    var values = { panels_translucent: true, panels_opacity: 70, panels_align_right: true, control_center_halo: false }
    var lines = settingsFile.text().split("\n")
    for (var i = 0; i < lines.length; i++) {
      var match = lines[i].match(/^\s*(\w+)\s*=\s*(.*?)\s*$/)
      if (!match || !(match[1] in values)) continue
      if (typeof values[match[1]] === "boolean") {
        if (match[2] === "true" || match[2] === "false") values[match[1]] = match[2] === "true"
      } else if (match[2] !== "" && !isNaN(Number(match[2]))) {
        values[match[1]] = Number(match[2])
      }
    }
    return values
  }
  readonly property bool panelsTranslucent: panelSettings.panels_translucent
  readonly property real panelsAlpha: Math.max(0.3, Math.min(1, panelSettings.panels_opacity / 100))
  readonly property bool panelsAlignRight: panelSettings.panels_align_right
  readonly property bool controlCenterHalo: panelSettings.control_center_halo
  readonly property bool darkCard: (0.2126 * Commons.Color.popups.background.r + 0.7152 * Commons.Color.popups.background.g + 0.0722 * Commons.Color.popups.background.b) < 0.4

  FileView {
    id: settingsFile
    path: Quickshell.env("HOME") + "/.config/omarchy-cupertino/settings.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoadFailed: settingsRetry.restart()
  }

  Timer {
    id: settingsRetry
    interval: 2000
    onTriggered: settingsFile.reload()
  }

  function flag(name) { return options[name] === undefined ? true : options[name] === true }
  function close() { open = false; pinned = false }
  function refresh() { if (!reader.running) reader.running = true }

  function act(command) {
    if (command[0] === "picker") close()
    else apply(command)
    queue = queue.concat([command])
    next()
  }

  function next() {
    if (runner.running || queue.length === 0) return
    runner.command = ["bash", Qt.resolvedUrl("act.sh").toString().replace("file://", "")].concat(queue[0])
    queue = queue.slice(1)
    runner.running = true
  }

  function apply(command) {
    var copy = JSON.parse(JSON.stringify(info))
    var verb = command[0]
    if (verb === "wifi" && copy.wifi) copy.wifi.on = command[1] === "on"
    else if (verb === "bluetooth" && copy.bt) copy.bt.on = command[1] === "on"
    else if (verb === "focus" && copy.focus) copy.focus.on = !copy.focus.on
    else if (verb === "nightlight") {
      if (!copy.nightlight) copy.nightlight = {}
      copy.nightlight.on = !copy.nightlight.on
    } else if (verb === "brightness" && copy.display) copy.display.percent = Number(command[1])
    else if (verb === "volume" && copy.sound) { copy.sound.percent = Number(command[1]); copy.sound.muted = false }
    else return
    info = copy
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenChanged: {
    if (open) refresh()
    if (!bar) return
    if (open) bar.requestPopout(root)
    else if (bar.activePopout === root) bar.releasePopout(root)
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: String.fromCodePoint(0xF1542)
    onPressed: function() { root.pinned = false; root.open = !root.open }
  }

  Process {
    id: reader
    command: ["bash", Qt.resolvedUrl("data.sh").toString().replace("file://", "")]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        if (runner.running || root.queue.length > 0) return
        if (root.stale) {
          root.stale = false
          reader.running = true
          return
        }
        try { root.info = JSON.parse(text) } catch (error) {}
      }
    }
  }

  Process {
    id: runner
    onExited: {
      root.next()
      if (runner.running) return
      root.stale = reader.running
      root.refresh()
    }
  }

  Timer {
    interval: 2000
    repeat: true
    running: root.open
    onTriggered: root.refresh()
  }

  IpcHandler {
    target: "cupertino-control-center"
    function reveal(): void { root.pinned = true; root.open = true }
    function dismiss(): void { root.close() }
    function toggle(): void { root.pinned = false; root.open = !root.open }
  }

  PopupWindow {
    id: popup

    visible: root.open
    color: "transparent"
    implicitWidth: card.width
    implicitHeight: card.height

    anchor {
      id: popupAnchor
      window: button.QsWindow.window
      adjustment: PopupAdjustment.Slide
      edges: Edges.Top | Edges.Left
      gravity: Edges.Bottom | Edges.Right
      rect.width: 1
      rect.height: 1
      onAnchoring: {
        var win = button.QsWindow.window
        if (!win) return
        var margin = Commons.Style.gapsOut
        var targetX = win.width - popup.implicitWidth - margin
        if (!root.panelsAlignRight) {
          var point = win.contentItem.mapFromItem(button, button.width / 2 - popup.implicitWidth / 2, 0)
          targetX = Math.max(margin, Math.min(point.x, win.width - popup.implicitWidth - margin))
        }
        popupAnchor.rect.x = Math.round(Math.max(margin, targetX))
        popupAnchor.rect.y = Math.round(win.height + margin)
      }
    }

    HyprlandFocusGrab {
      active: root.open && !root.pinned
      windows: button.QsWindow.window ? [popup, button.QsWindow.window] : [popup]
      onCleared: root.close()
    }

    Rectangle {
      id: card
      x: 0
      y: 0
      width: view.implicitWidth + (root.controlCenterHalo ? 24 : 0)
      height: view.implicitHeight + (root.controlCenterHalo ? 24 : 0)
      radius: root.controlCenterHalo ? 34 : 0
      color: !root.controlCenterHalo
        ? "transparent"
        : root.panelsTranslucent
          ? Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, Math.max(0.24, Math.min(0.55, root.panelsAlpha * 0.48)))
          : Commons.Color.popups.background
      border.width: root.controlCenterHalo ? 1 : 0
      border.color: root.panelsTranslucent
        ? (root.darkCard ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12))
        : Qt.alpha(Commons.Color.popups.text, 0.16)

      Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, parent.radius - 1)
        visible: root.controlCenterHalo && root.panelsTranslucent
        gradient: Gradient {
          GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, root.darkCard ? 0.06 : 0.22) }
          GradientStop { position: 0.45; color: "transparent" }
        }
      }

      ControlCenterView {
        id: view
        x: root.controlCenterHalo ? 12 : 0
        y: root.controlCenterHalo ? 12 : 0
        info: root.info
        show: ({ wifi: root.flag("wifi"), bluetooth: root.flag("bluetooth"), focus: root.flag("focus"), display: root.flag("display"), sound: root.flag("sound"), media: root.flag("media") })
        background: Commons.Color.popups.background
        foreground: Commons.Color.popups.text
        accent: Commons.Color.accent
        translucent: root.panelsTranslucent
        panelAlpha: root.panelsAlpha
        halo: root.controlCenterHalo
        fontFamily: root.bar ? root.bar.fontFamily : "sans-serif"
        onAct: function(command) { root.act(command) }
      }
    }
  }
}
