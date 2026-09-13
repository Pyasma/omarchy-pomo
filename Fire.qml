import QtQuick
import qs.Commons

// The streak, burning — drawn, not typed. The shape is the one every streak
// app uses: a rounded teardrop of flame with a smaller, paler flame inside
// it. Bright while the run lives, grey when there is nothing to count. One
// flame from the first day, two from three, three from seven, and the colour
// climbs from orange towards white-hot with the run. Each flame flickers on
// its own clock so a row never moves in lockstep.
Item {
  id: root

  property int tier: 0
  property real size: Style.font.iconLarge
  property string fontFamily: Style.font.family
  property bool glow: true
  property bool sway: true
  property bool lit: true
  property color dimColour: "#8a8a8a"
  property color dimInner: "#c4c4c4"
  // Flames by tier, or a fixed count where there is room for only one.
  property int flames: tier <= 0 ? 0 : (tier < 2 ? 1 : (tier < 3 ? 2 : 3))
  // A burst plays when the tier climbs: the flames leap, then settle.
  property real burst: 0
  property int trigger: 0
  onTriggerChanged: flare()

  readonly property int shown: !lit ? 1 : (tier <= 0 ? 0 : flames)
  readonly property color colour: !lit ? dimColour
    : tier >= 4 ? "#ffb300"
    : tier === 3 ? "#ff5a00"
    : tier === 2 ? "#ff7a00"
    : "#ff9600"
  readonly property color inner: !lit ? dimInner
    : tier >= 4 ? "#fff3c4"
    : tier === 3 ? "#ffd000"
    : "#ffc800"
  readonly property color glowColour: colour
  readonly property real flameWidth: size * 0.9

  visible: shown > 0
  implicitWidth: shown > 0 ? shown * flameWidth + (shown - 1) * Math.round(size * 0.04) : 0
  implicitHeight: size

  Rectangle {
    visible: root.glow && root.lit
    anchors.centerIn: parent
    width: parent.width + root.size * 0.9
    height: parent.height + root.size * 0.5
    radius: height / 2
    color: root.glowColour
    opacity: 0.10 + root.burst * 0.25
    SequentialAnimation on scale {
      loops: Animation.Infinite
      running: root.visible
      NumberAnimation { to: 1.08; duration: 900; easing.type: Easing.InOutSine }
      NumberAnimation { to: 0.94; duration: 1100; easing.type: Easing.InOutSine }
    }
  }

  Row {
    anchors.centerIn: parent
    spacing: Math.round(root.size * 0.04)

    Repeater {
      model: root.shown

      Item {
        id: flame
        required property int index
        width: root.flameWidth
        height: root.size
        readonly property real base: root.shown === 3 && index === 1 ? 1.1 : 1.0
        readonly property int beat: 420 + index * 130 + (root.tier * 37) % 90
        transformOrigin: Item.Bottom

        Canvas {
          id: body
          anchors.fill: parent
          transformOrigin: Item.Bottom
          scale: flame.base * (1 + root.burst * 0.35)
          onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var w = width, h = height
            function P(x, y) { return [x * w, y * h] }
            function path(pts) {
              ctx.beginPath()
              ctx.moveTo.apply(ctx, P(pts[0][0], pts[0][1]))
              for (var i = 1; i < pts.length; i += 3)
                ctx.bezierCurveTo(
                  pts[i][0] * w, pts[i][1] * h,
                  pts[i + 1][0] * w, pts[i + 1][1] * h,
                  pts[i + 2][0] * w, pts[i + 2][1] * h)
              ctx.closePath()
            }
            // Outer flame: a teardrop that leans into its tip at top-right.
            path([[0.56, 0.02],
              [0.62, 0.20], [0.92, 0.34], [0.92, 0.62],
              [0.92, 0.84], [0.74, 1.00], [0.50, 1.00],
              [0.26, 1.00], [0.08, 0.84], [0.08, 0.62],
              [0.08, 0.46], [0.20, 0.36], [0.28, 0.26],
              [0.30, 0.38], [0.38, 0.44], [0.44, 0.42],
              [0.40, 0.28], [0.46, 0.12], [0.56, 0.02]])
            ctx.fillStyle = root.colour
            ctx.fill()
            // Inner flame, paler, sitting low in the body.
            path([[0.52, 0.52],
              [0.60, 0.62], [0.70, 0.68], [0.70, 0.80],
              [0.70, 0.91], [0.61, 0.98], [0.50, 0.98],
              [0.39, 0.98], [0.30, 0.91], [0.30, 0.80],
              [0.30, 0.72], [0.36, 0.66], [0.40, 0.62],
              [0.43, 0.68], [0.49, 0.70], [0.52, 0.52]])
            ctx.fillStyle = root.inner
            ctx.fill()
          }
          Component.onCompleted: requestPaint()
          Connections {
            target: root
            function onColourChanged() { body.requestPaint() }
            function onInnerChanged() { body.requestPaint() }
          }
          onWidthChanged: requestPaint()
          onHeightChanged: requestPaint()

          SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: root.visible && root.lit
            NumberAnimation { to: 0.78; duration: flame.beat; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 1.0; duration: flame.beat * 0.8; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 0.88; duration: flame.beat * 0.5; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 1.0; duration: flame.beat * 1.1; easing.type: Easing.InOutQuad }
          }
        }

        SequentialAnimation on rotation {
          loops: Animation.Infinite
          running: root.visible && root.sway && root.lit
          NumberAnimation { to: -4 - flame.index; duration: flame.beat * 1.4; easing.type: Easing.InOutSine }
          NumberAnimation { to: 3 + flame.index; duration: flame.beat * 1.7; easing.type: Easing.InOutSine }
        }
      }
    }
  }

  SequentialAnimation {
    id: burstAnim
    NumberAnimation { target: root; property: "burst"; to: 1; duration: 180; easing.type: Easing.OutCubic }
    NumberAnimation { target: root; property: "burst"; to: 0; duration: 900; easing.type: Easing.OutBounce }
  }

  function flare() { burstAnim.restart() }
}
