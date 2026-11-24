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
  readonly property string hint: {
    if (recording) return qsTr("Esc cancels. Backspace removes the shortcut.")
    if (setting.type === "theme") {
      let count = Array.from(backend.themeNames(setting.dark)).length
      return setting.dark ? qsTr("%n dark theme(s) installed", "", count) : qsTr("%n light theme(s) installed", "", count)
    }
    return setting.hint || ""
  }

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
      case "slider": return sliderControl
      case "stepper": return stepperControl
      case "select": return selectControl
      case "text": return textControl
      case "shortcut": return shortcutControl
      case "omarchy": return omarchyControl
      case "appearance": return appearanceControl
      case "theme": return themeControl
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
    id: appearanceControl
    MacSegmented {
      ui: row.ui
      options: [
        { value: "light", label: qsTr("Light") },
        { value: "dark", label: qsTr("Dark") }
      ]
      value: row.backend.themeDark(row.backend.themeName) ? "dark" : "light"
      onPicked: value => row.backend.setAppearance(value)
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
