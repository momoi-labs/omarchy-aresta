// Copyright (c) 2026 Sebastian Webber
// Licensed under the MIT License. See LICENSE.

import QtQuick
import QtQuick.Shapes

Shape {
  id: root

  property real radius: 16
  property real power: 3.4
  property color color: "transparent"
  property color borderColor: "transparent"
  property real borderWidth: 1

  preferredRendererType: Shape.CurveRenderer

  function outline(w, h, r, p, inset) {
    var left = inset, top = inset, right = w - inset, bottom = h - inset
    r = Math.max(0, Math.min(r - inset, (right - left) / 2, (bottom - top) / 2))
    var corners = [
      { x: right - r, y: top + r, from: -Math.PI / 2 },
      { x: right - r, y: bottom - r, from: 0 },
      { x: left + r, y: bottom - r, from: Math.PI / 2 },
      { x: left + r, y: top + r, from: Math.PI }
    ]
    var steps = 16
    var points = []
    for (var c = 0; c < corners.length; c++) {
      for (var i = 0; i <= steps; i++) {
        var t = corners[c].from + (Math.PI / 2) * i / steps
        var cos = Math.cos(t), sin = Math.sin(t)
        points.push(Qt.point(
          corners[c].x + r * Math.sign(cos) * Math.pow(Math.abs(cos), 2 / p),
          corners[c].y + r * Math.sign(sin) * Math.pow(Math.abs(sin), 2 / p)))
      }
    }
    points.push(points[0])
    return points
  }

  ShapePath {
    fillColor: root.color
    strokeColor: root.borderColor
    strokeWidth: root.borderWidth
    PathPolyline { path: root.outline(root.width, root.height, root.radius, root.power, root.borderWidth / 2) }
  }
}
