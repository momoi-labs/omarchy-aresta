import QtQuick

QtObject {
  property color background: "#1e1e1e"
  property color foreground: "#dddddd"
  property color accent: "#0a84ff"

  function mix(amount) { return Qt.tint(background, Qt.alpha(foreground, amount)) }
  function luminance(c) {
    function channel(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
  }

  readonly property color window: background
  readonly property color sidebar: mix(0.06)
  readonly property color box: mix(0.05)
  readonly property color control: mix(0.14)
  readonly property color controlSoft: mix(0.09)
  readonly property color controlBorder: Qt.alpha(foreground, 0.1)
  readonly property color separator: Qt.alpha(foreground, 0.1)
  readonly property color text: foreground
  readonly property color textSecondary: mix(0.62)
  readonly property color textTertiary: mix(0.38)
  readonly property color hover: Qt.alpha(foreground, 0.06)
  readonly property color key: mix(0.16)
  readonly property color keyBorder: Qt.alpha(foreground, 0.16)
  readonly property color accentText: luminance(accent) > 0.3 ? "#111113" : "#ffffff"
  readonly property color knob: "#ffffff"
  readonly property color knobBorder: Qt.rgba(0, 0, 0, 0.15)
  readonly property color record: "#ff5f57"

  readonly property string fontFamily: {
    var families = Qt.fontFamilies()
    var preferred = ["SF Pro Text", "SF Pro", "System Font", "Inter"]
    for (var i = 0; i < preferred.length; i++)
      if (families.indexOf(preferred[i]) !== -1) return preferred[i]
    return "sans-serif"
  }
}
