pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

Rectangle {
  id: stepper

  required property Theme ui
  property real value: 0
  property real from: 0
  property real to: 100
  property real stepSize: 1
  property string unit: ""
  signal moved(real value)

  function nudge(direction) {
    moved(Math.max(from, Math.min(to, value + direction * stepSize)))
  }

  implicitWidth: label.width + 36
  implicitHeight: 26
  radius: 7
  color: ui.controlSoft
  border.width: activeFocus ? 2 : 1
  border.color: activeFocus ? Qt.alpha(ui.accent, 0.6) : ui.controlBorder
  activeFocusOnTab: true
  Keys.onUpPressed: nudge(1)
  Keys.onDownPressed: nudge(-1)

  Text {
    id: label
    x: 9
    width: Math.max(implicitWidth, 34)
    anchors.verticalCenter: parent.verticalCenter
    horizontalAlignment: Text.AlignRight
    text: stepper.value + (stepper.unit ? " " + stepper.unit : "")
    color: stepper.ui.text
    font.family: stepper.ui.fontFamily
    font.pixelSize: 13
    font.features: { "tnum": 1 }
  }

  Rectangle {
    x: parent.width - 18
    width: 1
    height: parent.height
    color: stepper.ui.separator
  }

  Column {
    x: parent.width - 17
    width: 17
    height: parent.height

    Repeater {
      model: [1, -1]

      Item {
        id: arrow
        required property int modelData
        width: 17
        height: stepper.height / 2

        Rectangle {
          anchors.fill: parent
          color: area.containsMouse ? stepper.ui.hover : "transparent"
        }

        Shape {
          anchors.centerIn: parent
          width: 8
          height: 5
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            strokeColor: stepper.ui.textSecondary
            strokeWidth: 1.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: arrow.modelData > 0 ? "M1 4 L4 1 L7 4" : "M1 1 L4 4 L7 1" }
          }
        }

        MouseArea {
          id: area
          anchors.fill: parent
          hoverEnabled: true
          onClicked: stepper.nudge(arrow.modelData)
        }
      }
    }
  }
}
