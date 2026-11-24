import QtQuick

Row {
  id: slider

  required property Theme ui
  property real value: 0
  property real from: 0
  property real to: 100
  property real stepSize: 1
  property string unit: ""
  signal moved(real value)

  readonly property real ratio: Math.max(0, Math.min(1, (value - from) / (to - from)))
  readonly property int decimals: stepSize < 1 ? 1 : 0

  function snap(position) {
    var raw = from + Math.max(0, Math.min(1, position / track.width)) * (to - from)
    var stepped = Math.round(raw / stepSize) * stepSize
    return Number(Math.max(from, Math.min(to, stepped)).toFixed(decimals))
  }

  function nudge(direction) {
    moved(Number(Math.max(from, Math.min(to, value + direction * stepSize)).toFixed(decimals)))
  }

  spacing: 10
  activeFocusOnTab: true
  Keys.onLeftPressed: nudge(-1)
  Keys.onRightPressed: nudge(1)

  Item {
    id: track

    width: 150
    height: 20
    anchors.verticalCenter: parent.verticalCenter

    Rectangle {
      y: 8
      width: parent.width
      height: 4
      radius: 2
      color: slider.ui.control
    }

    Rectangle {
      y: 8
      width: slider.ratio * parent.width
      height: 4
      radius: 2
      color: slider.ui.accent
    }

    Rectangle {
      x: slider.ratio * parent.width - width / 2
      y: 2
      width: 22
      height: 16
      radius: 8
      color: slider.ui.knob
      border.width: slider.activeFocus ? 2 : 1
      border.color: slider.activeFocus ? Qt.alpha(slider.ui.accent, 0.6) : Qt.rgba(0, 0, 0, 0.2)
    }

    MouseArea {
      anchors.fill: parent
      anchors.leftMargin: -8
      anchors.rightMargin: -8
      preventStealing: true
      cursorShape: Qt.PointingHandCursor
      onPressed: mouse => { slider.forceActiveFocus(); slider.moved(slider.snap(mouse.x - 8)) }
      onPositionChanged: mouse => { if (pressed) slider.moved(slider.snap(mouse.x - 8)) }
    }
  }

  Text {
    width: 44
    anchors.verticalCenter: parent.verticalCenter
    horizontalAlignment: Text.AlignRight
    text: slider.value.toFixed(slider.decimals) + (slider.unit === "%" ? "%" : slider.unit ? " " + slider.unit : "")
    color: slider.ui.textSecondary
    font.family: slider.ui.fontFamily
    font.pixelSize: 13
    font.features: { "tnum": 1 }
  }
}
