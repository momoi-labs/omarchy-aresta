pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Cupertino as App

Item {
  id: root

  required property Theme ui
  required property App.Backend backend
  required property string themeTitle
  required property string wallpaperUrl

  readonly property bool dark: backend.themeDark(backend.themeName)
  readonly property bool shadows: backend.revision >= 0 && backend.flag("shadow_enabled")

  readonly property var palette: {
    var map = {}
    if (backend.themeName === "-" || backend.background === "") return map
    var list = backend.themePalette(backend.themeName)
    for (var i = 0; i < list.length; i++) {
      var parts = list[i].split("|")
      if (parts.length === 2) map[parts[0]] = parts[1]
    }
    return map
  }

  function token(key, fallback) {
    return palette[key] || fallback
  }

  readonly property color bg: token("background", ui.background)
  readonly property color fg: token("foreground", ui.foreground)
  readonly property color accentColor: token("accent", ui.accent)
  readonly property color accentText: ui.luminance(accentColor) > 0.3 ? "#111113" : "#ffffff"
  readonly property color selectionColor: token("selection", Qt.alpha(accentColor, 0.25))
  readonly property color selectionText: ui.luminance(selectionColor) > 0.35 ? "#111113" : "#ffffff"
  readonly property color darkerBg: token("darker_background", ui.mix(0.08))
  readonly property color darkBg: token("dark_background", ui.box)
  readonly property color lighterBg: token("lighter_background", ui.sidebar)
  readonly property color mutedColor: token("muted", ui.textSecondary)
  readonly property color mutedInk: token("dark_foreground", mutedColor)
  readonly property color brightInk: token("bright_foreground", fg)

  readonly property color termRed: token("red", "#ff5f57")
  readonly property color termOrange: token("orange", "#ff9230")
  readonly property color termYellow: token("yellow", "#ffd600")
  readonly property color termGreen: token("green", "#30d158")
  readonly property color termCyan: token("cyan", "#00d2e0")
  readonly property color termBlue: token("blue", "#0a84ff")
  readonly property color termMagenta: token("magenta", "#db34f2")
  readonly property color termBrown: token("brown", termOrange)

  readonly property string luminanceText: (Math.round(backend.themeLuminance(backend.themeName) * 100) / 100).toFixed(2)

  readonly property var uiSwatches: [
    { name: qsTr("Accent"), color: accentColor, hex: token("accent", backend.accent) },
    { name: qsTr("Selection"), color: selectionColor, hex: token("selection", selectionColor.toString()) },
    { name: qsTr("Background"), color: bg, hex: token("background", backend.background) },
    { name: qsTr("Darker Background"), color: darkerBg, hex: token("darker_background", darkerBg.toString()) },
    { name: qsTr("Foreground"), color: fg, hex: token("foreground", backend.foreground) },
    { name: qsTr("Muted"), color: mutedColor, hex: token("muted", mutedColor.toString()) }
  ]

  readonly property var ansiSwatches: [
    { name: qsTr("Red"), color: termRed, hex: token("red", termRed.toString()) },
    { name: qsTr("Orange"), color: termOrange, hex: token("orange", termOrange.toString()) },
    { name: qsTr("Yellow"), color: termYellow, hex: token("yellow", termYellow.toString()) },
    { name: qsTr("Green"), color: termGreen, hex: token("green", termGreen.toString()) },
    { name: qsTr("Cyan"), color: termCyan, hex: token("cyan", termCyan.toString()) },
    { name: qsTr("Blue"), color: termBlue, hex: token("blue", termBlue.toString()) },
    { name: qsTr("Magenta"), color: termMagenta, hex: token("magenta", termMagenta.toString()) }
  ]

  property string tipText: ""
  property real tipCenterX: 0
  property real tipTopY: 0

  component SwatchDot: Item {
    id: swatch
    required property var itemData
    width: 20
    height: 20

    Rectangle {
      width: parent.width
      height: parent.height
      y: swatchArea.containsMouse ? -1.5 : 0
      scale: swatchArea.containsMouse ? 1.08 : 1.0
      radius: 6
      color: swatch.itemData.color
      border.width: 1
      border.color: root.ui.controlBorder
    }

    MouseArea {
      id: swatchArea
      anchors.fill: parent
      hoverEnabled: true
      onEntered: {
        var pos = swatch.mapToItem(root, swatch.width / 2, 0)
        root.tipText = swatch.itemData.name + " · " + swatch.itemData.hex
        root.tipCenterX = pos.x
        root.tipTopY = pos.y
      }
      onExited: {
        if (root.tipText === swatch.itemData.name + " · " + swatch.itemData.hex) {
          root.tipText = ""
        }
      }
    }
  }

  implicitHeight: stage.y + stage.height + 10 + strip.implicitHeight + 12

  Rectangle {
    id: stage
    x: 12
    y: 12
    width: parent.width - 24
    height: 236
    radius: 10
    color: root.ui.controlSoft
    border.width: 1
    border.color: root.ui.separator
    clip: true

    RoundedImage {
      anchors.fill: parent
      anchors.margins: 1
      radius: 9
      source: root.wallpaperUrl
      sourceSize.width: 1400
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
    }

    Rectangle {
      id: termShadowSource
      x: termWindow.x
      y: termWindow.y
      width: termWindow.width
      height: termWindow.height
      radius: termWindow.radius
      color: root.bg
      visible: false
      layer.enabled: root.shadows
    }

    MultiEffect {
      anchors.fill: termWindow
      z: 1
      visible: root.shadows
      source: termShadowSource
      shadowEnabled: true
      shadowBlur: 0.85
      shadowHorizontalOffset: 0
      shadowVerticalOffset: 10
      shadowColor: Qt.rgba(0, 0, 0, root.dark ? 0.58 : 0.22)
    }

    Rectangle {
      id: termWindow
      x: 22
      y: 18
      z: 2
      width: Math.min(392, Math.max(240, stage.width * 0.565))
      height: 174
      radius: 9
      color: root.bg
      border.width: 1
      border.color: Qt.alpha(root.fg, 0.16)

      Rectangle {
        id: termTitlebar
        x: 1
        y: 1
        width: parent.width - 2
        height: 22
        radius: 8
        color: root.dark ? root.darkerBg : root.darkBg

        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: 8
          color: parent.color
        }

        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: 1
          color: Qt.alpha(root.fg, 0.08)
        }

        Row {
          x: 8
          anchors.verticalCenter: parent.verticalCenter
          spacing: 5

          Repeater {
            model: 3

            Rectangle {
              width: 7.5
              height: 7.5
              radius: 3.75
              color: Qt.alpha(root.fg, 0.24)
            }
          }
        }

        Text {
          anchors.centerIn: parent
          width: parent.width - 68
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          text: qsTr("seba@omarchy — ~/cupertino")
          color: Qt.alpha(root.fg, 0.72)
          font.family: root.ui.fontFamily
          font.pixelSize: 10
          font.weight: Font.Medium
        }
      }

      Text {
        x: 10
        y: termTitlebar.y + termTitlebar.height + 8
        width: parent.width - 20
        height: parent.height - y - 8
        clip: true
        textFormat: Text.StyledText
        color: root.fg
        font.family: "monospace"
        font.pixelSize: 9.5
        lineHeight: 1.52
        text:
          "<font color=\"" + root.termBlue + "\"><b>~/cupertino</b></font> " +
          "<font color=\"" + root.termMagenta + "\">main</font> " +
          "<font color=\"" + root.termGreen + "\">❯</font> cargo test --quiet<br>" +
          "<font color=\"" + root.termCyan + "\">&nbsp;&nbsp;&nbsp;Compiling</font> cupertino-settings " +
          "<font color=\"" + root.mutedInk + "\">v0.4.2</font><br>" +
          "<font color=\"" + root.termYellow + "\"><b>warning</b></font>" +
          "<font color=\"" + root.mutedInk + "\">:</font> " +
          "<font color=\"" + root.termOrange + "\">unused</font> token " +
          "<font color=\"" + root.termBrown + "\">brown</font><br>" +
          "<font color=\"" + root.mutedInk + "\">test</font> theme::load_toml&nbsp;&nbsp;... " +
          "<font color=\"" + root.termGreen + "\"><b>ok</b></font><br>" +
          "<font color=\"" + root.mutedInk + "\">test</font> bar::live_preview ... " +
          "<font color=\"" + root.termGreen + "\"><b>ok</b></font><br>" +
          "<font color=\"" + root.mutedInk + "\">test</font> contrast::aa_min&nbsp;&nbsp;... " +
          "<font color=\"" + root.termRed + "\"><b>FAILED</b></font><br>" +
          "<font color=\"" + root.termBlue + "\">diff</font> " +
          "<font color=\"" + root.termGreen + "\">+14</font> " +
          "<font color=\"" + root.termRed + "\">-3</font>&nbsp;&nbsp;" +
          "<font color=\"" + root.mutedInk + "\">2 files changed</font>"
      }
    }

    Rectangle {
      id: appShadowSource
      x: appWindow.x
      y: appWindow.y
      width: appWindow.width
      height: appWindow.height
      radius: appWindow.radius
      color: root.bg
      visible: false
      layer.enabled: root.shadows
    }

    MultiEffect {
      anchors.fill: appWindow
      z: 3
      visible: root.shadows
      source: appShadowSource
      shadowEnabled: true
      shadowBlur: 0.9
      shadowHorizontalOffset: 0
      shadowVerticalOffset: 12
      shadowColor: Qt.rgba(0, 0, 0, root.dark ? 0.68 : 0.28)
    }

    Rectangle {
      id: appWindow
      anchors.right: parent.right
      anchors.rightMargin: 20
      y: 34
      z: 4
      width: Math.min(312, Math.max(210, stage.width * 0.45))
      height: 162
      radius: 9
      color: root.bg
      border.width: 1
      border.color: Qt.alpha(root.fg, 0.16)

      Rectangle {
        id: appSidebar
        x: 1
        y: 1
        width: 92
        height: parent.height - 2
        radius: 8
        color: root.lighterBg

        Rectangle {
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: 8
          color: parent.color
        }

        Rectangle {
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: 1
          color: Qt.alpha(root.fg, 0.08)
        }

        Column {
          x: 7
          y: 8
          width: parent.width - 14
          spacing: 4

          Row {
            leftPadding: 2
            bottomPadding: 5
            spacing: 5

            Repeater {
              model: ["#ff5f57", "#febc2e", "#28c840"]

              Rectangle {
                required property string modelData
                width: 7.5
                height: 7.5
                radius: 3.75
                color: modelData
              }
            }
          }

          Repeater {
            model: [
              { label: qsTr("Inbox"), selected: true, dot: root.accentText, ink: root.accentText },
              { label: qsTr("Projects"), selected: false, dot: root.termCyan, ink: root.fg },
              { label: qsTr("Notes"), selected: false, dot: root.termMagenta, ink: root.mutedInk },
              { label: qsTr("Archive"), selected: false, dot: root.termOrange, ink: root.mutedInk }
            ]

            Rectangle {
              id: navItem
              required property var modelData
              width: parent.width
              height: 18
              radius: 5
              color: navItem.modelData.selected ? root.accentColor : "transparent"

              Row {
                x: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: 5
                  height: 5
                  radius: 2.5
                  color: navItem.modelData.dot
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: navItem.modelData.label
                  color: navItem.modelData.ink
                  font.family: root.ui.fontFamily
                  font.pixelSize: 9
                  font.weight: Font.Medium
                }
              }
            }
          }
        }
      }

      Item {
        id: appMain
        anchors.left: appSidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 1

        Column {
          x: 11
          y: 9
          width: parent.width - 22
          spacing: 7

          Item {
            width: parent.width
            height: 16

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: qsTr("Theme Preview")
              color: root.brightInk
              font.family: root.ui.fontFamily
              font.pixelSize: 10.5
              font.weight: Font.Bold
            }

            Rectangle {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: modeBadge.implicitWidth + 12
              height: 15
              radius: 7.5
              color: root.darkerBg

              Text {
                id: modeBadge
                anchors.centerIn: parent
                text: root.dark ? qsTr("dark") : qsTr("light")
                color: root.mutedInk
                font.family: root.ui.fontFamily
                font.pixelSize: 8.5
                font.weight: Font.DemiBold
              }
            }
          }

          Rectangle {
            width: parent.width
            height: selText.implicitHeight + 10
            radius: 5
            color: root.selectionColor

            Text {
              id: selText
              x: 7
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - 14
              elide: Text.ElideRight
              textFormat: Text.StyledText
              text: qsTr("Selected item uses <b>selection</b> tint")
              color: root.selectionText
              font.family: root.ui.fontFamily
              font.pixelSize: 9
            }
          }

          Rectangle {
            width: parent.width
            height: 24
            radius: 6
            color: root.darkBg
            border.width: 1
            border.color: Qt.alpha(root.fg, 0.08)

            Text {
              x: 8
              anchors.verticalCenter: parent.verticalCenter
              text: qsTr("Adaptive tint")
              color: root.fg
              font.family: root.ui.fontFamily
              font.pixelSize: 9
            }

            Rectangle {
              anchors.right: parent.right
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              width: 22
              height: 12
              radius: 6
              color: root.accentColor

              Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 1.5
                anchors.verticalCenter: parent.verticalCenter
                width: 9
                height: 9
                radius: 4.5
                color: "#ffffff"
              }
            }
          }
        }

        Item {
          x: 11
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 9
          width: parent.width - 22
          height: 20

          Text {
            anchors.left: parent.left
            anchors.right: applyPill.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: root.themeTitle
            color: root.mutedInk
            font.family: root.ui.fontFamily
            font.pixelSize: 8.5
          }

          Rectangle {
            id: applyPill
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: applyLabel.implicitWidth + 18
            height: 19
            radius: 5
            color: root.accentColor

            Text {
              id: applyLabel
              anchors.centerIn: parent
              text: qsTr("Apply")
              color: root.accentText
              font.family: root.ui.fontFamily
              font.pixelSize: 8.5
              font.weight: Font.DemiBold
            }
          }
        }
      }
    }

    Rectangle {
      id: themeChip
      x: 10
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 9
      z: 6
      width: chipRow.implicitWidth + 16
      height: 21
      radius: 10.5
      color: root.dark ? Qt.rgba(18 / 255, 20 / 255, 24 / 255, 0.78) : Qt.rgba(1, 1, 1, 0.82)
      border.width: 1
      border.color: root.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12)

      Row {
        id: chipRow
        anchors.centerIn: parent
        spacing: 6

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: 7
          height: 7
          radius: 3.5
          color: root.accentColor
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.themeTitle + " · " + (root.dark ? qsTr("Dark") : qsTr("Light"))
          color: root.dark ? "#eceef2" : "#1c1e22"
          font.family: root.ui.fontFamily
          font.pixelSize: 10.5
          font.weight: Font.Medium
        }
      }
    }
  }

  Item {
    id: strip
    x: 12
    y: stage.y + stage.height + 10
    width: parent.width - 24
    implicitHeight: Math.max(swatchGroups.implicitHeight, metaText.implicitHeight)
    height: implicitHeight

    Flow {
      id: swatchGroups
      width: Math.max(0, parent.width - metaText.implicitWidth - 12)
      spacing: 10

      Row {
        spacing: 4

        Text {
          anchors.verticalCenter: parent.verticalCenter
          rightPadding: 2
          text: qsTr("UI")
          color: root.ui.textSecondary
          font.family: root.ui.fontFamily
          font.pixelSize: 10.5
          font.weight: Font.DemiBold
        }

        Repeater {
          model: root.uiSwatches

          SwatchDot {
            required property var modelData
            itemData: modelData
          }
        }
      }

      Rectangle {
        width: 1
        height: 16
        y: 2
        color: root.ui.separator
      }

      Row {
        spacing: 4

        Text {
          anchors.verticalCenter: parent.verticalCenter
          rightPadding: 2
          text: qsTr("ANSI")
          color: root.ui.textSecondary
          font.family: root.ui.fontFamily
          font.pixelSize: 10.5
          font.weight: Font.DemiBold
        }

        Repeater {
          model: root.ansiSwatches

          SwatchDot {
            required property var modelData
            itemData: modelData
          }
        }
      }
    }

    Text {
      id: metaText
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: root.themeTitle + " · L " + root.luminanceText
      color: root.ui.textSecondary
      font.family: root.ui.fontFamily
      font.pixelSize: 11
    }
  }

  Rectangle {
    id: tooltip
    visible: root.tipText !== ""
    z: 50
    x: Math.max(12, Math.min(root.width - 12 - width, root.tipCenterX - width / 2))
    y: root.tipTopY - height - 7
    width: tipLabel.implicitWidth + 14
    height: tipLabel.implicitHeight + 6
    radius: 6
    color: "#14161b"
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.14)

    Text {
      id: tipLabel
      anchors.centerIn: parent
      text: root.tipText
      color: "#f4f5f7"
      font.family: "monospace"
      font.pixelSize: 10
    }
  }
}
