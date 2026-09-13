import QtQuick
import Quickshell
import Quickshell.Io

// The bridge to the pomo CLI. Everything the widget and the panel show comes
// from one `pomo json` read, polled once a second while a timer runs and
// every five when nothing does. Actions are the same commands a terminal
// would run; each one is followed by a fresh read so the shell never has to
// guess what pomo did with it.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string home: Quickshell.env("HOME") || ""
  property string configuredPath: ""
  readonly property string pomo: configuredPath !== "" ? configuredPath : home + "/.local/bin/pomo"

  property var state: ({})
  property bool loaded: false
  property bool available: true
  property double fetchedAt: 0

  readonly property string phase: state.phase || "idle"
  readonly property string label: state.label || "Idle"
  readonly property bool idle: phase === "idle"
  readonly property bool paused: phase === "paused"
  readonly property bool running: !idle && !paused
  readonly property bool working: phase === "work"
  readonly property string title: state.title || ""
  readonly property int total: state.total || 0
  readonly property int today: state.today || 0
  readonly property int minutes: state.minutes || 0
  readonly property int goal: state.goal || 0
  readonly property int streak: state.streak || 0
  readonly property int tier: state.tier || 0
  readonly property string fire: state.fire || ""
  readonly property var tasks: state.tasks || []
  readonly property var sessions: state.sessions || null
  readonly property bool goalCleared: goal > 0 && today >= goal

  // Seconds left, counted down locally between polls so the digits move
  // every second even though pomo is only asked once a second at best.
  property double nowMs: Date.now()
  readonly property int remaining: {
    var base = state.remaining || 0
    if (!running) return base
    var drift = Math.floor((nowMs - fetchedAt) / 1000)
    return Math.max(0, base - drift)
  }
  readonly property real progress: total > 0 ? Math.min(1, Math.max(0, 1 - remaining / total)) : 0
  readonly property string remainingText: {
    var s = remaining
    var m = Math.floor(s / 60)
    var r = s % 60
    return m + ":" + (r < 10 ? "0" : "") + r
  }

  // Milestones: the moment the streak tier climbs, or the goal clears, the
  // panel gets to celebrate. Tracked here so every surface sees the same event.
  property int lastTier: -1
  property bool lastCleared: false
  signal tierClimbed(int tier)
  signal goalJustCleared()

  function configure(settings) {
    var next = settings && settings.pomoPath ? String(settings.pomoPath) : ""
    if (next !== configuredPath) {
      configuredPath = next
      refresh()
    }
  }

  function refresh() {
    if (poll.running) return
    poll.running = true
  }

  function run(args) {
    Quickshell.execDetached([pomo].concat(args))
    refreshSoon.restart()
  }

  function toggle() { run(["toggle"]) }
  function stop() { run(["stop"]) }
  function start(id) { run(id === undefined || id === null ? ["start"] : ["start", String(id)]) }
  function rest() { run(["break"]) }
  function done(id) { run(["done", String(id)]) }
  function remove(id) { run(["rm", String(id)]) }
  function newTask(title) { run(["new", title]) }
  function addTask(title) { run(["add", title]) }
  function openTui() {
    Quickshell.execDetached(["omarchy-launch-or-focus-tui", pomo, "tui"])
  }

  function apply(text) {
    var next = null
    try { next = JSON.parse(text) } catch (e) { next = null }
    if (!next || typeof next !== "object") {
      available = false
      loaded = true
      return
    }
    available = true
    fetchedAt = Date.now()
    nowMs = fetchedAt
    state = next
    loaded = true

    var primed = lastTier >= 0
    var t = next.tier || 0
    var cleared = (next.goal || 0) > 0 && (next.today || 0) >= (next.goal || 0)
    if (primed && t > lastTier) tierClimbed(t)
    if (primed && cleared && !lastCleared) goalJustCleared()
    lastTier = t
    lastCleared = cleared
  }

  Component.onCompleted: refresh()

  Process {
    id: poll
    command: [root.pomo, "json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.apply(text)
    }
    onExited: function(code) {
      if (code !== 0) { root.available = false; root.loaded = true }
    }
  }

  Timer {
    interval: root.running ? 1000 : 5000
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  Timer {
    interval: 250
    repeat: true
    running: root.running
    onTriggered: root.nowMs = Date.now()
  }

  Timer {
    id: refreshSoon
    interval: 350
    repeat: false
    onTriggered: root.refresh()
  }

  IpcHandler {
    target: "pomo"

    function refresh(): void { root.refresh() }
    function toggle(): void { root.toggle() }
    function stop(): void { root.stop() }
  }
}
