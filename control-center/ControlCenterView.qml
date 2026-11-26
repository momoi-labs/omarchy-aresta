pragma ComponentBehavior: Bound

import QtQuick

Column {
  id: view

  property var info: ({})
  property var show: ({ wifi: true, bluetooth: true, focus: true, display: true, sound: true, media: true })
  property color background: "#1e1e1e"
  property color foreground: "#ffffff"
  property color accent: "#0a84ff"
  property string fontFamily: "sans-serif"
  property string iconFamily: "monospace"
  property bool translucent: true
  property real panelAlpha: 0.72
  property bool halo: false

  signal act(var command)

  function luminance(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }

  readonly property int w: 332
  readonly property bool dark: luminance(background) < 0.4
  readonly property color pillBase: dark
    ? Qt.rgba(Math.min(1, background.r + 0.045), Math.min(1, background.g + 0.045), Math.min(1, background.b + 0.045), 1)
    : background
  readonly property color pillBaseHover: dark
    ? Qt.rgba(Math.min(1, background.r + 0.085), Math.min(1, background.g + 0.085), Math.min(1, background.b + 0.085), 1)
    : Qt.rgba(Math.min(1, background.r + 0.02), Math.min(1, background.g + 0.02), Math.min(1, background.b + 0.02), 1)
  readonly property color pillBg: translucent
    ? Qt.rgba(pillBase.r, pillBase.g, pillBase.b, panelAlpha)
    : (halo ? (dark ? Qt.rgba(Math.min(1, background.r + 0.07), Math.min(1, background.g + 0.07), Math.min(1, background.b + 0.07), 1) : Qt.darker(background, 1.04)) : pillBase)
  readonly property color pillBgHover: translucent
    ? Qt.rgba(pillBaseHover.r, pillBaseHover.g, pillBaseHover.b, Math.min(1, panelAlpha + (dark ? 0.08 : 0.1)))
    : (dark ? Qt.rgba(Math.min(1, background.r + 0.11), Math.min(1, background.g + 0.11), Math.min(1, background.b + 0.11), 1) : Qt.darker(background, 1.07))
  readonly property color pillRim: dark ? Qt.rgba(1, 1, 1, translucent ? 0.20 : 0.14) : Qt.rgba(0, 0, 0, translucent ? 0.11 : 0.12)
  readonly property color pillRimHover: dark ? Qt.rgba(1, 1, 1, 0.34) : Qt.rgba(0, 0, 0, 0.20)
  readonly property color dotOffBg: Qt.alpha(foreground, dark ? 0.14 : 0.09)
  readonly property color dotOnBg: dark ? "#ffffff" : accent
  readonly property color dotOnInk: dark ? accent : "#ffffff"
  readonly property color focusAccent: "#db34f2"
  readonly property color focusOnBg: dark ? "#ffffff" : focusAccent
  readonly property color focusOnInk: dark ? focusAccent : "#ffffff"
  readonly property color dim: Qt.alpha(foreground, 0.58)
  readonly property color trackBg: Qt.alpha(foreground, dark ? 0.20 : 0.14)
  readonly property color trackFill: dark ? "#ffffff" : "#1f2328"

  readonly property var wifi: info.wifi || ({})
  readonly property var bt: info.bt || ({})
  readonly property var focusInfo: info.focus || ({})
  readonly property var nightlightInfo: info.nightlight || ({})
  readonly property var display: info.display || ({})
  readonly property var sound: info.sound || ({})
  readonly property var media: info.media || ({})
  readonly property var btDevices: bt.devices || []

  readonly property string wifiText: !wifi.on ? qsTr("Off") : wifi.ssid ? wifi.ssid : qsTr("Not Connected")
  readonly property string btText: !bt.on ? qsTr("Off") : btDevices.length === 0 ? qsTr("On") : btDevices.length === 1 ? btDevices[0] : qsTr("%1 devices").arg(btDevices.length)
  readonly property bool playing: media.status === "Playing"
  readonly property bool hasPlayer: !!media.bus
  readonly property string mediaTitle: media.title ? media.title : qsTr("Not Playing")
  readonly property string mediaSub: media.title ? (media.artist || media.player || "") : (media.player || "")
  readonly property int wifiCode: [0xF092F, 0xF091F, 0xF0922, 0xF0925, 0xF0928][!wifi.on || !wifi.ssid ? 0 : Math.max(1, Math.min(4, Math.ceil((wifi.signal || 0) / 25)))]
  readonly property int soundLowCode: sound.muted || !sound.percent ? 0xEEE8 : 0xF026

  readonly property var links: {
    var out = []
    if (show.wifi) out.push({ id: "wifi", picker: "omarchy.network", name: qsTr("Wi-Fi"), status: wifiText, on: !!wifi.on, code: wifiCode })
    if (show.bluetooth) out.push({ id: "bluetooth", picker: "omarchy.bluetooth", name: qsTr("Bluetooth"), status: btText, on: !!bt.on, code: 0xF00AF })
    return out
  }
  readonly property var sliders: {
    var out = []
    if (show.display) out.push({ key: "brightness", picker: "omarchy.monitor", name: qsTr("Display"), screen: true })
    if (show.sound) out.push({ key: "volume", picker: "omarchy.audio", name: qsTr("Sound"), screen: false })
    return out
  }

  width: w
  spacing: 10

  component Glyph: Text {
    property int code: 0
    text: String.fromCodePoint(code)
    font.family: view.iconFamily
    font.pixelSize: 15
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  component Label: Text {
    color: view.foreground
    font.family: view.fontFamily
    font.pixelSize: 13
    elide: Text.ElideRight
    textFormat: Text.PlainText
  }

  component Chevron: Text {
    property bool active: false
    text: "\u203A"
    color: view.foreground
    font.family: view.fontFamily
    font.pixelSize: 17
    font.weight: Font.Medium
    opacity: active ? 0.9 : 0
    Behavior on opacity { NumberAnimation { duration: 140 } }
  }

  component Pill: Rectangle {
    id: pill
    property bool hovered: false
    color: hovered ? view.pillBgHover : view.pillBg
    border.width: 1
    border.color: hovered ? view.pillRimHover : view.pillRim

    Rectangle {
      anchors.fill: parent
      anchors.margins: 1
      radius: Math.max(0, pill.radius - 1)
      visible: view.translucent
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, view.dark ? 0.09 : 0.42) }
        GradientStop { position: 0.45; color: "transparent" }
      }
    }
  }

  component Dot: Rectangle {
    id: dot
    property bool on: false
    property int code: 0
    property int size: 42
    property color onBg: view.dotOnBg
    property color onInk: view.dotOnInk
    width: size
    height: size
    radius: size / 2
    color: on ? onBg : view.dotOffBg
    Glyph {
      anchors.centerIn: parent
      code: dot.code
      color: dot.on ? dot.onInk : view.foreground
      font.pixelSize: Math.round(dot.size * 0.46)
    }
  }

  component Step: Item {
    id: step
    property string verb: ""
    property int code: 0
    property int iconSize: 17
    property bool live: view.hasPlayer
    width: 32
    height: 32
    Rectangle {
      anchors.fill: parent
      radius: 16
      color: stepArea.containsMouse && step.live ? Qt.alpha(view.foreground, 0.14) : "transparent"
    }
    Glyph {
      anchors.centerIn: parent
      code: step.code
      font.pixelSize: step.iconSize
      color: step.live ? view.foreground : view.dim
    }
    MouseArea {
      id: stepArea
      anchors.fill: parent
      hoverEnabled: true
      enabled: step.live
      onClicked: view.act([step.verb, view.media.bus])
    }
  }

  Row {
    visible: view.links.length > 0 || view.show.media
    spacing: 10

    Column {
      id: linkColumn
      visible: view.links.length > 0
      width: view.show.media ? (view.w - 10) / 2 : view.w
      spacing: 10

      Repeater {
        model: view.links

        Pill {
          id: linkPill
          required property var modelData
          width: linkColumn.width
          height: view.links.length === 1 && view.show.media ? 142 : 66
          radius: height === 66 ? 33 : 26
          hovered: linkBodyArea.containsMouse || linkDotArea.containsMouse

          MouseArea {
            id: linkBodyArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: view.act(["picker", linkPill.modelData.picker])
          }

          Dot {
            id: linkDot
            x: 11
            anchors.verticalCenter: parent.verticalCenter
            on: linkPill.modelData.on
            code: linkPill.modelData.code
            size: 42
            MouseArea {
              id: linkDotArea
              anchors.fill: parent
              hoverEnabled: true
              onClicked: view.act([linkPill.modelData.id, linkPill.modelData.on ? "off" : "on"])
            }
          }

          Column {
            anchors.left: linkDot.right
            anchors.leftMargin: 9
            anchors.right: linkChevron.left
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Label {
              width: parent.width
              text: linkPill.modelData.name
              font.weight: Font.DemiBold
            }
            Label {
              width: parent.width
              text: linkPill.modelData.status
              color: view.dim
              font.pixelSize: 11
            }
          }

          Chevron {
            id: linkChevron
            anchors.right: parent.right
            anchors.rightMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            active: linkPill.hovered
          }
        }
      }
    }

    Pill {
      visible: view.show.media
      width: view.links.length > 0 ? (view.w - 10) / 2 : view.w
      height: Math.max(142, linkColumn.implicitHeight)
      radius: 26

      Item {
        anchors.fill: parent
        anchors.margins: 14

        Rectangle {
          id: art
          width: 44
          height: 44
          radius: 10
          color: view.hasPlayer ? view.accent : view.dotOffBg
          clip: true

          Rectangle {
            anchors.fill: parent
            visible: view.hasPlayer && picture.status !== Image.Ready
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0.0; color: view.accent }
              GradientStop { position: 0.6; color: "#db34f2" }
              GradientStop { position: 1.0; color: "#ff9230" }
            }
          }

          Glyph {
            anchors.centerIn: parent
            visible: picture.status !== Image.Ready
            code: 0xF075A
            color: view.hasPlayer ? "#ffffff" : view.dim
            font.pixelSize: 21
          }

          Image {
            id: picture
            anchors.fill: parent
            source: view.media.art || ""
            sourceSize.width: 88
            sourceSize.height: 88
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
          }
        }

        Rectangle {
          visible: !!view.media.player
          anchors.right: parent.right
          anchors.top: parent.top
          width: Math.min(sourceLabel.implicitWidth + 14, parent.width - art.width - 8)
          height: 20
          radius: 10
          color: Qt.alpha(view.foreground, 0.10)

          Label {
            id: sourceLabel
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - 10)
            text: view.media.player || ""
            color: view.dim
            font.pixelSize: 10
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
          }
        }

        Column {
          anchors.left: parent.left
          anchors.right: parent.right
          y: art.height + 9
          spacing: 1

          Label {
            width: parent.width
            text: view.mediaTitle
            font.weight: Font.DemiBold
          }
          Label {
            width: parent.width
            visible: text !== ""
            text: view.mediaSub
            color: view.dim
            font.pixelSize: 11
          }
        }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          spacing: 10

          Step { verb: "previous"; code: 0xF04AE; iconSize: 16 }
          Step { verb: "playpause"; code: view.playing ? 0xF03E4 : 0xF040A; iconSize: 20 }
          Step { verb: "next"; code: 0xF04AD; iconSize: 16 }
        }
      }
    }
  }

  Row {
    width: view.w
    spacing: 10

    Pill {
      id: focusPill
      visible: view.show.focus
      width: view.w - 152
      height: 62
      anchors.verticalCenter: parent.verticalCenter
      radius: 31
      hovered: focusArea.containsMouse

      MouseArea {
        id: focusArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: view.act(["focus"])
      }

      Dot {
        id: focusDot
        x: 11
        anchors.verticalCenter: parent.verticalCenter
        on: !!view.focusInfo.on
        code: 0xF009B
        size: 40
        onBg: view.focusOnBg
        onInk: view.focusOnInk
      }

      Column {
        anchors.left: focusDot.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Label {
          width: parent.width
          text: qsTr("Focus")
          font.weight: Font.DemiBold
        }
        Label {
          width: parent.width
          text: view.focusInfo.on ? qsTr("On") : qsTr("Off")
          color: view.dim
          font.pixelSize: 11
        }
      }
    }

    Item {
      visible: !view.show.focus
      width: view.w - 152
      height: 66
    }

    Rectangle {
      id: themeCircle
      width: 66
      height: 66
      radius: 33
      color: view.dark
        ? (themeArea.containsMouse ? "#f2f2f5" : "#ffffff")
        : (themeArea.containsMouse ? view.pillBgHover : view.pillBg)
      border.width: 1
      border.color: view.dark
        ? Qt.rgba(1, 1, 1, 0.95)
        : (themeArea.containsMouse ? view.pillRimHover : view.pillRim)

      Item {
        anchors.centerIn: parent
        width: 22
        height: 22

        Rectangle {
          anchors.fill: parent
          radius: 11
          color: "transparent"
          border.width: 2
          border.color: view.dark ? "#16181c" : view.foreground
        }

        Item {
          x: 11
          width: 11
          height: 22
          clip: true

          Rectangle {
            x: -11
            width: 22
            height: 22
            radius: 11
            color: view.dark ? "#16181c" : view.foreground
          }
        }
      }

      MouseArea {
        id: themeArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: view.act(["theme", view.dark ? "light" : "dark"])
      }
    }

    Rectangle {
      id: nightCircle
      readonly property bool active: !!view.nightlightInfo.on
      width: 66
      height: 66
      radius: 33
      color: active
        ? Qt.rgba(1, 0.62, 0.25, nightArea.containsMouse ? 0.95 : 0.88)
        : (nightArea.containsMouse ? view.pillBgHover : view.pillBg)
      border.width: 1
      border.color: active
        ? Qt.rgba(1, 0.84, 0.6, 0.85)
        : (nightArea.containsMouse ? view.pillRimHover : view.pillRim)

      Glyph {
        anchors.centerIn: parent
        code: 0xF05A8
        font.pixelSize: 22
        color: nightCircle.active ? "#1c1205" : view.foreground
      }

      MouseArea {
        id: nightArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: view.act(["nightlight"])
      }
    }
  }

  Repeater {
    model: view.sliders

    Pill {
      id: slide
      required property var modelData
      readonly property var percent: modelData.screen ? view.display.percent : view.sound.percent
      readonly property real value: percent === undefined ? -1 : percent
      readonly property real shown: sliderDrag.pressed ? sliderDrag.value : value
      readonly property bool activeHover: slideArea.containsMouse || sliderDrag.containsMouse || sliderDrag.pressed

      width: view.w
      height: 76
      radius: 30
      hovered: activeHover

      MouseArea {
        id: slideArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: view.act(["picker", slide.modelData.picker])
      }

      Label {
        x: 16
        y: 12
        text: slide.modelData.name
        font.weight: Font.DemiBold
      }

      Label {
        anchors.right: slideChevron.left
        anchors.rightMargin: 6
        y: 13
        text: slide.value < 0 ? qsTr("No data") : Math.round(slide.shown) + "%"
        color: view.dim
        font.pixelSize: 11
        opacity: slide.activeHover ? 0.9 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
      }

      Chevron {
        id: slideChevron
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 8
        active: slide.activeHover
      }

      Item {
        x: 16
        y: 41
        width: parent.width - 32
        height: 22

        Glyph {
          id: leftIcon
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: 18
          code: slide.modelData.screen ? 0xF05A8 : view.soundLowCode
          color: view.foreground
          opacity: 0.85
          font.pixelSize: slide.modelData.screen ? 13 : 14
        }

        Glyph {
          id: rightIcon
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: 20
          code: slide.modelData.screen ? 0xF05A8 : 0xF028
          color: view.foreground
          opacity: 0.88
          font.pixelSize: slide.modelData.screen ? 18 : 16
        }

        Item {
          id: trackWrap
          anchors.left: leftIcon.right
          anchors.leftMargin: 10
          anchors.right: rightIcon.left
          anchors.rightMargin: 10
          height: parent.height
          readonly property real ratio: Math.max(0, Math.min(1, slide.shown / 100))

          Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 5
            radius: 2.5
            color: view.trackBg

            Rectangle {
              visible: slide.value >= 0
              width: parent.width * trackWrap.ratio
              height: parent.height
              radius: parent.radius
              color: view.trackFill
            }
          }

          Rectangle {
            visible: slide.value >= 0
            width: 24
            height: 15
            radius: 7.5
            x: Math.max(0, Math.min(trackWrap.width - width, trackWrap.width * trackWrap.ratio - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            color: "#ffffff"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, view.dark ? 0.25 : 0.16)
            opacity: slide.activeHover ? 1 : 0
            scale: slide.activeHover ? 1 : 0.72
            Behavior on opacity { NumberAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 140 } }
          }

          MouseArea {
            id: sliderDrag
            property int value: 0
            readonly property int floor: slide.modelData.screen ? 1 : 0
            function read() {
              value = Math.max(floor, Math.min(100, Math.round(100 * mouseX / Math.max(1, trackWrap.width))))
            }
            anchors.fill: parent
            hoverEnabled: true
            enabled: slide.value >= 0
            preventStealing: true
            onPressed: read()
            onPositionChanged: if (pressed) read()
            onReleased: view.act([slide.modelData.key, String(value)])
          }
        }
      }
    }
  }
}
