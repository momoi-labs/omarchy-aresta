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
    else if (verb === "brightness" && copy.display) copy.display.percent = Number(command[1])
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
    implicitWidth: card.width + 16
    implicitHeight: card.height + 16

    anchor {
      item: button
      edges: Edges.Bottom | Edges.Right
      gravity: Edges.Bottom | Edges.Left
      adjustment: PopupAdjustment.Slide
      margins.top: 4
      margins.right: -8
    }

    HyprlandFocusGrab {
      active: root.open && !root.pinned
      windows: button.QsWindow.window ? [popup, button.QsWindow.window] : [popup]
      onCleared: root.close()
    }

    Rectangle {
      id: card
      x: 8
      y: 8
      width: view.implicitWidth + 24
      height: view.implicitHeight + 24
      radius: 24
      color: Commons.Color.popups.background
      border.width: 1
      border.color: Qt.alpha(Commons.Color.popups.text, 0.16)

      ControlCenterView {
        id: view
        x: 12
        y: 12
        info: root.info
        show: ({ wifi: root.flag("wifi"), bluetooth: root.flag("bluetooth"), focus: root.flag("focus"), display: root.flag("display"), sound: root.flag("sound"), media: root.flag("media") })
        background: Commons.Color.popups.background
        foreground: Commons.Color.popups.text
        accent: Commons.Color.accent
        fontFamily: root.bar ? root.bar.fontFamily : "sans-serif"
        onAct: function(command) { root.act(command) }
      }
    }
  }
}
