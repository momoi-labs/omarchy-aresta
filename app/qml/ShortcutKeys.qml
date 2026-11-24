pragma ComponentBehavior: Bound

import QtQuick

Row {
  id: keys

  required property Theme ui
  property var labels: []
  property bool locked: false
  property bool recording: false
  signal clicked()
  signal cancelled()

  spacing: 8

  Rectangle {
    visible: keys.locked
    anchors.verticalCenter: parent.verticalCenter
    width: tag.implicitWidth + 12
    height: 18
    radius: 6
    color: keys.ui.control

    Text {
      id: tag
      anchors.centerIn: parent
      text: "Omarchy"
      color: keys.ui.textSecondary
      font.family: keys.ui.fontFamily
      font.pixelSize: 11
    }
  }

  Rectangle {
    visible: keys.recording
    anchors.verticalCenter: parent.verticalCenter
    width: recordRow.implicitWidth + 20
    height: 28
    radius: 8
    color: "transparent"
    border.width: 2
    border.color: keys.ui.accent

    Row {
      id: recordRow
      anchors.centerIn: parent
      spacing: 7

      Rectangle {
        width: 8
        height: 8
        radius: 4
        color: keys.ui.record
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        text: qsTr("Type the new shortcut")
        color: keys.ui.accent
        font.family: keys.ui.fontFamily
        font.pixelSize: 13
        font.weight: Font.Medium
      }
    }
  }

  Rectangle {
    visible: keys.recording
    anchors.verticalCenter: parent.verticalCenter
    width: cancelLabel.implicitWidth + 24
    height: 26
    radius: 13
    color: cancelArea.containsMouse ? Qt.tint(keys.ui.controlSoft, keys.ui.hover) : keys.ui.controlSoft
    border.width: 1
    border.color: keys.ui.controlBorder

    Text {
      id: cancelLabel
      anchors.centerIn: parent
      text: qsTr("Cancel")
      color: keys.ui.text
      font.family: keys.ui.fontFamily
      font.pixelSize: 13
      font.weight: Font.Medium
    }

    MouseArea {
      id: cancelArea
      anchors.fill: parent
      hoverEnabled: true
      onClicked: keys.cancelled()
    }
  }

  Rectangle {
    visible: !keys.recording
    anchors.verticalCenter: parent.verticalCenter
    width: caps.implicitWidth + 4
    height: 28
    radius: 8
    color: area.containsMouse && !keys.locked ? keys.ui.hover : "transparent"
    opacity: keys.locked ? 0.6 : 1

    Row {
      id: caps
      anchors.centerIn: parent
      spacing: 4

      Text {
        visible: keys.labels.length === 0
        text: qsTr("None")
        color: keys.ui.textSecondary
        font.family: keys.ui.fontFamily
        font.pixelSize: 12
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: 6
        rightPadding: 6
      }

      Repeater {
        model: keys.labels

        Rectangle {
          required property string modelData
          width: Math.max(24, capLabel.implicitWidth + 14)
          height: 24
          radius: 6
          color: keys.ui.key
          border.width: 1
          border.color: keys.ui.keyBorder

          Text {
            id: capLabel
            anchors.centerIn: parent
            text: parent.modelData
            color: keys.ui.text
            font.family: keys.ui.fontFamily
            font.pixelSize: 12
          }
        }
      }
    }

    MouseArea {
      id: area
      anchors.fill: parent
      enabled: !keys.locked
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: keys.clicked()
    }
  }
}
