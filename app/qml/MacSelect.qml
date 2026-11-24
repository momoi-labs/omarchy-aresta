pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Shapes

Rectangle {
  id: select

  required property Theme ui
  property var options: []
  property string value: ""
  signal picked(string value)

  readonly property string currentLabel: {
    for (var i = 0; i < options.length; i++)
      if (options[i].value === value) return options[i].label
    return value
  }

  implicitWidth: row.implicitWidth + 10
  implicitHeight: 24
  radius: 7
  color: area.containsMouse || menu.opened ? ui.hover : "transparent"
  border.width: activeFocus ? 2 : 0
  border.color: Qt.alpha(ui.accent, 0.6)
  activeFocusOnTab: true
  Keys.onSpacePressed: menu.open()

  Row {
    id: row
    x: 8
    anchors.verticalCenter: parent.verticalCenter
    spacing: 6

    Text {
      text: select.currentLabel
      color: select.ui.textSecondary
      font.family: select.ui.fontFamily
      font.pixelSize: 13
      anchors.verticalCenter: parent.verticalCenter
    }

    Shape {
      width: 10
      height: 14
      anchors.verticalCenter: parent.verticalCenter
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: select.ui.textSecondary
        strokeWidth: 1.6
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        PathSvg { path: "M2 5 L5 2 L8 5 M2 9 L5 12 L8 9" }
      }
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: menu.open()
  }

  Popup {
    id: menu
    y: select.height + 4
    x: select.width - width
    padding: 5
    focus: true

    background: Rectangle {
      radius: 10
      color: select.ui.sidebar
      border.width: 1
      border.color: select.ui.keyBorder
    }

    contentItem: Column {
      Repeater {
        model: select.options

        Rectangle {
          id: option
          required property var modelData
          width: Math.max(140, optionLabel.implicitWidth + 36)
          height: 26
          radius: 6
          color: optionArea.containsMouse ? select.ui.accent : "transparent"

          Text {
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            text: option.modelData.value === select.value ? "✓" : ""
            color: optionArea.containsMouse ? select.ui.accentText : select.ui.text
            font.pixelSize: 12
          }

          Text {
            id: optionLabel
            x: 24
            anchors.verticalCenter: parent.verticalCenter
            text: option.modelData.label
            color: optionArea.containsMouse ? select.ui.accentText : select.ui.text
            font.family: select.ui.fontFamily
            font.pixelSize: 13
          }

          MouseArea {
            id: optionArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
              menu.close()
              select.picked(option.modelData.value)
            }
          }
        }
      }
    }
  }
}
