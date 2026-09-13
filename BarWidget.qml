import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// One slot on the bar: the fire, with the timer ring drawn round it while a
// phase runs. Left click opens the panel, right click starts or pauses
// without opening anything, middle click stops.
BarWidget {
  id: root
  moduleName: "io.github.pyasma.pomo"

  readonly property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property bool showMinutes: setting("showMinutes", false) === true

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property real openPanelIndicatorWidth: layout.width
  readonly property real openPanelIndicatorHeight: Style.bar.iconCanvas

  readonly property string tooltip: {
    if (!service || !service.loaded) return "pomo"
    if (!service.available) return "pomo is not installed — see the plugin README"
    var lines = []
    if (service.idle) lines.push("idle")
    else lines.push(service.label + " " + service.remainingText + (service.title ? " — " + service.title : ""))
    lines.push(service.today + " pomodoros today · " + service.minutes + "m focus")
    if (service.goal > 0)
      lines.push("goal " + service.today + "/" + service.goal
        + (service.streak > 0 ? " · " + service.fire + " " + service.streak + " day streak" : ""))
    return lines.join("\n")
  }

  function syncService() {
    if (service && typeof service.configure === "function") service.configure(settings)
    injectPanel()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = flameButton
    if ("hostWidget" in target) target.hostWidget = root
    if ("service" in target) target.service = root.service
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  implicitWidth: vertical ? barSize : layout.implicitWidth
  implicitHeight: vertical ? layout.implicitHeight : barSize

  onBarChanged: Qt.callLater(syncService)
  onSettingsChanged: Qt.callLater(syncService)
  onServiceChanged: Qt.callLater(syncService)
  Component.onCompleted: Qt.callLater(syncService)

  property int flares: 0

  Connections {
    target: root.service
    function onTierClimbed(tier) { root.flares += 1 }
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.syncService)
    }
  }

  IpcHandler {
    target: "io.github.pyasma.pomo"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { if (root.service) root.service.refresh() }
  }

  // The streak the way every streak app draws it: a flame and the day count
  // beside it, one colour, tight. Grey flame when there is nothing to count.
  // The timer is a ring round that same flame, drawn only while a phase
  // runs — pomo spends one glyph on the bar, never two.
  readonly property bool burning: service ? service.tier > 0 : false
  readonly property bool timing: service ? !service.idle : false
  readonly property color streakColour: burning ? fireTint.colour : Util.alpha(flameButton.foreground, 0.4)

  Row {
    id: layout
    anchors.centerIn: parent
    spacing: 0

    WidgetButton {
      id: minutesLabel
      bar: root.bar
      visible: !root.vertical && root.showMinutes && root.timing
      text: root.service ? root.service.remainingText : ""
      fontSize: Style.font.bodySmall
      horizontalMargin: 2
      tooltipText: root.tooltip
      onPressed: function(b) { root.press(b) }
    }

    WidgetButton {
      id: flameButton
      bar: root.bar
      tooltipText: root.tooltip
      labelVisible: false
      hasVisualContent: true
      fixedWidth: root.vertical ? -1 : streakRow.implicitWidth + Style.spaceReal(7) * 2
      fixedHeight: root.vertical ? streakRow.implicitHeight + Style.spaceReal(4) * 2 : -1
      onPressed: function(b) { root.press(b) }

      Row {
        id: streakRow
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Style.spaceReal(0.5)
        spacing: Style.spaceReal(2)

        // The flame sits inside the timer ring: one glyph, the arc drawn
        // round it while a phase runs, nothing round it when idle.
        Item {
          anchors.verticalCenter: parent.verticalCenter
          width: Style.bar.iconCanvas + Style.spaceReal(4)
          height: width

          Ring {
            anchors.fill: parent
            visible: root.timing
            progress: root.service ? root.service.progress : 0
            track: Util.alpha(flameButton.foreground, 0.28)
            fill: root.service && root.service.working ? Color.accent : flameButton.foreground
            strokeWidth: Math.max(2, Style.spaceReal(1.5))
            paused: root.service ? root.service.paused : false
            idle: false
          }
          Fire {
            anchors.centerIn: parent
            tier: root.service ? Math.max(1, root.service.tier) : 1
            flames: 1
            size: Style.bar.iconCanvas * 0.72
            glow: false
            sway: false
            lit: root.burning
            dimColour: root.streakColour
            trigger: root.flares
          }
        }
        Text {
          visible: root.burning
          anchors.verticalCenter: parent.verticalCenter
          text: root.service ? String(root.service.streak) : ""
          color: root.streakColour
          font.family: flameButton.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          renderType: Text.NativeRendering
        }
      }
    }
  }

  function press(b) {
    if (!service) return
    if (b === Qt.RightButton) service.toggle()
    else if (b === Qt.MiddleButton) service.stop()
    else toggle()
  }

  // Colour lookup only — never drawn.
  Fire { id: fireTint; visible: false; tier: root.service ? root.service.tier : 0 }
}
