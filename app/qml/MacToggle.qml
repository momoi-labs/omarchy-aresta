import QtQuick

Rectangle {
  id: toggle

  required property Theme ui
  property bool checked: false
  signal toggled(bool value)

  implicitWidth: 40
  implicitHeight: 24
  radius: height / 2
  color: checked ? ui.accent : ui.control
  activeFocusOnTab: true
  border.width: activeFocus ? 2 : 0
  border.color: Qt.alpha(ui.accent, 0.5)

  Behavior on color { ColorAnimation { duration: 120 } }

  Rectangle {
    x: toggle.checked ? toggle.width - width - 2 : 2
    y: 2
    width: 24
    height: toggle.height - 4
    radius: height / 2
    color: toggle.ui.knob
    border.width: 1
    border.color: toggle.ui.knobBorder
    Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: toggle.toggled(!toggle.checked)
  }

  Keys.onSpacePressed: toggle.toggled(!toggle.checked)
}
