import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// The popup under the ring: the timer big, the goal bar with the fire
// beside it, and the task list. Keyboard first — the same keys the
// terminal panel uses — and every row is clickable too.
//
//   ↵ / space  start the task under the cursor (or pause / resume a timer)
//   j k ↑ ↓    move
//   n          new task: type a name, ↵ adds it and starts the timer
//   d          tick the task under the cursor
//   x          delete it
//   p          pause / resume        s  stop        b  rest
//   t          open the full terminal panel
Panel {
  id: root
  moduleName: "io.github.pyasma.pomo"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var service: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: Color.popups.text
  readonly property color dim: Util.alpha(foreground, 0.55)
  readonly property color faint: Util.alpha(foreground, 0.28)
  readonly property color accent: Color.accent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var tasks: service ? service.tasks : []
  readonly property int rowHeight: Style.spacing.popupRowHeight
  readonly property int visibleRows: Math.min(7, Math.max(3, tasks.length))

  property int cursor: 0
  property bool composing: false
  property int flares: 0

  function open() {
    composing = false
    cursor = currentIndex()
    if (service) service.refresh()
    controller.show()
  }
  function close() {
    composing = false
    controller.hide()
  }
  function toggle() { opened ? close() : open() }

  function currentIndex() {
    if (!service || service.state.task === null || service.state.task === undefined) return 0
    for (var i = 0; i < tasks.length; i++) if (tasks[i].id === service.state.task) return i
    return 0
  }
  function clampCursor() {
    if (cursor >= tasks.length) cursor = Math.max(0, tasks.length - 1)
    if (cursor < 0) cursor = 0
  }
  function move(d) {
    if (tasks.length === 0) return
    cursor = ((cursor + d) % tasks.length + tasks.length) % tasks.length
  }
  function selected() { return tasks.length > 0 && cursor < tasks.length ? tasks[cursor] : null }

  function activate() {
    if (!service) return
    var t = selected()
    if (!t) { beginCompose(); return }
    // Enter on the running task is pause/resume; on any other, start it.
    if (!service.idle && service.state.task === t.id) service.toggle()
    else service.start(t.id)
  }
  function tick() { var t = selected(); if (t && service) service.done(t.id) }
  function remove() { var t = selected(); if (t && service) service.remove(t.id) }

  function beginCompose() {
    composing = true
    composer.text = ""
    Qt.callLater(function() { composer.forceActiveFocus() })
  }
  function endCompose() {
    composing = false
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }
  function submitCompose() {
    var name = composer.text.trim()
    endCompose()
    if (name !== "" && service) service.newTask(name)
  }

  function key(t) {
    if (!service) return
    switch (t) {
    case "n": beginCompose(); break
    case "d": tick(); break
    case "p": service.toggle(); break
    case "s": service.stop(); break
    case "b": service.rest(); break
    case "t": close(); service.openTui(); break
    case "r": service.refresh(); break
    }
  }

  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function") return bar.switchPanelFrom(barIdentity, direction)
    return false
  }

  // Column.implicitHeight is unreliable for children that size themselves
  // through bindings, so the card height is summed by hand.
  readonly property real wantedHeight: {
    var kids = [hero, goalRow, sep1, composer, emptyNote, list, sep2, actions]
    var h = 0, n = 0
    for (var i = 0; i < kids.length; i++) {
      if (!kids[i].visible) continue
      h += kids[i].implicitHeight
      n += 1
    }
    return h + Math.max(0, n - 1) * content.spacing
  }

  onTasksChanged: clampCursor()

  Connections {
    target: root.service
    function onTierClimbed(tier) { root.flares += 1 }
    function onGoalJustCleared() { root.flares += 1 }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(root.wantedHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.composing

      onMoveRequested: function(dx, dy) { if (dy !== 0) root.move(dy) }
      onActivateRequested: root.activate()
      onCloseRequested: root.close()
      onDeleteRequested: root.remove()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) { root.key(t) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        // ---- the timer
        Item {
          id: hero
          width: parent.width
          height: Math.round(Style.font.displayLarge * 2.6)
          implicitHeight: height

          Ring {
            id: bigRing
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height
            height: parent.height
            progress: root.service ? root.service.progress : 0
            track: root.faint
            fill: root.service && root.service.working ? root.accent : root.foreground
            strokeWidth: Math.max(3, Style.spaceReal(4))
            paused: root.service ? root.service.paused : false
            idle: root.service ? root.service.idle : true

            Text {
              anchors.centerIn: parent
              text: root.service && !root.service.idle ? root.service.remainingText : "—"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: root.service && !root.service.idle && root.service.remainingText.length > 4
                ? Style.font.subtitle : Style.font.title
              font.bold: true
            }
          }

          Column {
            anchors.left: bigRing.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(3)

            Text {
              width: parent.width
              elide: Text.ElideRight
              text: {
                if (!root.service || !root.service.loaded) return "pomo"
                if (!root.service.available) return "pomo is not installed"
                if (root.service.idle) return "Idle"
                return root.service.label
              }
              color: root.service && root.service.working ? root.accent : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
            }
            Text {
              width: parent.width
              elide: Text.ElideRight
              text: root.service && root.service.title !== "" ? root.service.title
                : (root.service && root.service.idle ? "pick a task, or press n" : "")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }
            Text {
              width: parent.width
              text: root.service ? root.service.today + " pomodoros today · " + root.service.minutes + "m focus" : ""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        // ---- the goal, and the fire
        Item {
          id: goalRow
          width: parent.width
          height: Math.max(goalBar.implicitHeight, fire.implicitHeight)
          implicitHeight: height
          visible: root.service && root.service.goal > 0

          Row {
            id: goalBar
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(3)

            Repeater {
              model: root.service ? root.service.goal : 0
              Rectangle {
                required property int index
                width: Style.space(18)
                height: Style.space(6)
                radius: height / 2
                color: root.service && index < root.service.today
                  ? (root.service.goalCleared ? "#7bc275" : root.accent)
                  : root.faint
                Behavior on color { ColorAnimation { duration: 300 } }
              }
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              leftPadding: Style.space(6)
              text: root.service ? root.service.today + " of " + root.service.goal + " today" : ""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)
            visible: root.service && root.service.streak > 0

            Fire {
              id: fire
              anchors.verticalCenter: parent.verticalCenter
              tier: root.service ? root.service.tier : 0
              size: Style.font.iconLarge * 1.3
              trigger: root.flares
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.service ? root.service.streak + " day streak" : ""
              color: fire.colour
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: root.service && root.service.tier >= 3
            }
          }
        }

        PanelSeparator { id: sep1; width: parent.width }

        // ---- new task, when composing
        TextField {
          id: composer
          width: parent.width
          visible: root.composing
          placeholderText: "new task — ↵ starts it, esc cancels"
          font.family: root.fontFamily
          onAccepted: root.submitCompose()
          Keys.onEscapePressed: root.endCompose()
        }

        // ---- the tasks
        Text {
          id: emptyNote
          visible: root.tasks.length === 0 && !root.composing
          width: parent.width
          text: "no tasks — press n"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          horizontalAlignment: Text.AlignHCenter
          topPadding: Style.space(6)
          bottomPadding: Style.space(6)
        }

        ListView {
          id: list
          width: parent.width
          height: root.tasks.length === 0 ? 0 : Math.min(root.tasks.length, 7) * root.rowHeight
          implicitHeight: height
          clip: true
          model: root.tasks
          currentIndex: root.cursor
          highlightMoveDuration: 80
          boundsBehavior: Flickable.StopAtBounds
          interactive: root.tasks.length > 7

          delegate: Item {
            id: row
            required property var modelData
            required property int index
            width: list.width
            height: root.rowHeight
            readonly property bool hot: root.cursor === index
            readonly property bool current: root.service && !root.service.idle && root.service.state.task === modelData.id

            Rectangle {
              anchors.fill: parent
              radius: Style.space(4)
              color: row.hot ? Util.alpha(root.foreground, 0.08) : "transparent"
            }

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(8)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(12)
                text: row.current ? "▸" : ""
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(12) - dots.width - meta.width - parent.spacing * 3
                elide: Text.ElideRight
                text: row.modelData.title
                color: row.current ? root.accent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
              Row {
                id: dots
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)
                readonly property int cap: Math.min(6, row.modelData.est || 1)
                Repeater {
                  model: dots.cap
                  Rectangle {
                    required property int index
                    width: Style.space(5)
                    height: width
                    radius: width / 2
                    color: index < (row.modelData.done || 0) ? "#7bc275" : root.faint
                  }
                }
              }
              Text {
                id: meta
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.wmin ? row.modelData.wmin + "m" : ""
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
              onContainsMouseChanged: if (containsMouse) root.cursor = row.index
              onClicked: function(m) {
                root.cursor = row.index
                if (m.button === Qt.LeftButton) root.activate()
                else if (m.button === Qt.RightButton) root.tick()
                else root.remove()
              }
            }
          }
        }

        PanelSeparator { id: sep2; width: parent.width }

        // ---- actions
        Row {
          id: actions
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(14)

          Button {
            iconText: root.service && root.service.running ? "󰏤" : "󰐊"
            tooltipText: (root.service && root.service.running ? "pause" : (root.service && root.service.paused ? "resume" : "start")) + "  ·  p"
            iconSize: Style.font.iconLarge
            foreground: root.foreground
            accent: root.accent
            onClicked: {
              if (!root.service) return
              if (root.service.idle) root.activate()
              else root.service.toggle()
            }
          }
          Button {
            iconText: "󰓛"
            tooltipText: "stop  ·  s"
            iconSize: Style.font.iconLarge
            foreground: root.foreground
            accent: root.accent
            enabled: root.service && !root.service.idle
            opacity: enabled ? 1 : 0.4
            onClicked: if (root.service) root.service.stop()
          }
          Button {
            iconText: "󰅶"
            tooltipText: "rest  ·  b"
            iconSize: Style.font.iconLarge
            foreground: root.foreground
            accent: root.accent
            onClicked: if (root.service) root.service.rest()
          }
          Button {
            iconText: "󰐕"
            tooltipText: "new task  ·  n"
            iconSize: Style.font.iconLarge
            foreground: root.foreground
            accent: root.accent
            onClicked: root.beginCompose()
          }
          Button {
            iconText: "󰆍"
            tooltipText: "terminal panel  ·  t"
            iconSize: Style.font.iconLarge
            foreground: root.foreground
            accent: root.accent
            onClicked: { root.close(); if (root.service) root.service.openTui() }
          }
        }
      }
    }
  }
}
