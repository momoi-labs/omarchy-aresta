pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs
import QtQuick.Shapes
import QtQuick.Window
import Cupertino as App

Window {
  id: window

  width: 1040
  height: 690
  minimumWidth: 760
  minimumHeight: 480
  visible: true
  title: qsTr("Cupertino Settings")
  color: look.window

  property string panel: "appearance"
  property var back: []
  property var forward: []
  property string query: ""
  property string target: ""

  readonly property var titleAlignOptions: [
    { value: "left", label: qsTr("Left") },
    { value: "center", label: qsTr("Center") },
    { value: "right", label: qsTr("Right") }
  ]

  readonly property var buttonPositionOptions: [
    { value: "left", label: qsTr("Left") },
    { value: "right", label: qsTr("Right") }
  ]

  readonly property var desktopPositions: [
    { value: "menus", label: qsTr("After the menus") },
    { value: "center", label: qsTr("Center") },
    { value: "status", label: qsTr("Before the status icons") }
  ]

  readonly property var desktopStyles: [
    { value: "numbers", label: qsTr("Numbers") },
    { value: "dots", label: qsTr("Dots") }
  ]

  readonly property var selectionColors: [
    { value: "gray", label: qsTr("Gray") },
    { value: "accent", label: qsTr("Theme accent") }
  ]

  readonly property var previewDesktops: [
    { id: 1, occupied: true, current: false },
    { id: 2, occupied: true, current: true },
    { id: 3, occupied: false, current: false },
    { id: 4, occupied: true, current: false },
    { id: 5, occupied: false, current: false }
  ]

  component Desktops: Row {
    id: desktops
    required property Theme ui
    required property color ink
    property var items: []
    property string style: "numbers"
    property bool occupiedOnly: false
    spacing: style === "dots" ? 7 : 3

    Repeater {
      model: desktops.items.filter(function(item) { return !desktops.occupiedOnly || item.occupied || item.current })

      Item {
        id: desktop
        required property var modelData
        width: desktops.style === "dots" ? (modelData.current ? 18 : 7) : 20
        height: 18

        Rectangle {
          visible: desktops.style === "numbers" && desktop.modelData.current
          anchors.fill: parent
          radius: 5
          color: desktops.ui.accent
        }

        Text {
          visible: desktops.style === "numbers"
          anchors.centerIn: parent
          text: desktop.modelData.id
          color: desktop.modelData.current ? desktops.ui.accentText : desktop.modelData.occupied ? desktops.ink : Qt.alpha(desktops.ink, 0.4)
          font.family: desktops.ui.fontFamily
          font.pixelSize: 12
          font.weight: desktop.modelData.current ? Font.Bold : Font.Medium
        }

        Rectangle {
          visible: desktops.style === "dots"
          anchors.centerIn: parent
          width: parent.width
          height: 7
          radius: 3.5
          color: desktop.modelData.current ? desktops.ui.accent : desktop.modelData.occupied ? Qt.alpha(desktops.ink, 0.7) : "transparent"
          border.width: desktop.modelData.current || desktop.modelData.occupied ? 0 : 1.2
          border.color: Qt.alpha(desktops.ink, 0.6)
        }
      }
    }
  }

  readonly property string themeTitle: store.themeTitle(store.themeName)

  function fileUrl(path) {
    return path === "" ? "" : "file://" + path.split("/").map(encodeURIComponent).join("/")
  }

  function localPath(url) {
    return decodeURIComponent(url.toString().replace(/^file:\/\//, ""))
  }

  function pictureName(path) {
    var base = path.split("/").pop().replace(/\.[^.]*$/, "")
    return base.split(/[-_ ]+/).filter(function(word) { return word !== "" })
      .map(function(word) { return word.charAt(0).toUpperCase() + word.slice(1) }).join(" ")
  }

  readonly property var sections: [
    { id: "appearance", name: qsTr("Appearance"), block: 1, groups: [
      { title: qsTr("Appearance"), rows: [
        { type: "appearance", label: qsTr("Appearance"), hint: qsTr("Auto follows sunrise and sunset") },
        { type: "theme", key: "light_theme", dark: false, label: qsTr("Light theme") },
        { type: "theme", key: "dark_theme", dark: true, label: qsTr("Dark theme") }
      ], note: qsTr("Each list shows only themes of its mode. \"osx light\" and \"osx dark\" are the defaults.") },
      { kind: "colors", rows: [{ type: "colors", label: qsTr("Colors"), hint: qsTr("Colors of the current theme") }] },
      { title: qsTr("Windows"), rows: [{ type: "toggle", key: "shadow_enabled", label: qsTr("Show window shadows"), hint: qsTr("Floating workspaces always show shadows") }] }
    ] },
    { id: "wallpaper", name: qsTr("Wallpaper"), block: 1, groups: [
      { rows: [
        { type: "wallpaper", label: qsTr("Current wallpaper") },
        { type: "toggle", key: "wallpaper_keep", label: qsTr("Keep this wallpaper when the theme changes"), hint: qsTr("Off: each theme shows its own wallpaper, as Omarchy does by default") }
      ] },
      { kind: "sources", rows: [{ label: qsTr("Add Photo"), hint: qsTr("Add Folder") }] }
    ] },
    { id: "menubar", name: qsTr("Menu Bar"), block: 1, groups: [
      { rows: [
        { type: "plugin", plugin: "dev.momoi-labs.omarchy-cupertino", fallback: "omarchy.bar", label: qsTr("Use the Cupertino menu bar"), hint: qsTr("Off brings back the Omarchy bar") }
      ] },
      { title: qsTr("Desktops"), rows: [
        { type: "bar", label: qsTr("Menu bar preview") },
        { type: "toggle", key: "bar_desktops", label: qsTr("Show desktops in the menu bar"), hint: qsTr("Click a desktop to go there. Scroll over the row to move to the next one.") },
        { type: "segment", key: "bar_desktops_position", label: qsTr("Position"), options: desktopPositions },
        { type: "segment", key: "bar_desktops_style", label: qsTr("Style"), options: desktopStyles },
        { type: "toggle", key: "bar_desktops_occupied_only", label: qsTr("Only desktops with windows"), hint: qsTr("The current desktop always shows") }
      ], note: qsTr("Desktops are the Hyprland workspaces of this monitor. In the preview: desktop 2 is current, 1 and 4 have windows, 3 and 5 are empty.") },
      { rows: [
        { type: "slider", key: "bar_opacity", label: qsTr("Menu bar background opacity"), hint: qsTr("Uses your theme background color"), min: 0, max: 100, step: 5, unit: "%" }
      ] },
      { title: qsTr("Clock"), rows: [
        { type: "text", key: "clock_format", label: qsTr("Clock format"), hint: qsTr("Qt date format, like ddd d MMM  HH:mm") }
      ] }
    ] },
    { id: "titlebars", name: qsTr("Title Bars"), block: 1, groups: [
      { rows: [
        { type: "toggle", key: "traffic_lights_enabled", label: qsTr("Use the Cupertino title bars") },
        { type: "titlebars", label: qsTr("Title bar preview") }
      ] },
      { title: qsTr("Windows"), rows: [
        { type: "toggle", key: "title_bars_always", requires: "traffic_lights_enabled", label: qsTr("Always show title bars"), hint: qsTr("Show on tiled windows too, not only on floating workspaces") },
        { type: "segment", key: "traffic_lights_position", requires: "traffic_lights_enabled", label: qsTr("Button position"), options: buttonPositionOptions },
        { type: "toggle", key: "traffic_lights_grey_inactive", requires: "traffic_lights_enabled", label: qsTr("Grey traffic lights on unfocused windows") },
        { type: "toggle", key: "traffic_light_icons_on_hover", requires: "traffic_lights_enabled", label: qsTr("Show icons in traffic lights on hover") },
        { type: "select", key: "title_align", requires: "traffic_lights_enabled", label: qsTr("Window title alignment"), options: titleAlignOptions },
        { type: "stepper", key: "traffic_light_size", requires: "traffic_lights_enabled", label: qsTr("Traffic light size"), min: 8, max: 24, unit: "px" }
      ] }
    ] },
    { id: "keyboard", name: qsTr("Keyboard"), block: 2, groups: [
      { title: qsTr("Keyboard Shortcuts"), rows: [
        { type: "toggle", key: "quit_enabled", label: qsTr("Use Quit app"), hint: qsTr("Off brings back Omarchy's Super+Q, which closes only the window") },
        { type: "shortcut", key: "shortcut_quit", label: qsTr("Quit app"), hint: qsTr("Closes every window of the app, on all workspaces") },
        { type: "toggle", key: "cycle_enabled", label: qsTr("Use Cycle windows"), hint: qsTr("Off brings back Omarchy's Super+`, which toggles the Quake console") },
        { type: "shortcut", key: "shortcut_cycle", label: qsTr("Cycle windows of the same app"), hint: qsTr("Skips minimized windows") }
      ] },
      { title: qsTr("App Switcher"), rows: [
        { type: "toggle", key: "switcher_enabled", label: qsTr("Use the Cupertino app switcher"), hint: qsTr("Off brings back Omarchy's Super+Tab and Super+Shift+Tab, which go to the next and previous workspace") },
        { type: "shortcut", key: "shortcut_switcher_next", label: qsTr("Switch apps"), hint: qsTr("Hold the first modifier to keep the switcher open") },
        { type: "shortcut", key: "shortcut_switcher_previous", label: qsTr("Switch apps backwards") }
      ] },
      { title: qsTr("Windows"), rows: [
        { type: "omarchy", label: qsTr("Close window"), keys: ["Super", "W"] },
        { type: "omarchy", label: qsTr("Minimize to the Dock"), keys: ["Super", "M"] }
      ], note: qsTr("Omarchy owns these two. Change them in the Omarchy keybindings.") },
      { title: qsTr("Quake Console"), rows: [
        { type: "toggle", key: "quake_enabled", label: qsTr("Use Cupertino Quake console keys"), hint: qsTr("Off brings back Omarchy's Super+Shift+`. Super+` toggles the console while Cycle windows is off.") },
        { type: "shortcut", key: "shortcut_quake_toggle", label: qsTr("Toggle Quake console") },
        { type: "shortcut", key: "shortcut_quake_move", label: qsTr("Move window to Quake console") }
      ] }
    ] },
    { id: "spotlight", name: qsTr("Spotlight"), block: 2, groups: [
      { rows: [
        { type: "plugin", plugin: "dev.momoi-labs.omarchy-cupertino.menu", label: qsTr("Use Cupertino Spotlight"), hint: qsTr("Off brings back the Omarchy menu") },
        { type: "slider", key: "spotlight_size", label: qsTr("Size"), min: 80, max: 150, step: 10, unit: "%" },
        { type: "segment", key: "spotlight_selection", label: qsTr("Selection color"), options: selectionColors },
        { type: "toggle", key: "spotlight_filters", label: qsTr("Show filters"), hint: qsTr("Buttons under the search field. Ctrl+1 to Ctrl+9 work either way.") },
        { type: "toggle", key: "spotlight_menu_on_open", label: qsTr("Show menu on open"), hint: qsTr("Off opens only the search field until you type") },
        { type: "toggle", key: "spotlight_shortcuts", label: qsTr("Show shortcuts"), hint: qsTr("Keyboard hints at the bottom of the card") },
        { type: "toggle", key: "spotlight_movable", label: qsTr("Movable"), hint: qsTr("Drag the card to move it, or its top or bottom edge to change its height. It opens that way next time.") },
        { type: "clear", keys: ["spotlight_position", "spotlight_height"], label: qsTr("Position"), hint: qsTr("Saved for each display"), button: qsTr("Reset position") }
      ] }
    ] },
    { id: "cupertino", name: qsTr("Cupertino"), block: 3, lead: qsTr("Options that macOS System Settings does not have."), groups: [
      { title: qsTr("Window Corners"), rows: [
        { type: "toggle", key: "corners_enabled", label: qsTr("Rounded corners"), hint: qsTr("Off brings back Omarchy's square corners") },
        { type: "slider", key: "window_rounding", label: qsTr("Window corner radius"), min: 0, max: 24, step: 1, unit: "px" },
        { type: "slider", key: "window_rounding_power", label: qsTr("Window corner shape"), hint: qsTr("2 is a circle arc, 4 is a squircle"), min: 2, max: 5, step: 0.1 }
      ] },
      { title: qsTr("Window Border"), rows: [
        { type: "toggle", key: "border_enabled", label: qsTr("Thin neutral border"), hint: qsTr("Off brings back Omarchy's colored border") },
        { type: "stepper", key: "border_size", label: qsTr("Window border width"), min: 0, max: 8, unit: "px" },
        { type: "slider", key: "border_active_opacity", label: qsTr("Border opacity, focused window"), min: 0, max: 100, step: 5, unit: "%" },
        { type: "slider", key: "border_inactive_opacity", label: qsTr("Border opacity, unfocused window"), min: 0, max: 100, step: 5, unit: "%" }
      ] },
      { title: qsTr("Window Shadow"), rows: [
        { type: "slider", key: "shadow_range", label: qsTr("Shadow size"), min: 0, max: 60, step: 1, unit: "px" },
        { type: "stepper", key: "shadow_offset", label: qsTr("Shadow vertical offset"), min: 0, max: 40, unit: "px" },
        { type: "slider", key: "shadow_active_opacity", label: qsTr("Shadow strength, focused window"), min: 0, max: 100, step: 1, unit: "%" },
        { type: "slider", key: "shadow_inactive_opacity", label: qsTr("Shadow strength, unfocused window"), min: 0, max: 100, step: 1, unit: "%" }
      ] },
      { title: qsTr("Menu Bar"), rows: [
        { type: "stepper", key: "bar_height", label: qsTr("Menu bar height"), min: 20, max: 48, unit: "px" },
        { type: "slider", key: "status_icon_scale", label: qsTr("Status icon size"), min: 100, max: 150, step: 5, unit: "%" },
        { type: "stepper", key: "status_item_width", label: qsTr("Space per status item"), min: 20, max: 60, unit: "px" }
      ] }
    ] }
  ]

  readonly property var currentSection: {
    for (var i = 0; i < sections.length; i++)
      if (sections[i].id === panel) return sections[i]
    return sections[0]
  }

  readonly property var results: {
    var needle = query.trim().toLowerCase()
    var hits = []
    if (!needle) return hits
    for (var s = 0; s < sections.length; s++) {
      var section = sections[s]
      for (var g = 0; g < section.groups.length; g++) {
        var group = section.groups[g]
        for (var r = 0; r < group.rows.length; r++) {
          var item = group.rows[r]
          var haystack = [item.label, item.hint || "", group.title || "", section.name].join(" ").toLowerCase()
          if (haystack.indexOf(needle) !== -1) hits.push({ section: section.id, sectionName: section.name, label: item.label })
        }
      }
    }
    return hits
  }

  function open(id) {
    store.stopRecording()
    if (id !== panel) {
      back = back.concat([panel])
      forward = []
      panel = id
      content.contentY = 0
    }
  }

  function reveal(row) {
    target = ""
    var top = row.mapToItem(page, 0, 0).y - 40
    content.contentY = Math.max(0, Math.min(top, content.contentHeight - content.height))
  }

  function goBack() {
    if (back.length === 0) return
    store.stopRecording()
    forward = forward.concat([panel])
    panel = back[back.length - 1]
    back = back.slice(0, -1)
    content.contentY = 0
  }

  function goForward() {
    if (forward.length === 0) return
    store.stopRecording()
    back = back.concat([panel])
    panel = forward[forward.length - 1]
    forward = forward.slice(0, -1)
    content.contentY = 0
  }

  App.Backend { id: store }

  Theme {
    id: look
    background: store.background
    foreground: store.foreground
    accent: store.accent
  }

  Timer {
    interval: 250
    running: true
    repeat: true
    onTriggered: store.tick()
  }

  onActiveChanged: if (!active) store.stopRecording()
  Component.onDestruction: store.stopRecording()

  Shortcut { enabled: store.recording === ""; sequences: [StandardKey.Find]; onActivated: search.forceActiveFocus() }
  Shortcut { enabled: store.recording === ""; sequences: [StandardKey.Quit, StandardKey.Close]; onActivated: Qt.quit() }
  Shortcut { enabled: store.recording === ""; sequence: "Alt+Left"; onActivated: window.goBack() }
  Shortcut { enabled: store.recording === ""; sequence: "Alt+Right"; onActivated: window.goForward() }

  Item {
    id: recorder
    focus: store.recording !== ""
    onFocusChanged: if (focus) forceActiveFocus()
    Keys.onPressed: event => {
      event.accepted = true
      var plain = (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier | Qt.ShiftModifier)) === 0
      if (plain && event.key === Qt.Key_Escape) store.stopRecording()
      else if (plain && event.key === Qt.Key_Backspace) store.clearShortcut()
      else store.record(event.modifiers, event.nativeScanCode)
    }
  }

  Rectangle {
    id: sidebar

    x: 8
    y: 8
    width: Math.max(232, window.width * 0.276)
    height: parent.height - 16
    radius: 15
    color: look.sidebar
    border.width: 1
    border.color: look.separator

    Rectangle {
      id: searchBox
      x: 10
      y: 12
      width: parent.width - 20
      height: 30
      radius: 15
      color: look.control
      border.width: 1
      border.color: search.activeFocus ? look.accent : look.controlBorder

      Shape {
        x: 10
        y: 8
        width: 14
        height: 14
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeColor: look.textSecondary
          strokeWidth: 1.7
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          PathSvg { path: "M6 2 A4 4 0 1 1 6 10 A4 4 0 1 1 6 2 M9.2 9.2 L12.5 12.5" }
        }
      }

      TextInput {
        id: search
        x: 30
        width: parent.width - 40
        height: parent.height
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: look.text
        selectionColor: look.accent
        selectedTextColor: look.accentText
        font.family: look.fontFamily
        font.pixelSize: 13
        onTextChanged: window.query = text
        Keys.onEscapePressed: { text = ""; focus = false }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: search.text === ""
          text: qsTr("Search")
          color: look.textSecondary
          font: search.font
        }
      }
    }

    ListView {
      id: navigation
      x: 10
      y: searchBox.y + searchBox.height + 12
      width: parent.width - 20
      height: parent.height - y - 10
      visible: window.query.trim() === "" || window.results.length > 0
      clip: true
      spacing: 0
      model: window.query.trim() === "" ? window.sections : window.results

      delegate: Item {
        id: entry
        required property var modelData
        required property int index

        readonly property bool searching: window.query.trim() !== ""
        readonly property string sectionId: searching ? modelData.section : modelData.id
        readonly property bool selected: !searching && window.panel === sectionId
        readonly property bool gap: !searching && index > 0 && window.sections[index - 1].block !== modelData.block

        width: ListView.view.width
        height: item.height + (gap ? 16 : 0)

        Rectangle {
          id: item
          y: entry.gap ? 16 : 0
          width: parent.width
          height: entry.searching ? 40 : 34
          radius: 10
          color: entry.selected ? look.accent : area.containsMouse ? look.hover : "transparent"

          SectionIcon {
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            kind: entry.sectionId
          }

          Column {
            x: 39
            width: parent.width - 47
            anchors.verticalCenter: parent.verticalCenter

            Text {
              width: parent.width
              elide: Text.ElideRight
              text: entry.searching ? entry.modelData.label : entry.modelData.name
              color: entry.selected ? look.accentText : look.text
              font.family: look.fontFamily
              font.pixelSize: 13
            }

            Text {
              visible: entry.searching
              text: entry.searching ? entry.modelData.sectionName : ""
              color: look.textSecondary
              font.family: look.fontFamily
              font.pixelSize: 11
            }
          }

          MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
              window.open(entry.sectionId)
              search.text = ""
              window.target = entry.modelData.label
            }
          }
        }
      }
    }

    Column {
      visible: !navigation.visible
      width: parent.width - 24
      x: 12
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: qsTr("No Results")
        color: look.text
        font.family: look.fontFamily
        font.pixelSize: 15
        font.weight: Font.Bold
      }

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: qsTr("Nothing matches \"%1\". Check the spelling, or search for a section name.").arg(window.query.trim())
        color: look.textSecondary
        font.family: look.fontFamily
        font.pixelSize: 13
      }
    }
  }

  Item {
    id: main
    anchors.left: sidebar.right
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom

    Rectangle {
      id: navPill
      x: 8
      y: 11
      width: 72
      height: 32
      radius: 16
      color: look.box
      border.width: 1
      border.color: look.separator

      Repeater {
        model: [-1, 1]

        Item {
          id: navButton
          required property int modelData
          readonly property bool active: modelData < 0 ? window.back.length > 0 : window.forward.length > 0
          x: modelData < 0 ? 0 : 36
          width: 36
          height: 32

          Shape {
            anchors.centerIn: parent
            width: 8
            height: 13
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
              strokeColor: navButton.active ? look.text : look.textTertiary
              strokeWidth: 1.9
              fillColor: "transparent"
              capStyle: ShapePath.RoundCap
              joinStyle: ShapePath.RoundJoin
              PathSvg { path: navButton.modelData < 0 ? "M6.5 1.5 L1.5 6.5 L6.5 11.5" : "M1.5 1.5 L6.5 6.5 L1.5 11.5" }
            }
          }

          MouseArea {
            anchors.fill: parent
            enabled: navButton.active
            onClicked: navButton.modelData < 0 ? window.goBack() : window.goForward()
          }
        }
      }
    }

    Text {
      anchors.left: navPill.right
      anchors.leftMargin: 12
      anchors.right: errorText.left
      anchors.verticalCenter: navPill.verticalCenter
      text: window.currentSection.name
      color: look.text
      font.family: look.fontFamily
      font.pixelSize: 15
      font.weight: Font.Bold
      elide: Text.ElideRight
    }

    Text {
      id: errorText
      anchors.right: parent.right
      anchors.rightMargin: 24
      anchors.verticalCenter: navPill.verticalCenter
      width: Math.min(implicitWidth, parent.width / 2)
      text: store.error
      color: look.record
      font.family: look.fontFamily
      font.pixelSize: 12
      elide: Text.ElideRight
    }

    Flickable {
      id: content
      anchors.fill: parent
      anchors.topMargin: 54
      anchors.leftMargin: 8
      anchors.rightMargin: 24
      contentHeight: page.implicitHeight + 24
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: page
        width: Math.min(content.width, 720)
        spacing: 20
        topPadding: 2

        Text {
          visible: !!window.currentSection.lead
          leftPadding: 10
          text: window.currentSection.lead || ""
          color: look.textSecondary
          font.family: look.fontFamily
          font.pixelSize: 12
        }

        Repeater {
          model: window.currentSection.groups

          Column {
            id: group
            required property var modelData
            width: page.width
            spacing: 8

            readonly property bool colors: group.modelData.kind === "colors"
            readonly property bool sources: group.modelData.kind === "sources"

            Row {
              id: groupTitle
              visible: !!group.modelData.title || group.colors
              leftPadding: 10
              spacing: 8

              Text {
                id: groupName
                text: group.colors ? qsTr("Colors of %1").arg(window.themeTitle) : group.modelData.title || ""
                color: look.text
                font.family: look.fontFamily
                font.pixelSize: 13
                font.weight: Font.Bold
              }

              Text {
                visible: group.colors
                width: Math.max(0, group.width - groupTitle.leftPadding - groupName.width - groupTitle.spacing - 10)
                elide: Text.ElideMiddle
                text: group.colors ? store.themeFile(store.themeName) : ""
                color: look.textSecondary
                font.family: look.fontFamily
                font.pixelSize: 12
              }
            }

            Loader {
              active: group.sources
              visible: active
              width: parent.width
              sourceComponent: sourcesView
            }

            Rectangle {
              visible: !group.sources
              width: parent.width
              height: rows.implicitHeight
              radius: 12
              color: look.box

              Column {
                id: rows
                width: parent.width

                Repeater {
                  model: group.modelData.rows

                  Loader {
                    id: rowLoader
                    required property var modelData
                    required property int index
                    readonly property bool targeted: window.target !== "" && window.target === modelData.label
                    width: rows.width
                    onTargetedChanged: if (targeted) Qt.callLater(window.reveal, rowLoader)
                    sourceComponent: group.sources ? null
                      : modelData.type === "colors" ? colorsRow
                      : modelData.type === "wallpaper" ? wallpaperRow
                      : modelData.type === "bar" ? barRow
                      : modelData.type === "titlebars" ? titleBarsRow : settingRow

                    Component {
                      id: settingRow
                      SettingRow {
                        ui: look
                        backend: store
                        setting: rowLoader.modelData
                        first: rowLoader.index === 0
                      }
                    }
                  }
                }
              }
            }

            Text {
              visible: !!group.modelData.note
              width: parent.width
              leftPadding: 10
              rightPadding: 10
              text: group.modelData.note || ""
              color: look.textSecondary
              font.family: look.fontFamily
              font.pixelSize: 12
              wrapMode: Text.Wrap
            }
          }
        }
      }
    }
  }

  FileDialog {
    id: photoDialog
    title: qsTr("Add Photo")
    nameFilters: [qsTr("Pictures (*.jpg *.jpeg *.png *.gif *.bmp *.webp)")]
    onAccepted: store.addPhoto(window.localPath(selectedFile))
  }

  FolderDialog {
    id: folderDialog
    title: qsTr("Add Folder")
    onAccepted: store.addFolder(window.localPath(selectedFolder))
  }

  Component {
    id: colorsRow

    Item {
      id: colors
      readonly property var palette: store.themePalette(store.themeName)
      readonly property int columns: Math.max(3, Math.min(7, Math.floor((width - 16) / 84)))
      readonly property real swatchWidth: (width - 24 - (columns - 1) * 8) / columns
      implicitHeight: header.height + swatches.implicitHeight + 28

      function label(key) {
        return key.split("_").map(function(word) { return word.charAt(0).toUpperCase() + word.slice(1) }).join(" ")
      }

      Item {
        id: header
        width: parent.width
        height: 104

        ThemeTile {
          x: 12
          y: 12
          ui: look
          tileWidth: 112
          tileHeight: 70
          colors: store.themeColors(store.themeName)
        }

        Column {
          x: 144
          width: parent.width - x - 12
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2

          Text {
            text: window.themeTitle
            color: look.text
            font.family: look.fontFamily
            font.pixelSize: 14
          }

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: (store.themeDark(store.themeName) ? qsTr("Dark theme, background luminance %1") : qsTr("Light theme, background luminance %1"))
              .arg(Math.round(store.themeLuminance(store.themeName) * 100) / 100)
            color: look.textSecondary
            font.family: look.fontFamily
            font.pixelSize: 12
          }
        }

        Rectangle {
          anchors.bottom: parent.bottom
          width: parent.width
          height: 1
          color: look.separator
        }
      }

      Flow {
        id: swatches
        x: 12
        y: header.height + 14
        width: parent.width - 24
        spacing: 8

        Repeater {
          model: colors.palette

          Column {
            id: swatch
            required property string modelData
            width: colors.swatchWidth
            spacing: 2

            Rectangle {
              width: parent.width
              height: 26
              radius: 6
              color: swatch.modelData.split("|")[1]
              border.width: 1
              border.color: look.controlBorder
            }

            Text {
              width: parent.width
              elide: Text.ElideRight
              text: colors.label(swatch.modelData.split("|")[0])
              color: look.text
              font.family: look.fontFamily
              font.pixelSize: 11
            }

            Text {
              text: swatch.modelData.split("|")[1]
              color: look.textSecondary
              font.family: look.fontFamily
              font.pixelSize: 10
            }
          }
        }
      }
    }
  }

  Component {
    id: wallpaperRow

    Item {
      implicitHeight: 158

      Rectangle {
        id: picture
        x: 14
        y: 14
        width: 208
        height: 130
        radius: 8
        color: look.controlSoft
        clip: true

        RoundedImage {
          radius: 8
          anchors.fill: parent
          source: window.fileUrl(store.currentWallpaper)
          sourceSize.width: 416
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
        }
      }

      Column {
        anchors.left: picture.right
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: picture.verticalCenter
        spacing: 4

        Text {
          width: parent.width
          elide: Text.ElideRight
          text: store.currentWallpaper === "" ? qsTr("No wallpaper") : window.pictureName(store.currentWallpaper)
          color: look.text
          font.family: look.fontFamily
          font.pixelSize: 15
          font.weight: Font.DemiBold
        }

        Text {
          width: parent.width
          elide: Text.ElideMiddle
          text: store.shortPath(store.currentWallpaper)
          color: look.textSecondary
          font.family: look.fontFamily
          font.pixelSize: 12
        }

        Text {
          topPadding: 6
          text: store.revision >= 0 && store.flag("wallpaper_keep") ? qsTr("Stays when you change the theme.") : qsTr("Changes with the theme.")
          color: look.textSecondary
          font.family: look.fontFamily
          font.pixelSize: 12
        }
      }
    }
  }

  Component {
    id: sourcesView

    Column {
      id: sources
      spacing: 20
      readonly property int perRow: Math.max(1, Math.floor((width - 20 + 10) / 138))

      Repeater {
        model: store.revision >= 0 && store.themeName !== "-" ? store.wallpaperSources() : []

        Column {
          id: source
          required property string modelData
          readonly property var parts: modelData.split("\t")
          readonly property var images: store.revision >= 0 ? store.wallpaperImages(parts[2]) : []
          property bool expanded: false
          width: sources.width
          spacing: 8

          Item {
            width: parent.width
            height: 18

            Row {
              x: 10
              spacing: 8
              anchors.verticalCenter: parent.verticalCenter

              Text {
                text: source.parts[0]
                color: look.text
                font.family: look.fontFamily
                font.pixelSize: 13
                font.weight: Font.Bold
              }

              Text {
                text: source.parts[1] !== "" ? source.parts[1] : store.shortPath(source.parts[2]) + "/"
                color: look.textSecondary
                font.family: look.fontFamily
                font.pixelSize: 12
              }
            }

            Text {
              visible: source.images.length > sources.perRow
              anchors.right: parent.right
              anchors.rightMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              text: source.expanded ? qsTr("Show Less") : qsTr("Show All (%1)").arg(source.images.length)
              color: look.accent
              font.family: look.fontFamily
              font.pixelSize: 12

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: source.expanded = !source.expanded
              }
            }
          }

          Rectangle {
            width: parent.width
            height: source.images.length > 0 ? thumbs.implicitHeight + 20 : empty.implicitHeight + 32
            radius: 12
            color: look.box

            Text {
              id: empty
              visible: source.images.length === 0
              x: 14
              width: parent.width - 28
              anchors.verticalCenter: parent.verticalCenter
              wrapMode: Text.Wrap
              textFormat: Text.StyledText
              text: qsTr("Nothing here yet. Add Photo copies a picture into <tt>%1/</tt>.").arg(store.shortPath(source.parts[2]))
              color: look.textSecondary
              font.family: look.fontFamily
              font.pixelSize: 12
            }

            Flow {
              id: thumbs
              x: 10
              y: 10
              width: parent.width - 20
              spacing: 10

              Repeater {
                model: source.expanded ? source.images : source.images.slice(0, sources.perRow)

                Item {
                  id: thumb
                  required property string modelData
                  readonly property bool current: modelData === store.currentWallpaper
                  width: 128
                  height: 100

                  Rectangle {
                    x: -3
                    y: -3
                    width: 134
                    height: 86
                    radius: 10
                    color: "transparent"
                    border.width: 3
                    border.color: thumb.current ? look.accent : "transparent"
                  }

                  Rectangle {
                    width: 128
                    height: 80
                    radius: 7
                    color: look.controlSoft
                    border.width: 1
                    border.color: look.separator
                    clip: true

                    RoundedImage {
                      radius: 6
                      anchors.fill: parent
                      anchors.margins: 1
                      source: window.fileUrl(thumb.modelData)
                      sourceSize.width: 256
                      fillMode: Image.PreserveAspectCrop
                      asynchronous: true
                    }
                  }

                  Text {
                    y: 84
                    width: parent.width
                    horizontalAlignment: thumb.current ? Text.AlignHCenter : Text.AlignLeft
                    elide: Text.ElideRight
                    text: window.pictureName(thumb.modelData)
                    color: thumb.current ? look.text : look.textSecondary
                    font.family: look.fontFamily
                    font.pixelSize: 11
                    font.weight: thumb.current ? Font.Bold : Font.Normal
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: store.setWallpaper(thumb.modelData)
                  }
                }
              }
            }
          }
        }
      }

      Row {
        anchors.right: parent.right
        spacing: 8

        Repeater {
          model: [
            { label: qsTr("Add Folder…"), dialog: folderDialog },
            { label: qsTr("Add Photo…"), dialog: photoDialog }
          ]

          Rectangle {
            id: button
            required property var modelData
            width: buttonLabel.implicitWidth + 24
            height: 26
            radius: 7
            color: buttonArea.pressed ? look.control : look.controlSoft
            border.width: 1
            border.color: look.controlBorder

            Text {
              id: buttonLabel
              anchors.centerIn: parent
              text: button.modelData.label
              color: look.text
              font.family: look.fontFamily
              font.pixelSize: 13
            }

            MouseArea {
              id: buttonArea
              anchors.fill: parent
              onClicked: button.modelData.dialog.open()
            }
          }
        }
      }
    }
  }

  Component {
    id: barRow

    Item {
      id: preview
      readonly property bool shown: store.revision >= 0 && store.flag("bar_desktops")
      readonly property string position: store.revision >= 0 ? store.text("bar_desktops_position") : ""
      readonly property string style: store.revision >= 0 ? store.text("bar_desktops_style") : ""
      readonly property bool occupiedOnly: store.revision >= 0 && store.flag("bar_desktops_occupied_only")
      readonly property color ink: look.text
      implicitHeight: 174

      Timer {
        id: minute
        property date now: new Date()
        interval: 1000
        running: true
        repeat: true
        onTriggered: now = new Date()
      }

      Rectangle {
        x: 12
        y: 12
        width: parent.width - 24
        height: 150
        radius: 10
        color: look.controlSoft
        border.width: 1
        border.color: look.separator
        clip: true

        RoundedImage {
          radius: 9
          anchors.fill: parent
          anchors.margins: 1
          source: window.fileUrl(store.currentWallpaper)
          sourceSize.width: 1400
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
        }

        Rectangle {
          id: strip
          x: 1
          y: 1
          width: parent.width - 2
          height: 28
          topLeftRadius: 9
          topRightRadius: 9
          color: Qt.alpha(look.background, (store.revision >= 0 ? store.number("bar_opacity") : 80) / 100)

          Row {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: 13
              height: 13
              radius: 3
              color: "transparent"
              border.width: 1.3
              border.color: preview.ink
            }

            Repeater {
              model: strip.width >= 560 ? [qsTr("Ghostty"), qsTr("File"), qsTr("Edit"), qsTr("View")] : [qsTr("Ghostty")]
              Text {
                required property string modelData
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                text: modelData
                color: preview.ink
                font.family: look.fontFamily
                font.pixelSize: 12
                font.weight: index === 0 ? Font.Bold : Font.Normal
              }
            }

            Desktops {
              visible: preview.shown && preview.position === "menus"
              anchors.verticalCenter: parent.verticalCenter
              ui: look
              ink: preview.ink
              items: window.previewDesktops
              style: preview.style
              occupiedOnly: preview.occupiedOnly
            }
          }

          Desktops {
            visible: preview.shown && preview.position === "center"
            anchors.centerIn: parent
            ui: look
            ink: preview.ink
            items: window.previewDesktops
            style: preview.style
            occupiedOnly: preview.occupiedOnly
          }

          Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16

            Desktops {
              visible: preview.shown && preview.position === "status"
              anchors.verticalCenter: parent.verticalCenter
              ui: look
              ink: preview.ink
              items: window.previewDesktops
              style: preview.style
              occupiedOnly: preview.occupiedOnly
            }

            Shape {
              anchors.verticalCenter: parent.verticalCenter
              width: 16
              height: 12
              preferredRendererType: Shape.CurveRenderer
              ShapePath {
                strokeColor: preview.ink
                strokeWidth: 1.5
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg { path: "M1 4.5 Q8 -1.5 15 4.5 M3.5 7 Q8 3.5 12.5 7 M6 9.5 Q8 8 10 9.5" }
              }
            }

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: 18
              height: 9
              radius: 2.5
              color: "transparent"
              border.width: 1.2
              border.color: preview.ink

              Rectangle { x: 2; y: 2; width: 10; height: 5; radius: 1; color: preview.ink }
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: Qt.formatDateTime(minute.now, store.revision >= 0 ? store.text("clock_format") : "")
              color: preview.ink
              font.family: look.fontFamily
              font.pixelSize: 12
            }
          }
        }
      }
    }
  }

  Component {
    id: titleBarsRow

    Item {
      id: bars
      readonly property bool cupertino: store.revision >= 0 && store.flag("traffic_lights_enabled")
      readonly property bool grey: store.revision >= 0 && store.flag("traffic_lights_grey_inactive")
      readonly property bool hoverIcons: store.revision >= 0 && store.flag("traffic_light_icons_on_hover")
      readonly property string align: store.revision >= 0 ? store.text("title_align") : "center"
      readonly property bool buttonsRight: store.revision >= 0 && store.text("traffic_lights_position") === "right"
      readonly property real lightSize: store.revision >= 0 ? Math.floor(store.number("traffic_light_size")) : 14
      readonly property var themeColors: {
        var map = {}
        var list = store.themePalette(store.themeName)
        for (var i = 0; i < list.length; i++) {
          var parts = list[i].split("|")
          map[parts[0]] = parts[1]
        }
        return map
      }
      readonly property color background: themeColors.background || look.background
      readonly property color foreground: themeColors.foreground || look.foreground
      readonly property color barColor: themeColors.lighter_background && themeColors.lighter_background !== themeColors.background
        ? themeColors.lighter_background : themeColors.selection || background
      readonly property var lights: [
        { icon: "×", color: "#ff5f57" },
        { icon: "−", color: "#febc2e" },
        { icon: "□", color: "#28c840" }
      ]
      implicitHeight: 254

      Rectangle {
        id: desk
        x: 12
        y: 12
        width: parent.width - 24
        height: 230
        radius: 10
        color: look.controlSoft
        border.width: 1
        border.color: look.separator
        clip: true

        RoundedImage {
          radius: 9
          anchors.fill: parent
          anchors.margins: 1
          source: window.fileUrl(store.currentWallpaper)
          sourceSize.width: 1400
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
        }

        Repeater {
          model: [
            { focused: false, title: qsTr("Files"), x: 0.06, y: 22, width: 0.5, height: 140 },
            { focused: true, title: qsTr("Terminal"), x: 0.4, y: 66, width: 0.54, height: 144 }
          ]

          Rectangle {
            id: frame
            required property var modelData
            readonly property bool focused: modelData.focused
            readonly property real lightsWidth: 3 * bars.lightSize + 2 * 8
            readonly property real omarchyWidth: 3 * 20 + 2 * 8
            x: desk.width * modelData.x
            y: modelData.y
            width: desk.width * modelData.width
            height: modelData.height
            radius: 10
            color: bars.barColor
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.18)

            Rectangle {
              x: 1
              y: 30
              width: parent.width - 2
              height: parent.height - 31
              bottomLeftRadius: 9
              bottomRightRadius: 9
              color: bars.background
            }

            Text {
              readonly property bool centered: bars.cupertino && bars.align === "center"
              readonly property bool rightAligned: bars.cupertino && bars.align === "right"
              x: !bars.cupertino ? 10 : centered ? (parent.width - width) / 2 : bars.buttonsRight ? 10 : 26 + frame.lightsWidth
              width: !bars.cupertino ? parent.width - 36 - frame.omarchyWidth
                : centered ? parent.width - 52 - 2 * frame.lightsWidth : parent.width - 36 - frame.lightsWidth
              height: 30
              verticalAlignment: Text.AlignVCenter
              horizontalAlignment: centered ? Text.AlignHCenter : rightAligned ? Text.AlignRight : Text.AlignLeft
              elide: Text.ElideRight
              text: frame.modelData.title
              color: bars.foreground
              font.family: "monospace"
              font.pixelSize: 12
            }

            Row {
              id: lights
              visible: bars.cupertino
              x: bars.buttonsRight ? parent.width - width - 10 : 10
              y: (30 - bars.lightSize) / 2
              spacing: 8

              HoverHandler { id: lightsHover }

              Repeater {
                model: bars.buttonsRight ? bars.lights.slice().reverse() : bars.lights

                Rectangle {
                  id: light
                  required property var modelData
                  width: bars.lightSize
                  height: bars.lightSize
                  radius: Math.floor(bars.lightSize / 2)
                  color: frame.focused || !bars.grey ? modelData.color : "#998e8e93"

                  Text {
                    anchors.centerIn: parent
                    visible: !bars.hoverIcons || lightsHover.hovered
                    text: light.modelData.icon
                    color: "#99000000"
                    font.family: "sans"
                    font.pixelSize: Math.round(bars.lightSize * 0.62)
                  }
                }
              }
            }

            Row {
              visible: !bars.cupertino
              anchors.right: parent.right
              anchors.rightMargin: 10
              y: 5
              spacing: 8

              Repeater {
                model: ["−", "□", "×"]

                Rectangle {
                  id: button
                  required property string modelData
                  width: 20
                  height: 20
                  color: bars.barColor

                  Text {
                    anchors.centerIn: parent
                    text: button.modelData
                    color: bars.foreground
                    font.family: "sans"
                    font.pixelSize: 12
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
