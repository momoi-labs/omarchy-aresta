pragma ComponentBehavior: Bound

import QtQuick

Item {
  id: tile

  required property Theme ui
  property string name: ""
  property bool selected: false
  property string preview: ""
  property var colors: []
  property real tileWidth: 84
  property real tileHeight: 54
  signal clicked()

  readonly property color miniBackground: colors.length === 3 ? colors[0] : ui.background
  readonly property color miniForeground: colors.length === 3 ? colors[1] : ui.foreground
  readonly property color miniAccent: colors.length === 3 ? colors[2] : ui.accent

  implicitWidth: Math.max(tileWidth + 8, label.implicitWidth)
  implicitHeight: tileHeight + 8 + 7 + label.implicitHeight

  Rectangle {
    id: frame
    anchors.horizontalCenter: parent.horizontalCenter
    width: tile.tileWidth + 8
    height: tile.tileHeight + 8
    radius: 12
    color: "transparent"
    border.width: 3
    border.color: tile.selected ? tile.ui.accent : "transparent"

    Rectangle {
      id: cut
      anchors.fill: parent
      anchors.margins: 4
      radius: 8
      clip: true
      color: Qt.tint(tile.miniBackground, Qt.alpha(tile.miniAccent, 0.42))
      border.width: 1
      border.color: tile.ui.separator

      RoundedImage {
        radius: 7
        anchors.fill: parent
        anchors.margins: 1
        visible: tile.preview !== ""
        source: tile.preview
        sourceSize.width: tile.tileWidth * 2
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
      }

      Item {
        anchors.fill: parent
        visible: tile.preview === ""

        Rectangle {
          width: parent.width
          height: 8
          topLeftRadius: 8
          topRightRadius: 8
          color: Qt.alpha(tile.miniBackground, 0.6)
        }

        Rectangle {
          x: parent.width * 0.22
          y: parent.height * 0.28
          width: parent.width * 0.64
          height: parent.height
          radius: 7
          color: tile.miniBackground
          border.width: 1
          border.color: Qt.alpha(tile.miniForeground, 0.25)

          Row {
            x: 5
            y: 5
            spacing: 3
            Repeater {
              model: ["#ff5f57", "#febc2e", "#28c840"]
              Rectangle { required property string modelData; width: 5; height: 5; radius: 2.5; color: modelData }
            }
          }

          Rectangle { x: 5; y: 14; width: parent.width * 0.46; height: 3; radius: 1.5; color: tile.miniForeground; opacity: 0.75 }
          Rectangle { x: 5; y: 21; width: parent.width * 0.26; height: 3; radius: 1.5; color: tile.miniAccent }
        }
      }
    }
  }

  Text {
    id: label
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: frame.bottom
    anchors.topMargin: 7
    text: tile.name
    color: tile.selected ? tile.ui.text : tile.ui.textSecondary
    font.family: tile.ui.fontFamily
    font.pixelSize: 12
    font.weight: tile.selected ? Font.DemiBold : Font.Normal
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: tile.clicked()
  }
}
