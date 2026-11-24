// Copyright (c) 2026 Sebastian Webber
// Licensed under the MIT License. See LICENSE.

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
  id: root

  property string omarchyPath: ""
  property var shell: null
  property var manifest: null
  property var barWidgetRegistry: null
  property var pluginRegistry: null
  property var barConfig: ({})

  readonly property string position: "top"
  readonly property bool vertical: false
  readonly property var settings: {
    var values = { bar_height: 29, bar_opacity: 30, clock_format: "ddd d MMM  HH:mm", status_icon_scale: 120, status_item_width: 38 }
    var lines = settingsFile.text().split("\n")
    for (var i = 0; i < lines.length; i++) {
      var match = lines[i].match(/^\s*(\w+)\s*=\s*(.*?)\s*$/)
      if (!match || !(match[1] in values)) continue
      if (typeof values[match[1]] === "string") {
        var text = match[2].match(/^"(.*)"$/)
        if (text) values[match[1]] = text[1]
      } else if (match[2] !== "" && !isNaN(Number(match[2]))) {
        values[match[1]] = Number(match[2])
      }
    }
    return values
  }
  readonly property int barSize: Math.round(settings.bar_height)
  readonly property string fontFamily: {
    var families = Qt.fontFamilies()
    var preferred = ["SF Pro Text", "SF Pro", "System Font", "Inter"]
    for (var i = 0; i < preferred.length; i++)
      if (families.indexOf(preferred[i]) !== -1) return preferred[i]
    return "sans-serif"
  }
  readonly property string clockFormat: settings.clock_format
  readonly property color foreground: "#ffffff"
  readonly property color background: Commons.Color.bar.background
  readonly property color urgent: Commons.Color.bar.active

  readonly property var leftOnlyIds: ["omarchy.menu", "omarchy.workspaces", "omarchy.active-window", "omarchy.spacer", "omarchy.clock"]
  readonly property var sectionOrder: ["left", "centerBegin", "center", "centerEnd", "right", "tray"]

  readonly property var layout: barConfig && barConfig.layout ? barConfig.layout : ({})

  readonly property var statusEntries: {
    var out = {}
    var keys = []
    for (var s = 0; s < sectionOrder.length; s++) {
      var list = layout[sectionOrder[s]]
      if (!Array.isArray(list)) continue
      for (var i = 0; i < list.length; i++) {
        var entry = typeof list[i] === "string" ? { id: list[i] } : list[i]
        if (!entry || !entry.id || entry.type) continue
        if (leftOnlyIds.indexOf(String(entry.id)) !== -1) continue
        var key = String(entry.id)
        while (out[key]) key += "+"
        out[key] = entry
        keys.push(key)
      }
    }
    return { keys: keys, entries: out }
  }

  readonly property var clockEntry: {
    for (var s = 0; s < sectionOrder.length; s++) {
      var list = layout[sectionOrder[s]]
      if (!Array.isArray(list)) continue
      for (var i = 0; i < list.length; i++)
        if (list[i] && list[i].id === "omarchy.clock") return list[i]
    }
    return { id: "omarchy.clock" }
  }

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

  property var activePopout: null
  property var clickTargets: []
  property var widgetSlots: []
  property var barApis: ({})
  property var tooltipTarget: null
  property string tooltipText: ""

  function settingsFor(entry) {
    var copy = {}
    for (var key in entry) if (key !== "id") copy[key] = entry[key]
    if (entry.id === "omarchy.clock") copy.format = root.clockFormat
    return copy
  }

  function registerClickTarget(target) {
    if (!target || clickTargets.indexOf(target) !== -1) return
    clickTargets = clickTargets.concat([target])
  }

  function unregisterClickTarget(target) {
    clickTargets = clickTargets.filter(function(item) { return item !== target })
  }

  function requestPopout(owner) {
    if (activePopout === owner) return
    if (activePopout) {
      if ("closeForPopoutSwitch" in activePopout) activePopout.closeForPopoutSwitch()
      else if ("close" in activePopout) activePopout.close()
    }
    activePopout = owner
  }

  function releasePopout(owner) {
    if (activePopout === owner) activePopout = null
  }

  function targetBelongsToWindow(target, window) {
    return !!target && !!window && !!target.QsWindow && target.QsWindow.window === window
  }

  function moduleWidgets(id) {
    var items = []
    for (var i = 0; i < widgetSlots.length; i++) {
      var slot = widgetSlots[i]
      if (slot && slot.activeItem && slot.moduleName === id) items.push(slot.activeItem)
    }
    return items
  }

  function findPanelWidget(id) {
    var focused = Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name || "") : ""
    var best = null
    var bestRank = -1
    for (var i = 0; i < widgetSlots.length; i++) {
      var slot = widgetSlots[i]
      var item = slot ? slot.activeItem : null
      if (!item || slot.moduleName !== id) continue
      if (typeof item.open !== "function" || typeof item.close !== "function" || item.opened === undefined) continue
      var window = slot.QsWindow ? slot.QsWindow.window : null
      var onFocused = !!window && !!window.screen && window.screen.name === focused
      var rank = (item.opened === true ? 2 : 0) + (onFocused ? 1 : 0)
      if (rank > bestRank) {
        best = item
        bestRank = rank
      }
    }
    return best
  }

  function summonBarWidget(id) {
    var item = findPanelWidget(id)
    if (!item) return false
    item.open()
    return true
  }

  function hideBarWidget(id) {
    var item = findPanelWidget(id)
    if (!item) return false
    item.close()
    return true
  }

  function isBarWidgetOpen(id) {
    var item = findPanelWidget(id)
    return !!item && item.opened === true
  }

  function showTooltip(target, text) {
    tooltipTarget = target
    tooltipText = String(text || "")
    tooltipTimer.restart()
  }

  function hideTooltip(target) {
    if (tooltipTarget !== target) return
    tooltipTimer.stop()
    tooltipTarget = null
    tooltipText = ""
  }

  function run(command) {
    if (command) Util.execDetached(command)
  }

  function entryShellFor(moduleName, firstParty) {
    var facade = root.shell && typeof root.shell.pluginShellForBarEntry === "function"
      ? root.shell.pluginShellForBarEntry(moduleName, moduleName) : null
    if (!firstParty || !facade) return facade
    return entryShellComponent.createObject(root, { facade: facade, host: root.shell })
  }

  function barApiFor(moduleName, firstParty) {
    if (barApis[moduleName]) return barApis[moduleName]
    var api = barApiComponent.createObject(root, {
      pluginId: moduleName,
      moduleName: moduleName,
      shell: root.entryShellFor(moduleName, firstParty),
      _showTooltip: root.showTooltip,
      _hideTooltip: root.hideTooltip,
      _registerClickTarget: root.registerClickTarget,
      _unregisterClickTarget: root.unregisterClickTarget,
      _requestPopout: root.requestPopout,
      _releasePopout: root.releasePopout,
      _targetBelongsToWindow: root.targetBelongsToWindow,
      _moduleWidgets: root.moduleWidgets,
      _run: root.run
    })
    var next = {}
    for (var id in barApis) next[id] = barApis[id]
    next[moduleName] = api
    barApis = next
    return api
  }

  Component {
    id: barApiComponent

    PluginBarApi {
      foreground: root.foreground
      barForeground: root.foreground
      background: root.background
      urgent: root.urgent
      fontFamily: root.fontFamily
      position: root.position
      vertical: root.vertical
      barSize: root.barSize
      activePopout: root.activePopout
      clickTargets: root.clickTargets
      layoutConfig: root.layout
    }
  }

  Component {
    id: entryShellComponent

    QtObject {
      property var facade: null
      property var host: null
      readonly property var barConfig: facade ? facade.barConfig : ({})

      function serviceFor(id) { return facade.serviceFor(id) }
      function firstPartyServiceFor(id) { return host ? host.firstPartyServiceFor(id) : null }
      function summon(id, payloadJson) { return host.summon(id, payloadJson) }
      function hide(id) { return facade.hide(id) }
      function toggle(id, payloadJson) { return facade.toggle(id, payloadJson) }
      function isPluginOpen(id) { return facade.isPluginOpen(id) }
      function updateEntryInline(id, settings) { return facade.updateEntryInline(id, settings) }
    }
  }

  Timer {
    id: tooltipTimer
    interval: 400
  }

  component WidgetSlot: Item {
    id: slot

    required property var entry
    readonly property string moduleName: String(entry.id || "")
    readonly property var registered: {
      var widgets = root.barWidgetRegistry ? root.barWidgetRegistry.widgets : null
      return widgets ? widgets[moduleName] || null : null
    }
    readonly property bool firstParty: !!registered && !!registered.metadata && registered.metadata.firstParty === true
    readonly property var settings: root.settingsFor(entry)
    readonly property var activeItem: loader.item

    property real itemScale: 1
    property real cellWidth: 0
    readonly property real scaledWidth: activeItem ? activeItem.implicitWidth * itemScale : 0

    implicitWidth: activeItem && activeItem.visible ? Math.max(cellWidth, Math.ceil(scaledWidth)) : 0
    implicitHeight: root.barSize

    function inject() {
      var target = loader.item
      if (!target) return
      if ("fixedEdge" in target) target.fixedEdge = "end"
      if ("bar" in target) target.bar = root.barApiFor(slot.moduleName, slot.firstParty)
      if ("moduleName" in target) target.moduleName = slot.moduleName
      if ("settings" in target) target.settings = slot.settings
    }

    onSettingsChanged: inject()
    Component.onCompleted: root.widgetSlots = root.widgetSlots.concat([slot])
    Component.onDestruction: root.widgetSlots = root.widgetSlots.filter(function(item) { return item !== slot })

    Loader {
      id: loader

      anchors.verticalCenter: parent.verticalCenter
      x: Math.round((slot.width - slot.scaledWidth) / 2)
      width: item ? item.implicitWidth : 0
      scale: slot.itemScale
      transformOrigin: Item.Left
      height: item ? item.implicitHeight : 0
      sourceComponent: slot.registered ? slot.registered.component : null
      onLoaded: {
        slot.inject()
        Qt.callLater(slot.inject)
      }
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: barWindow

        required property var modelData

        screen: modelData
        anchors { top: true; left: true; right: true }
        implicitHeight: root.barSize
        exclusiveZone: root.barSize
        color: "transparent"
        WlrLayershell.namespace: "omarchy-cupertino-bar"
        WlrLayershell.layer: WlrLayer.Top

        Rectangle {
          anchors.fill: parent
          color: Qt.rgba(root.background.r, root.background.g, root.background.b, root.settings.bar_opacity / 100)
        }

        RowLayout {
          anchors.left: parent.left
          anchors.leftMargin: 12
          anchors.verticalCenter: parent.verticalCenter
          spacing: 10

          WidgetSlot { entry: ({ id: "omarchy.menu" }) }

          Text {
            readonly property var toplevel: ToplevelManager.activeToplevel
            readonly property string appId: toplevel ? String(toplevel.appId || "") : ""
            readonly property var desktopEntry: {
              var revision = DesktopEntries.applications.values.length
              return appId ? DesktopEntries.heuristicLookup(appId) : null
            }

            text: desktopEntry && desktopEntry.name ? desktopEntry.name : appId
            textFormat: Text.PlainText
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: 13
            font.letterSpacing: 0.4
            font.weight: Font.Bold
          }
        }

        RowLayout {
          anchors.right: parent.right
          anchors.rightMargin: 5
          anchors.verticalCenter: parent.verticalCenter
          spacing: 0

          Repeater {
            model: ScriptModel { values: root.statusEntries.keys }
            delegate: WidgetSlot {
              required property string modelData
              entry: root.statusEntries.entries[modelData] || ({ id: "" })
              itemScale: root.settings.status_icon_scale / 100
              cellWidth: root.settings.status_item_width
            }
          }

          WidgetSlot {
            Layout.leftMargin: 3
            entry: root.clockEntry
          }
        }

        PopupWindow {
          id: tooltipWindow

          visible: !tooltipTimer.running && root.tooltipText !== "" && root.targetBelongsToWindow(root.tooltipTarget, barWindow)
          color: "transparent"
          implicitWidth: Math.ceil(tooltipLabel.implicitWidth + 20)
          implicitHeight: Math.ceil(tooltipLabel.implicitHeight + 12)

          anchor {
            id: tooltipAnchor
            window: barWindow
            adjustment: PopupAdjustment.Slide
            edges: Edges.Top | Edges.Left
            gravity: Edges.Bottom | Edges.Right
            rect.width: 1
            rect.height: 1
            onAnchoring: {
              var target = root.tooltipTarget
              if (!root.targetBelongsToWindow(target, barWindow)) return
              var point = barWindow.contentItem.mapFromItem(target, target.width / 2 - tooltipWindow.implicitWidth / 2, target.height + 6)
              tooltipAnchor.rect.x = Math.round(point.x)
              tooltipAnchor.rect.y = Math.round(point.y)
            }
          }

          Rectangle {
            anchors.fill: parent
            radius: Style.cornerRadius
            color: Commons.Color.tooltip.background
            border.color: Commons.Color.tooltip.border
            border.width: 1

            Text {
              id: tooltipLabel
              anchors.centerIn: parent
              text: root.tooltipText
              textFormat: Text.PlainText
              color: Commons.Color.tooltip.text
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }
      }
    }
  }
}
