// Copyright (c) 2026 Sebastian Webber
// Licensed under the MIT License. See LICENSE.

import Quickshell
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
  readonly property int barSize: 29
  readonly property string fontFamily: Qt.fontFamilies().indexOf("Inter") !== -1 ? "Inter" : "sans-serif"
  readonly property string clockFormat: "ddd d MMM HH:mm"
  readonly property color foreground: Commons.Color.bar.text
  readonly property color background: Commons.Color.bar.background
  readonly property color urgent: Commons.Color.bar.active

  readonly property var leftOnlyIds: ["omarchy.menu", "omarchy.workspaces", "omarchy.active-window", "omarchy.spacer", "omarchy.clock"]
  readonly property var sectionOrder: ["left", "centerBegin", "center", "centerEnd", "right"]

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
      function summon(id, payloadJson) { return facade.summon(id, payloadJson) }
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

    implicitWidth: activeItem && activeItem.visible ? activeItem.implicitWidth : 0
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
      width: slot.implicitWidth
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
        WlrLayershell.namespace: "omarchy-bar"
        WlrLayershell.layer: WlrLayer.Top

        Rectangle {
          anchors.fill: parent
          color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.6)
        }

        RowLayout {
          anchors.left: parent.left
          anchors.leftMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          spacing: 6

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
            font.weight: Font.Bold
          }
        }

        RowLayout {
          anchors.right: parent.right
          anchors.rightMargin: 12
          anchors.verticalCenter: parent.verticalCenter
          spacing: 0

          Repeater {
            model: ScriptModel { values: root.statusEntries.keys }
            delegate: WidgetSlot {
              required property string modelData
              entry: root.statusEntries.entries[modelData] || ({ id: "" })
            }
          }

          WidgetSlot {
            Layout.leftMargin: 6
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
