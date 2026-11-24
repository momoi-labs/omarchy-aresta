pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
  id: control

  required property Theme ui
  property var options: []
  property string value: ""
  signal picked(string value)

  readonly property int currentIndex: {
    for (var i = 0; i < options.length; i++)
      if (options[i].value === value) return i
    return -1
  }

  implicitWidth: row.implicitWidth + 4
  implicitHeight: 28
  radius: 8
  color: ui.controlSoft
  border.width: activeFocus ? 2 : 0
  border.color: Qt.alpha(ui.accent, 0.5)
  activeFocusOnTab: true

  function step(delta) {
    var next = Math.max(0, Math.min(options.length - 1, currentIndex + delta))
    if (next !== currentIndex) picked(options[next].value)
  }

  Keys.onLeftPressed: step(-1)
  Keys.onRightPressed: step(1)

  Row {
    id: row
    x: 2
    anchors.verticalCenter: parent.verticalCenter

    Repeater {
      model: control.options

      Rectangle {
        id: segment
        required property var modelData
        required property int index
        readonly property bool selected: index === control.currentIndex

        width: label.implicitWidth + 24
        height: control.height - 4
        radius: 6
        color: selected ? (control.ui.luminance(control.ui.background) > 0.5 ? "#ffffff" : control.ui.key) : "transparent"
        border.width: selected ? 1 : 0
        border.color: control.ui.controlBorder

        Text {
          id: label
          anchors.centerIn: parent
          text: segment.modelData.label
          color: segment.selected ? control.ui.text : control.ui.textSecondary
          font.family: control.ui.fontFamily
          font.pixelSize: 13
          font.weight: segment.selected ? Font.DemiBold : Font.Normal
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: control.picked(segment.modelData.value)
        }
      }
    }
  }
}
