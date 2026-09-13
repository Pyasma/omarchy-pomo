import QtQuick

// The timer as a ring: the arc fills clockwise as the phase runs out,
// dashed while paused, empty when idle.
Item {
  id: root

  property real progress: 0
  property color track: "#404040"
  property color fill: "#cccccc"
  property real strokeWidth: 2
  property bool paused: false
  property bool idle: true
  property bool showIdleDot: true

  onProgressChanged: canvas.requestPaint()
  onTrackChanged: canvas.requestPaint()
  onFillChanged: canvas.requestPaint()
  onPausedChanged: canvas.requestPaint()
  onIdleChanged: canvas.requestPaint()
  onShowIdleDotChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()

  Canvas {
    id: canvas
    anchors.fill: parent
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var w = width, h = height
      var r = Math.min(w, h) / 2 - root.strokeWidth
      var cx = w / 2, cy = h / 2
      ctx.lineWidth = root.strokeWidth
      ctx.lineCap = "round"

      ctx.strokeStyle = root.track
      ctx.beginPath()
      ctx.arc(cx, cy, r, 0, Math.PI * 2)
      ctx.stroke()

      if (root.idle) {
        if (!root.showIdleDot) return
        // A dot at twelve: the hand of a clock that has nothing to count.
        ctx.fillStyle = root.fill
        ctx.beginPath()
        ctx.arc(cx, cy - r, root.strokeWidth * 0.9, 0, Math.PI * 2)
        ctx.fill()
        return
      }
      var start = -Math.PI / 2
      var end = start + Math.PI * 2 * Math.max(0.002, root.progress)
      ctx.strokeStyle = root.fill
      if (root.paused) ctx.setLineDash([root.strokeWidth * 1.2, root.strokeWidth * 1.4])
      ctx.beginPath()
      ctx.arc(cx, cy, r, start, end)
      ctx.stroke()
      ctx.setLineDash([])
    }
  }
}
