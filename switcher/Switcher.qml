pragma ComponentBehavior: Bound

// Copyright (c) 2026 Sebastian Webber
// Copyright (c) 2026 Renan Tonheiro
// Licensed under the MIT License. See LICENSE.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons as Commons

Item {
  id: root

  property var shell: null
  property var manifest: null
  property string omarchyPath: ""

  readonly property string minimizedWorkspace: "special:minimized"
  readonly property real padding: 26
  readonly property real paddingTop: 27
  readonly property real cell: 102
  readonly property real gap: 14
  readonly property real iconSize: 90
  readonly property real cellRadius: 27
  readonly property real labelBaseline: 17
  readonly property real stripHeight: 156
  readonly property real stripRadius: 47
  readonly property real labelSize: 13
  readonly property real screenMargin: 40

  readonly property FontMetrics fontProbe: FontMetrics {}

  function doubleEmboldens(family) {
    fontProbe.font = Qt.font({ family: family, pixelSize: 40, weight: Font.Normal })
    var normalRect = fontProbe.tightBoundingRect("Appearance")
    var normalAdvance = fontProbe.advanceWidth("Appearance")
    fontProbe.font = Qt.font({ family: family, pixelSize: 40, weight: 699 })
    var boldRect = fontProbe.tightBoundingRect("Appearance")
    var boldAdvance = fontProbe.advanceWidth("Appearance")
    fontProbe.font = Qt.font({ family: family, pixelSize: 40, weight: Font.Bold })
    var heavyRect = fontProbe.tightBoundingRect("Appearance")
    var heavyAdvance = fontProbe.advanceWidth("Appearance")
    var hasRealBold = boldRect.width > normalRect.width + 0.5 || boldAdvance > normalAdvance + 0.5
    return hasRealBold
      && Math.abs(heavyAdvance - boldAdvance) < 0.5
      && heavyRect.width > boldRect.width + 0.5
      && heavyRect.height > boldRect.height + 0.5
  }

  readonly property string fontFamily: {
    var families = Qt.fontFamilies()
    var preferred = ["SF Pro Text", "SF Pro", "System Font", "Inter", "Noto Sans"]
    for (var i = 0; i < preferred.length; i++)
      if (families.indexOf(preferred[i]) !== -1 && !doubleEmboldens(preferred[i])) return preferred[i]
    return "sans-serif"
  }

  property bool opened: false
  property var apps: []
  property int selected: 0
  property var focusOrder: []
  property var iconIndex: ({})
  property var targetScreen: null

  readonly property real naturalWidth: padding * 2 + apps.length * cell + Math.max(0, apps.length - 1) * gap
  readonly property real fit: targetScreen ? Math.min(1, (targetScreen.width - screenMargin * 2) / Math.max(1, naturalWidth)) : 1
  readonly property var panelSettings: {
    var values = { panels_translucent: true, panels_opacity: 70 }
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
  readonly property color baseSurface: Qt.tint(Commons.Color.popups.background, Qt.alpha(Commons.Color.popups.text, 0.1))
  readonly property bool darkSurface: (0.2126 * Commons.Color.popups.background.r + 0.7152 * Commons.Color.popups.background.g + 0.0722 * Commons.Color.popups.background.b) < 0.4

  FileView {
    id: settingsFile
    path: Quickshell.env("HOME") + "/.config/aresta/settings.toml"
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

  function normalizedAddress(address) {
    var value = String(address || "")
    return value.indexOf("0x") === 0 ? value : "0x" + value
  }

  function rankOf(toplevel) {
    var address = normalizedAddress(toplevel.address)
    var index = focusOrder.indexOf(address)
    if (index >= 0) return index
    var ipc = toplevel.lastIpcObject || {}
    var history = typeof ipc.focusHistoryID === "number" && ipc.focusHistoryID >= 0 ? ipc.focusHistoryID : 1e6
    return focusOrder.length + history
  }

  function iconFor(entry, appId) {
    var names = []
    if (entry && entry.icon) names.push(String(entry.icon))
    if (appId) names.push(appId, appId.toLowerCase())
    for (var i = 0; i < names.length; i++) {
      if (names[i].charAt(0) === "/") return "file://" + names[i]
      if (iconIndex[names[i]]) return "file://" + iconIndex[names[i]].path
    }
    return ""
  }

  function buildApps() {
    var byApp = {}
    var order = []
    var toplevels = Hyprland.toplevels.values
    for (var i = 0; i < toplevels.length; i++) {
      var toplevel = toplevels[i]
      var ipc = toplevel.lastIpcObject || {}
      if (ipc.mapped === false) continue
      var workspace = toplevel.workspace
      var workspaceName = workspace ? String(workspace.name) : ""
      var minimized = workspaceName === minimizedWorkspace
      if (!workspace || (workspace.id < 1 && !minimized)) continue
      var appId = String(ipc.class || (toplevel.wayland ? toplevel.wayland.appId : "") || "")
      if (!appId) continue
      var rank = rankOf(toplevel)
      var app = byApp[appId]
      if (!app) {
        var entry = DesktopEntries.heuristicLookup(appId)
        app = { appId: appId, name: entry && entry.name ? entry.name : appId, icon: iconFor(entry, appId), rank: rank, address: "", minimized: false }
        byApp[appId] = app
        order.push(app)
      }
      if (!app.address || rank < app.rank) {
        app.rank = rank
        app.address = normalizedAddress(toplevel.address)
        app.minimized = minimized
      }
    }
    order.sort(function(a, b) { return a.rank - b.rank })
    return order
  }

  function screenForFocus() {
    var monitor = Hyprland.focusedMonitor
    for (var i = 0; i < Quickshell.screens.length; i++)
      if (monitor && Quickshell.screens[i].name === monitor.name) return Quickshell.screens[i]
    return Quickshell.screens[0]
  }

  function step(delta) {
    if (!opened) {
      Hyprland.refreshToplevels()
      apps = buildApps()
      if (apps.length === 0) return
      targetScreen = screenForFocus()
      selected = delta > 0 ? Math.min(1, apps.length - 1) : apps.length - 1
      opened = true
      return
    }
    if (apps.length > 0) selected = (selected + delta + apps.length) % apps.length
  }

  function reconcile() {
    if (!opened) return
    var current = apps[selected] ? apps[selected].appId : ""
    var next = buildApps()
    if (next.length === 0) {
      close()
      return
    }
    var index = 0
    for (var i = 0; i < next.length; i++) if (next[i].appId === current) index = i
    apps = next
    selected = Math.min(index, next.length - 1)
  }

  function close() {
    opened = false
    apps = []
  }

  function commit() {
    if (!opened) return
    var app = apps[selected]
    close()
    if (!app || !/^0x[0-9a-fA-F]+$/.test(app.address)) return
    Quickshell.execDetached(["hyprctl", "eval", "package.loaded[\"aresta.switcher\"].activate(\"" + app.address + "\")"])
  }

  function slotAt(x, y) {
    var index = Math.floor((x - padding) / (cell + gap))
    if (index < 0 || index >= apps.length) return -1
    if (x - padding - index * (cell + gap) > cell || y < paddingTop || y > paddingTop + cell) return -1
    return index
  }

  function hover(x, y) {
    var index = slotAt(x, y)
    if (index >= 0) selected = index
  }

  function pick(x, y) {
    var index = slotAt(x, y)
    if (!opened || index < 0) return
    selected = index
    Quickshell.execDetached(["hyprctl", "eval", "package.loaded[\"aresta.switcher\"].finish(\"commit\")"])
  }

  function scoreIcon(path) {
    if (/\.svg$/.test(path)) return 100000
    var match = path.match(/\/(\d+)x\d+(?:@(\d+)x?)?\//)
    if (match) return Number(match[1]) * (match[2] ? Number(match[2]) : 1)
    return 1
  }

  Process {
    id: iconScan
    running: true
    command: ["bash", "-c", [
      'dirs="$HOME/.icons $HOME/.local/share/icons";',
      'IFS=":"; for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do dirs="$dirs $d/icons"; done; unset IFS;',
      'for base in $dirs; do [[ -d $base ]] && find -L "$base" -path "*/apps/*" \\( -name "*.svg" -o -name "*.png" \\) 2>/dev/null; done;',
      'find /usr/share/pixmaps -maxdepth 1 \\( -name "*.svg" -o -name "*.png" \\) 2>/dev/null'
    ].join(" ")]
    stdout: StdioCollector {
      onStreamFinished: {
        var index = {}
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var path = lines[i]
          if (!path) continue
          var file = path.slice(path.lastIndexOf("/") + 1)
          var name = file.replace(/\.(svg|png)$/, "")
          var score = root.scoreIcon(path)
          if (!index[name] || score > index[name].score) index[name] = { path: path, score: score }
        }
        root.iconIndex = index
      }
    }
  }

  Connections {
    target: Hyprland
    function onActiveToplevelChanged() {
      var active = Hyprland.activeToplevel
      if (!active || !active.address) return
      var address = root.normalizedAddress(active.address)
      root.focusOrder = [address].concat(root.focusOrder.filter(function(item) { return item !== address })).slice(0, 256)
    }
  }

  Connections {
    target: Hyprland.toplevels
    function onValuesChanged() { root.reconcile() }
  }

  GlobalShortcut { appid: "aresta"; name: "next"; description: "App switcher: next app"; onPressed: root.step(1) }
  GlobalShortcut { appid: "aresta"; name: "previous"; description: "App switcher: previous app"; onPressed: root.step(-1) }
  GlobalShortcut { appid: "aresta"; name: "commit"; description: "App switcher: switch to the selected app"; onPressed: root.commit() }
  GlobalShortcut { appid: "aresta"; name: "cancel"; description: "App switcher: cancel"; onPressed: root.close() }

  IpcHandler {
    target: "aresta.switcher"
    function state(): string {
      return JSON.stringify({ opened: root.opened, selected: root.selected, apps: root.apps.map(function(app) { return { appId: app.appId, name: app.name, address: app.address, minimized: app.minimized, icon: app.icon } }) })
    }
  }

  PanelWindow {
    id: window

    visible: root.opened
    screen: root.targetScreen
    implicitWidth: Math.ceil(root.naturalWidth * root.fit)
    implicitHeight: Math.ceil(root.stripHeight * root.fit)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "aresta-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Item {
      id: strip

      width: root.naturalWidth
      height: root.stripHeight
      scale: root.fit
      transformOrigin: Item.TopLeft

      Rectangle {
        anchors.fill: parent
        radius: root.stripRadius
        color: root.panelsTranslucent ? Qt.rgba(root.baseSurface.r, root.baseSurface.g, root.baseSurface.b, root.panelsAlpha) : root.baseSurface
        border.width: 1
        border.color: root.panelsTranslucent ? (root.darkSurface ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.14)) : Qt.alpha(Commons.Color.popups.text, 0.12)

        Rectangle {
          anchors.fill: parent
          anchors.margins: 1
          radius: parent.radius - 1
          visible: root.panelsTranslucent
          gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, root.darkSurface ? 0.07 : 0.22) }
            GradientStop { position: 0.45; color: "transparent" }
          }
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onPositionChanged: mouse => root.hover(mouse.x, mouse.y)
        onClicked: mouse => root.pick(mouse.x, mouse.y)
      }

      Repeater {
        model: root.apps

        Item {
          id: slot

          required property var modelData
          required property int index
          readonly property bool current: index === root.selected

          x: root.padding + index * (root.cell + root.gap)
          y: root.paddingTop
          width: root.cell
          height: root.cell

          Rectangle {
            anchors.fill: parent
            radius: root.cellRadius
            visible: slot.current
            color: Qt.alpha(Commons.Color.popups.text, 0.28)
          }

          Image {
            id: icon
            anchors.centerIn: parent
            width: root.iconSize
            height: root.iconSize
            source: slot.modelData.icon
            sourceSize.width: root.iconSize * 3
            sourceSize.height: root.iconSize * 3
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
          }

          Text {
            anchors.centerIn: parent
            visible: icon.status !== Image.Ready
            text: slot.modelData.name.charAt(0).toUpperCase()
            color: Commons.Color.popups.text
            font.family: root.fontFamily
            font.pixelSize: root.iconSize * 0.5
            font.weight: Font.DemiBold
          }
        }
      }

      Text {
        id: label

        readonly property real center: root.padding + root.selected * (root.cell + root.gap) + root.cell / 2
        visible: root.apps.length > 0
        width: Math.min(implicitWidth, strip.width - root.padding * 2)
        x: Math.max(root.padding, Math.min(center - width / 2, strip.width - root.padding - width))
        y: root.paddingTop + root.cell + root.labelBaseline - baselineOffset
        text: root.apps[root.selected] ? root.apps[root.selected].name : ""
        elide: Text.ElideRight
        color: Commons.Color.popups.text
        font.family: root.fontFamily
        font.pixelSize: root.labelSize
        font.weight: Font.DemiBold
        textFormat: Text.PlainText
      }
    }
  }
}
