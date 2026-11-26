pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Shapes
import Cupertino as App

Rectangle {
  id: picker

  required property Theme ui
  required property App.Backend backend
  property var names: []
  property string value: ""
  signal picked(string name)

  readonly property string title: backend.revision >= 0 ? backend.themeTitle(value) : ""

  component ThemeWindow: Rectangle {
    id: mini
    property var colors: []
    readonly property color paper: colors.length === 3 ? colors[0] : "#808080"
    readonly property color ink: colors.length === 3 ? colors[1] : "#ffffff"
    readonly property color tint: colors.length === 3 ? colors[2] : "#0a84ff"
    readonly property real unit: height / 58

    radius: 4 * unit
    color: paper
    border.width: 1
    border.color: Qt.alpha(ink, 0.25)
    clip: true

    Rectangle {
      width: parent.width * 0.3
      height: parent.height
      radius: parent.radius
      color: Qt.tint(mini.paper, Qt.alpha(mini.ink, 0.08))

      Row {
        x: 5 * mini.unit
        y: 5 * mini.unit
        spacing: 2.5 * mini.unit
        Repeater {
          model: ["#ff5f57", "#febc2e", "#28c840"]
          Rectangle { required property string modelData; width: 4.5 * mini.unit; height: width; radius: width / 2; color: modelData }
        }
      }

      Rectangle { x: 4 * mini.unit; y: 15 * mini.unit; width: parent.width - 8 * mini.unit; height: 6 * mini.unit; radius: 1.5 * mini.unit; color: mini.tint }
      Rectangle { x: 5 * mini.unit; y: 26 * mini.unit; width: parent.width * 0.5; height: 2.5 * mini.unit; radius: 1.2 * mini.unit; color: Qt.alpha(mini.ink, 0.6) }
      Rectangle { x: 5 * mini.unit; y: 33 * mini.unit; width: parent.width * 0.5; height: 2.5 * mini.unit; radius: 1.2 * mini.unit; color: Qt.alpha(mini.ink, 0.6) }
    }

    Item {
      x: parent.width * 0.3
      width: parent.width * 0.7
      height: parent.height

      Rectangle { x: 6 * mini.unit; y: 6 * mini.unit; width: parent.width * 0.35; height: 3 * mini.unit; radius: 1.5 * mini.unit; color: mini.ink }
      Rectangle { x: 6 * mini.unit; y: 14 * mini.unit; width: parent.width - 12 * mini.unit; height: 10 * mini.unit; radius: 2 * mini.unit; color: Qt.alpha(mini.ink, 0.08) }
      Rectangle { x: 6 * mini.unit; y: 31 * mini.unit; width: parent.width * 0.45; height: 2.5 * mini.unit; radius: 1.2 * mini.unit; color: Qt.alpha(mini.ink, 0.45) }
      Rectangle { x: parent.width - width - 6 * mini.unit; y: parent.height - height - 6 * mini.unit; width: parent.width * 0.28; height: 7 * mini.unit; radius: 2 * mini.unit; color: mini.tint }
    }
  }

  implicitWidth: button.implicitWidth + 12
  implicitHeight: 32
  radius: 8
  color: area.containsMouse || popup.opened ? picker.ui.hover : picker.ui.controlSoft
  border.width: activeFocus ? 2 : 1
  border.color: activeFocus ? Qt.alpha(ui.accent, 0.6) : ui.controlBorder
  activeFocusOnTab: true

  function openPopup() {
    backend.refreshThemes()
    grid.currentIndex = Math.max(0, names.indexOf(title))
    popup.open()
  }

  function fill() {
    var name = grid.currentIndex >= 0 && grid.currentIndex < grid.count ? grid.model[grid.currentIndex] : ""
    var index = names.indexOf(name)
    grid.model = names
    grid.currentIndex = index >= 0 ? index : names.indexOf(title)
    grid.positionViewAtIndex(grid.currentIndex, GridView.Contain)
  }

  onNamesChanged: fill()
  Component.onCompleted: fill()

  Keys.onSpacePressed: openPopup()
  Keys.onReturnPressed: openPopup()
  Keys.onUpPressed: openPopup()
  Keys.onDownPressed: openPopup()

  Row {
    id: button
    x: 4
    anchors.verticalCenter: parent.verticalCenter
    spacing: 8

    ThemeWindow {
      width: 36
      height: 24
      anchors.verticalCenter: parent.verticalCenter
      colors: picker.backend.revision >= 0 ? picker.backend.themeColors(picker.value) : []
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: picker.title
      color: picker.ui.text
      font.family: picker.ui.fontFamily
      font.pixelSize: 13
    }

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: 16
      height: 20
      radius: 5
      color: picker.ui.accent

      Shape {
        anchors.centerIn: parent
        width: 10
        height: 14
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeColor: picker.ui.accentText
          strokeWidth: 1.6
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          joinStyle: ShapePath.RoundJoin
          PathSvg { path: "M2 5 L5 2 L8 5 M2 9 L5 12 L8 9" }
        }
      }
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: picker.openPopup()
  }

  Popup {
    id: popup

    readonly property int columns: 6
    readonly property real cellWidth: 112
    readonly property real cellHeight: 100

    y: picker.height + 6
    x: picker.width - width
    width: columns * cellWidth + 16
    height: Math.min(grid.contentHeight, 4 * cellHeight) + footer.height + 16
    margins: 8
    padding: 8
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    onOpened: grid.forceActiveFocus()
    onClosed: picker.forceActiveFocus()

    background: Rectangle {
      radius: 12
      color: picker.ui.sidebar
      border.width: 1
      border.color: picker.ui.keyBorder
    }

    contentItem: Item {
      GridView {
        id: grid
        width: parent.width
        height: parent.height - footer.height
        clip: true
        cellWidth: popup.cellWidth
        cellHeight: popup.cellHeight
        keyNavigationEnabled: true
        boundsBehavior: Flickable.StopAtBounds
        highlightFollowsCurrentItem: false

        function pick(index) {
          if (index < 0 || index >= picker.names.length) return
          popup.close()
          picker.picked(picker.names[index])
        }

        Keys.onReturnPressed: pick(currentIndex)
        Keys.onEnterPressed: pick(currentIndex)
        Keys.onSpacePressed: pick(currentIndex)
        Keys.onTabPressed: popup.close()
        Keys.onBacktabPressed: popup.close()
        Keys.onPressed: event => {
          if (event.key === Qt.Key_Home) { currentIndex = 0; event.accepted = true; return }
          if (event.key === Qt.Key_End) { currentIndex = count - 1; event.accepted = true; return }
          var letter = event.text.toLowerCase()
          if (letter.length !== 1 || letter < "a" || letter > "z") return
          for (var i = 1; i <= picker.names.length; i++) {
            var index = (currentIndex + i) % picker.names.length
            if (picker.names[index].toLowerCase().indexOf(letter) === 0) {
              currentIndex = index
              break
            }
          }
          event.accepted = true
        }

        delegate: Item {
          id: cell
          required property string modelData
          required property int index
          readonly property bool selected: modelData === picker.title
          readonly property bool current: GridView.isCurrentItem

          width: popup.cellWidth
          height: popup.cellHeight

          Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 10
            color: cell.current || cellArea.containsMouse ? picker.ui.hover : "transparent"
          }

          Rectangle {
            id: frame
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8
            width: 98
            height: 64
            radius: 8
            color: "transparent"
            border.width: 2
            border.color: cell.selected ? picker.ui.accent : "transparent"

            ThemeWindow {
              anchors.centerIn: parent
              width: 90
              height: 56
              colors: picker.backend.revision >= 0 ? picker.backend.themeColors(cell.modelData) : []
            }
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: frame.bottom
            anchors.topMargin: 6
            width: parent.width - 8
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: cell.modelData
            color: cell.selected || cell.current ? picker.ui.text : picker.ui.textSecondary
            font.family: picker.ui.fontFamily
            font.pixelSize: 12
            font.weight: cell.selected ? Font.DemiBold : Font.Normal
          }

          MouseArea {
            id: cellArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: grid.currentIndex = cell.index
            onClicked: grid.pick(cell.index)
          }
        }
      }

      Item {
        id: footer
        anchors.bottom: parent.bottom
        width: parent.width
        height: 30

        Rectangle { width: parent.width; height: 1; color: picker.ui.separator }

        Text {
          x: 6
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width / 2
          elide: Text.ElideRight
          textFormat: Text.StyledText
          readonly property string name: grid.currentIndex >= 0 && grid.currentIndex < picker.names.length ? picker.names[grid.currentIndex] : ""
          text: "<b>" + name + "</b>  " + String(picker.backend.revision >= 0 ? picker.backend.themeFile(name) : "").replace(/\/colors\.toml$/, "")
          color: picker.ui.textSecondary
          font.family: picker.ui.fontFamily
          font.pixelSize: 12
        }

        Text {
          anchors.right: parent.right
          anchors.rightMargin: 6
          anchors.verticalCenter: parent.verticalCenter
          text: qsTr("Arrows move, Return picks, Esc closes")
          color: picker.ui.textTertiary
          font.family: picker.ui.fontFamily
          font.pixelSize: 11
        }
      }
    }
  }
}
