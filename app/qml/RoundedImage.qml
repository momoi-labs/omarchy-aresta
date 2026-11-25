pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

Image {
  id: image

  property real radius: 0

  layer.enabled: true
  layer.effect: MultiEffect {
    maskEnabled: true
    maskSource: mask
    maskThresholdMin: 0.5
    maskSpreadAtMin: 1
  }

  Rectangle {
    id: mask
    width: image.width
    height: image.height
    radius: image.radius
    visible: false
    layer.enabled: true
    layer.smooth: true
  }
}
