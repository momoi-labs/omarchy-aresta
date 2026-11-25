pragma ComponentBehavior: Bound

import QtQuick
import Cupertino as App

Item {
  id: row

  required property Theme ui
  required property App.Backend backend
  required property var setting
  property bool first: false

  readonly property int revision: backend.revision
  readonly property bool recording: setting.type === "shortcut" && backend.recording === setting.key
  readonly property bool missing: setting.type === "plugin" && !backend.pluginInstalled(setting.plugin)
  readonly property bool auto: revision >= 0 && setting.type === "appearance" && backend.flag("appearance_auto")
  readonly property string hint: {
    if (missing) return qsTr("Not installed. Run install.sh to add it to ~/.config/omarchy/plugins.")
    if (recording) return qsTr("Esc cancels. Backspace removes the shortcut.")
    if (setting.type === "theme") {
      let count = Array.from(backend.themeNames(setting.dark)).length
      return setting.dark ? qsTr("%n dark theme(s) installed", "", count) : qsTr("%n light theme(s) installed", "", count)
    }
    if (auto) {
      if (backend.autoError !== "") return qsTr("No location. Auto changes nothing until weather.json or the network gives one.")
      if (backend.autoNext <= 0) return qsTr("Finding sunrise and sunset...")
      let next = new Date(backend.autoNext)
      let day = next.toDateString() === new Date().toDateString() ? qsTr("today") : Qt.formatDate(next, "ddd")
      return (backend.autoNextDark ? qsTr("Switches to Dark %1 at %2, at sunset") : qsTr("Switches to Light %1 at %2, at sunrise"))
        .arg(day).arg(Qt.formatTime(next, "HH:mm"))
    }
    return setting.hint || ""
  }

  readonly property bool available: !setting.requires || (revision >= 0
    && (setting.requires.plugin ? backend.pluginEnabled(setting.requires.plugin) : backend.flag(setting.requires)))

  enabled: available
  opacity: available ? 1 : 0.4
  implicitHeight: Math.max(42, labels.implicitHeight + 14, control.implicitHeight + 14)

  Rectangle {
    visible: !row.first
    x: 12
    width: parent.width - 24
    height: 1
    color: row.ui.separator
  }

  Column {
    id: labels
    x: 12
    width: parent.width - 24 - control.width - 14
    anchors.verticalCenter: parent.verticalCenter

    Text {
      width: parent.width
      text: row.setting.label
      color: row.ui.text
      font.family: row.ui.fontFamily
      font.pixelSize: 13
      wrapMode: Text.Wrap
    }

    Text {
      visible: row.hint !== ""
      width: parent.width
      topPadding: 1
      text: row.hint
      color: row.ui.textSecondary
      font.family: row.ui.fontFamily
      font.pixelSize: 11
      wrapMode: Text.Wrap
    }
  }

  Loader {
    id: control
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    sourceComponent: {
      switch (row.setting.type) {
      case "toggle": return toggleControl
      case "plugin": return pluginControl
      case "slider": return sliderControl
      case "stepper": return stepperControl
      case "select": return selectControl
      case "text": return textControl
      case "shortcut": return shortcutControl
      case "omarchy": return omarchyControl
      case "segment": return segmentControl
      case "appearance": return appearanceControl
      case "theme": return themeControl
      case "clear": return clearControl
      }
      return null
    }
  }

  Component {
    id: toggleControl
    MacToggle {
      ui: row.ui
      checked: row.revision >= 0 && row.backend.flag(row.setting.key)
      onToggled: value => row.backend.setFlag(row.setting.key, value)
    }
  }

  Component {
    id: pluginControl
    MacToggle {
      ui: row.ui
      enabled: !row.missing
      opacity: enabled ? 1 : 0.4
      checked: row.revision >= 0 && row.backend.pluginEnabled(row.setting.plugin)
      onToggled: value => row.backend.setPluginEnabled(row.setting.plugin, value, row.setting.fallback || "")
    }
  }

  Component {
    id: sliderControl
    MacSlider {
      ui: row.ui
      from: row.setting.min
      to: row.setting.max
      stepSize: row.setting.step || 1
      unit: row.setting.unit || ""
      value: row.revision >= 0 ? row.backend.number(row.setting.key) : 0
      onMoved: value => row.backend.setNumber(row.setting.key, value)
    }
  }

  Component {
    id: stepperControl
    MacStepper {
      ui: row.ui
      from: row.setting.min
      to: row.setting.max
      stepSize: row.setting.step || 1
      unit: row.setting.unit || ""
      value: row.revision >= 0 ? row.backend.number(row.setting.key) : 0
      onMoved: value => row.backend.setNumber(row.setting.key, value)
    }
  }

  Component {
    id: selectControl
    MacSelect {
      ui: row.ui
      options: row.setting.options
      value: row.revision >= 0 ? row.backend.text(row.setting.key) : ""
      onPicked: value => row.backend.setText(row.setting.key, value)
    }
  }

  Component {
    id: textControl
    Rectangle {
      implicitWidth: 190
      implicitHeight: 26
      radius: 7
      color: row.ui.controlSoft
      border.width: 1
      border.color: input.activeFocus ? row.ui.accent : row.ui.controlBorder

      TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 9
        anchors.rightMargin: 9
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        text: row.revision >= 0 ? row.backend.text(row.setting.key) : ""
        color: row.ui.text
        selectionColor: row.ui.accent
        selectedTextColor: row.ui.accentText
        font.family: "monospace"
        font.pixelSize: 12
        onEditingFinished: row.backend.setText(row.setting.key, text)
      }
    }
  }

  Component {
    id: shortcutControl
    ShortcutKeys {
      ui: row.ui
      labels: row.revision >= 0 ? row.backend.shortcutLabels(row.setting.key) : []
      recording: row.recording
      onClicked: row.backend.startRecording(row.setting.key)
      onCancelled: row.backend.stopRecording()
    }
  }

  Component {
    id: omarchyControl
    ShortcutKeys {
      ui: row.ui
      labels: row.setting.keys
      locked: true
    }
  }

  Component {
    id: segmentControl
    MacSegmented {
      ui: row.ui
      options: row.setting.options
      value: row.revision >= 0 ? row.backend.text(row.setting.key) : ""
      onPicked: value => row.backend.setText(row.setting.key, value)
    }
  }

  Component {
    id: appearanceControl
    MacSegmented {
      ui: row.ui
      options: [
        { value: "light", label: qsTr("Light") },
        { value: "dark", label: qsTr("Dark") },
        { value: "auto", label: qsTr("Auto") }
      ]
      value: row.auto ? "auto" : row.backend.themeDark(row.backend.themeName) ? "dark" : "light"
      onPicked: value => row.backend.setAppearance(value)
    }
  }

  Component {
    id: clearControl
    Rectangle {
      implicitWidth: clearLabel.implicitWidth + 24
      implicitHeight: 26
      radius: 7
      color: clearArea.pressed ? row.ui.control : row.ui.controlSoft
      border.width: 1
      border.color: row.ui.controlBorder

      Text {
        id: clearLabel
        anchors.centerIn: parent
        text: row.setting.button
        color: row.ui.text
        font.family: row.ui.fontFamily
        font.pixelSize: 13
      }

      MouseArea {
        id: clearArea
        anchors.fill: parent
        onClicked: row.setting.keys.forEach(key => row.backend.clearList(key))
      }
    }
  }

  Component {
    id: themeControl
    ThemePicker {
      ui: row.ui
      backend: row.backend
      names: row.revision >= 0 ? row.backend.themeNames(row.setting.dark) : []
      value: row.revision >= 0 ? row.backend.text(row.setting.key) : ""
      onPicked: name => row.backend.pickTheme(row.setting.dark, name)
    }
  }
}
