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
  property bool outputsOpen: false

  signal act(var command)

  function luminance(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }

  readonly property int w: 316
  readonly property bool dark: luminance(background) < 0.4
  readonly property color card: Qt.alpha(foreground, dark ? 0.09 : 0.055)
  readonly property color well: Qt.alpha(foreground, dark ? 0.17 : 0.12)
  readonly property color dim: Qt.alpha(foreground, 0.58)
  readonly property color fill: dark ? "#f2f2f4" : "#48484a"
  readonly property color fillInk: dark ? "#5a5a5f" : "#ffffff"

  readonly property var wifi: info.wifi || ({})
  readonly property var bt: info.bt || ({})
  readonly property var focusInfo: info.focus || ({})
  readonly property var display: info.display || ({})
  readonly property var sound: info.sound || ({})
  readonly property var media: info.media || ({})
  readonly property var btDevices: bt.devices || []
  readonly property var outputs: sound.outputs || []

  readonly property string wifiText: !wifi.on ? qsTr("Off") : wifi.ssid ? wifi.ssid : qsTr("Not Connected")
  readonly property string btText: !bt.on ? qsTr("Off") : btDevices.length === 0 ? qsTr("On") : btDevices.length === 1 ? btDevices[0] : qsTr("%1 devices").arg(btDevices.length)
  readonly property bool playing: media.status === "Playing"
  readonly property bool hasPlayer: !!media.bus
  readonly property string mediaTitle: media.title ? media.title : qsTr("Not Playing")
  readonly property string mediaSub: media.title ? (media.artist || media.player || "") : (media.player || "")
  readonly property int wifiCode: [0xF092F, 0xF091F, 0xF0922, 0xF0925, 0xF0928][!wifi.on || !wifi.ssid ? 0 : Math.max(1, Math.min(4, Math.ceil((wifi.signal || 0) / 25)))]
  readonly property int soundCode: sound.muted || !sound.percent ? 0xEEE8 : sound.percent <= 33 ? 0xF026 : sound.percent <= 66 ? 0xF027 : 0xF028

  readonly property var links: {
    var out = []
    if (show.wifi) out.push({ id: "wifi", picker: "omarchy.network", name: qsTr("Wi-Fi"), status: wifiText, on: !!wifi.on, code: wifiCode })
    if (show.bluetooth) out.push({ id: "bluetooth", picker: "omarchy.bluetooth", name: qsTr("Bluetooth"), status: btText, on: !!bt.on, code: 0xF00AF })
    return out
  }
  readonly property var sliders: {
    var out = []
    if (show.display) out.push({ id: "brightness", name: qsTr("Display"), percent: display.percent === undefined ? -1 : display.percent, code: 0xF0379, floor: 1 })
    if (show.sound) out.push({ id: "volume", name: qsTr("Sound"), percent: sound.percent === undefined ? -1 : sound.percent, code: soundCode, floor: 0 })
    return out
  }
  readonly property bool side: show.focus || show.sound

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

  component Dot: Rectangle {
    id: dot
    property bool on: false
    property int code: 0
    property int size: 30
    width: size
    height: size
    radius: size / 2
    color: on ? view.accent : view.well
    Glyph {
      anchors.centerIn: parent
      code: dot.code
      color: dot.on ? "#ffffff" : view.foreground
      font.pixelSize: Math.round(dot.size * 0.5)
    }
  }

  component Card: Rectangle {
    radius: 16
    color: view.card
  }

  component Step: Glyph {
    id: step
    property string verb: ""
    property bool live: view.hasPlayer
    color: live ? view.foreground : view.dim
    MouseArea {
      anchors.fill: parent
      anchors.margins: -5
      enabled: step.live
      onClicked: view.act([step.verb, view.media.bus])
    }
  }

  component Bar: Rectangle {
    id: bar
    property real percent: 0
    property int code: 0
    property int floor: 0
    readonly property real shown: drag.pressed ? drag.value : percent
    signal moved(int value)
    height: 24
    radius: height / 2
    color: view.well
    Rectangle {
      visible: bar.percent >= 0
      width: bar.height + (bar.width - bar.height) * Math.max(0, Math.min(100, bar.shown)) / 100
      height: bar.height
      radius: bar.radius
      color: view.fill
    }
    Glyph {
      x: 6
      width: 14
      anchors.verticalCenter: parent.verticalCenter
      code: bar.code
      color: bar.percent >= 0 ? view.fillInk : view.dim
      font.pixelSize: 13
    }
    MouseArea {
      id: drag
      property int value: 0
      function read() { value = Math.max(bar.floor, Math.min(100, Math.round(100 * (mouseX - bar.height / 2) / (bar.width - bar.height)))) }
      anchors.fill: parent
      enabled: bar.percent >= 0
      preventStealing: true
      onPressed: read()
      onPositionChanged: read()
      onReleased: bar.moved(value)
    }
  }

  Row {
    visible: view.links.length > 0 || view.side
    spacing: 10

    Card {
      visible: view.links.length > 0
      width: view.side ? (view.w - 10) / 2 : view.w
      height: 108

      Column {
        x: 12
        width: parent.width - 24
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Repeater {
          model: view.links
          Row {
            id: link
            required property var modelData
            width: parent.width
            spacing: 9
            Dot {
              on: link.modelData.on
              code: link.modelData.code
              size: 32
              MouseArea { anchors.fill: parent; onClicked: view.act([link.modelData.id, link.modelData.on ? "off" : "on"]) }
            }
            Item {
              width: parent.width - 41
              height: texts.height
              anchors.verticalCenter: parent.verticalCenter
              Column {
                id: texts
                width: parent.width
                Label { width: parent.width; text: link.modelData.name; font.weight: Font.DemiBold }
                Label { width: parent.width; text: link.modelData.status; color: view.dim; font.pixelSize: 11 }
              }
              MouseArea { anchors.fill: parent; onClicked: view.act(["picker", link.modelData.picker]) }
            }
          }
        }
      }
    }

    Column {
      visible: view.side
      width: view.links.length > 0 ? (view.w - 10) / 2 : view.w
      spacing: 10

      Card {
        visible: view.show.focus
        width: parent.width
        height: view.show.sound ? 49 : 108

        Row {
          x: 12
          width: parent.width - 24
          anchors.verticalCenter: parent.verticalCenter
          spacing: 9
          Dot { on: !!view.focusInfo.on; code: 0xF009B; size: 30 }
          Column {
            width: parent.width - 39
            anchors.verticalCenter: parent.verticalCenter
            Label { width: parent.width; text: qsTr("Focus"); font.weight: Font.DemiBold }
            Label { width: parent.width; text: view.focusInfo.on ? qsTr("On") : qsTr("Off"); color: view.dim; font.pixelSize: 11 }
          }
        }

        MouseArea { anchors.fill: parent; onClicked: view.act(["focus"]) }
      }

      Card {
        visible: view.show.sound
        width: parent.width
        height: view.show.focus ? 49 : 108

        Row {
          x: 12
          width: parent.width - 24
          anchors.verticalCenter: parent.verticalCenter
          spacing: 9
          Dot { on: view.outputsOpen; code: 0xF04C3; size: 30 }
          Column {
            width: parent.width - 39
            anchors.verticalCenter: parent.verticalCenter
            Label { width: parent.width; text: qsTr("Output"); font.weight: Font.DemiBold }
            Label { width: parent.width; text: view.sound.sink || qsTr("None"); color: view.dim; font.pixelSize: 11 }
          }
        }

        MouseArea { anchors.fill: parent; onClicked: view.outputsOpen = !view.outputsOpen }
      }
    }
  }

  Card {
    visible: view.show.sound && view.outputsOpen && view.outputs.length > 0
    width: view.w
    height: choices.height + 12

    Column {
      id: choices
      y: 6
      width: parent.width

      Repeater {
        model: view.outputs
        Item {
          id: choice
          required property var modelData
          width: choices.width
          height: 30
          Label { x: 14; width: parent.width - 48; anchors.verticalCenter: parent.verticalCenter; text: choice.modelData.label }
          Glyph { visible: choice.modelData.current; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; code: 0xF012C; color: view.accent }
          MouseArea { anchors.fill: parent; onClicked: view.act(["output", choice.modelData.id, choice.modelData.name]) }
        }
      }
    }
  }

  Repeater {
    model: view.sliders
    Card {
      id: slide
      required property var modelData
      width: view.w
      height: 66

      Label { x: 14; y: 10; text: slide.modelData.name; font.weight: Font.DemiBold }
      Label {
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 11
        text: slide.modelData.percent < 0 ? qsTr("No data") : Math.round(level.shown) + "%"
        color: view.dim
        font.pixelSize: 11
      }
      Bar {
        id: level
        x: 12
        y: 32
        width: parent.width - 24
        percent: slide.modelData.percent
        code: slide.modelData.code
        floor: slide.modelData.floor
        onMoved: function(value) { view.act([slide.modelData.id, String(value)]) }
      }
    }
  }

  Card {
    visible: view.show.media
    width: view.w
    height: 66

    Rectangle {
      id: art
      x: 12
      width: 42
      height: 42
      radius: 8
      anchors.verticalCenter: parent.verticalCenter
      color: view.well
      clip: true
      Glyph { anchors.centerIn: parent; visible: picture.status !== Image.Ready; code: 0xF075A; color: view.dim; font.pixelSize: 21 }
      Image {
        id: picture
        anchors.fill: parent
        source: view.media.art || ""
        sourceSize.width: 84
        sourceSize.height: 84
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
      }
    }
    Column {
      anchors.left: art.right
      anchors.leftMargin: 10
      anchors.right: transport.left
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      Label { width: parent.width; text: view.mediaTitle; font.weight: Font.DemiBold }
      Label { width: parent.width; visible: text !== ""; text: view.mediaSub; color: view.dim; font.pixelSize: 11 }
    }
    Row {
      id: transport
      anchors.right: parent.right
      anchors.rightMargin: 14
      anchors.verticalCenter: parent.verticalCenter
      spacing: 12
      Step { verb: "previous"; code: 0xF04AE; font.pixelSize: 17 }
      Step { verb: "playpause"; code: view.playing ? 0xF03E4 : 0xF040A; font.pixelSize: 20 }
      Step { verb: "next"; code: 0xF04AD; font.pixelSize: 17 }
    }
  }
}
