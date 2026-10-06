import QtQuick
import Quickshell
import Quickshell.Io

// Unsplash wallpaper engine. One instance lives in the shell for the whole
// session; the bar widget (one per monitor) reads its state and calls into it.
//
// All real work happens in the bundled `bin/omarchy-unsplash` CLI, so
// keybindings, menus and the bar share one implementation. This service:
//   - runs `omarchy-unsplash tick` every few minutes (the CLI decides whether
//     a new photo is due, so suspend / reboots / missed days just work)
//   - watches the CLI's state.json and config.json and exposes them as
//     properties for the widget
//   - runs widget actions (new, prev, favorite, keywords, ...) one at a time
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string pluginId: "tkreek.unsplash"
  readonly property string home: Quickshell.env("HOME")
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")
  readonly property string statePath: stateHome + "/omarchy-unsplash/state.json"
  readonly property string configPath: configHome + "/omarchy-unsplash/config.json"

  // Third-party plugins aren't told their folder, so resolve the bundled CLI
  // relative to this file.
  readonly property string sourceDir: String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, "")
  readonly property string cli: sourceDir + "/bin/omarchy-unsplash"

  readonly property string keySignupUrl: "https://unsplash.com/oauth/applications/new"

  // ---- state mirrored from state.json / config.json
  property var state: ({})
  property var config: ({})

  readonly property var current: state && state.current ? state.current : null
  readonly property var history: state && state.history ? state.history : []
  readonly property bool hasKey: !!(config && config.access_key)
  readonly property var keywords: config && config.keywords ? config.keywords : []
  readonly property var collections: config && config.collections ? config.collections : []
  // Anything unrecognised (e.g. a hand-edited value) behaves as daily, matching the CLI.
  readonly property string interval: config && ["hourly", "3h", "12h", "daily", "weekly"].indexOf(config.interval) !== -1
    ? config.interval : "daily"
  readonly property string lastError: state && state.last_error ? state.last_error : ""

  // True while the CLI holds its lock, whoever started it (widget, keybinding, timer).
  readonly property bool busy: runner.running || ticker.running || !!(state && state.busy)

  readonly property int historyIndex: {
    if (!current) return -1
    for (var i = 0; i < history.length; i++) if (history[i].id === current.id) return i
    return -1
  }
  readonly property bool canGoBack: historyIndex >= 0 && historyIndex < history.length - 1
  readonly property bool canGoForward: historyIndex > 0

  // Last message from a widget-initiated command (validation errors etc.).
  property string message: ""
  property bool messageIsError: false

  readonly property string errorText: {
    switch (lastError) {
      case "": return ""
      case "no_key": return "Add your free Unsplash access key to get started."
      case "bad_key": return "Unsplash rejected the access key."
      case "rate_limited": return "Unsplash rate limit reached. Try again in an hour."
      case "no_results": return "No photos found for that keyword."
      case "network": return "Couldn't reach Unsplash. Will retry shortly."
      default: return "Something went wrong (" + lastError + ")."
    }
  }

  function parse(text) {
    try { return JSON.parse(text) } catch (e) { return null }
  }

  // ---- actions (all routed through the CLI)
  property var pending: []

  // `input`, when given, is written to the command's stdin. Secrets go this way
  // and never into args: other local users can read process command lines.
  function run(args, onDone, input) {
    if (runner.running) {
      // One command at a time; drop duplicates of a queued command.
      var id = args.join("\u0001")
      for (var i = 0; i < pending.length; i++) if (pending[i].args.join("\u0001") === id) return
      pending = pending.concat([{ args: args, onDone: onDone, input: input }])
      return
    }
    runner.onDone = onDone || null
    runner.input = input === undefined ? null : String(input)
    runner.stdinEnabled = runner.input !== null
    runner.command = [root.cli].concat(args)
    runner.running = true
  }

  function newPhoto(query) {
    message = ""
    var args = ["new"]
    if (query && String(query).trim() !== "") args.push(String(query).trim())
    run(args)
  }
  function previous() { run(["prev"]) }
  function next() { run(["next"]) }
  function toggleFavorite() { run(["toggle-fav"]) }
  function openPhoto() { run(["open"]) }
  function openFavorites() { Quickshell.execDetached([root.cli, "favorites"]) }
  function openKeySignup() { Quickshell.execDetached(["xdg-open", root.keySignupUrl]) }
  // Only ever opens unsplash.com links (the URLs come from photo metadata).
  function openUrl(url) {
    if (/^https:\/\/unsplash\.com\//.test(String(url || ""))) Quickshell.execDetached(["xdg-open", String(url)])
  }

  function setChangeInterval(value) { run(["interval", value]) }

  // Keywords come from a comma-separated text field; fetch a fresh photo
  // right away so the change is visible.
  function setKeywords(text) {
    var trimmed = String(text || "").trim()
    if (trimmed === "") run(["keywords", "clear"], function(ok) { if (ok) root.newPhoto() })
    else run(["keywords", "set", trimmed], function(ok) { if (ok) root.newPhoto() })
  }

  function setKey(key) {
    var trimmed = String(key || "").replace(/\s+/g, "")
    if (trimmed === "") return
    message = "Checking key…"
    messageIsError = false
    run(["key", "set"], function(ok, err) {
      if (ok) {
        root.message = ""
        Quickshell.execDetached([root.cli, "link"])
        root.newPhoto()
      } else {
        root.message = err || "That key didn't work."
        root.messageIsError = true
      }
    }, trimmed + "\n")
  }

  Process {
    id: runner
    property var onDone: null
    property var input: null
    onStarted: {
      if (input === null) return
      write(input)
      input = null
      stdinEnabled = false  // closes stdin
    }
    stdout: StdioCollector { id: runnerOut }
    stderr: StdioCollector { id: runnerErr }
    onExited: function(code) {
      var err = runnerErr.text.trim().replace(/^omarchy-unsplash: /, "")
      if (code !== 0 && code !== 75) {
        root.message = err || ("Command failed (" + code + ")")
        root.messageIsError = true
      }
      var done = onDone
      onDone = null
      stateFile.reload()
      configFile.reload()
      if (done) done(code === 0, err)
      if (root.pending.length > 0) {
        var nextCmd = root.pending[0]
        root.pending = root.pending.slice(1)
        root.run(nextCmd.args, nextCmd.onDone, nextCmd.input)
      }
    }
  }

  // ---- scheduler: the CLI decides whether a fetch is due.
  Process {
    id: ticker
    command: [root.cli, "tick"]
    onExited: { stateFile.reload(); configFile.reload() }
  }

  function tick() {
    if (!root.sourceDir || ticker.running || runner.running) return
    ticker.running = true
  }

  Timer {
    id: tickTimer
    interval: 5 * 60 * 1000
    repeat: true
    running: true
    onTriggered: root.tick()
  }

  // First check shortly after login, once the network has had a moment.
  Timer {
    interval: 20 * 1000
    running: true
    onTriggered: root.tick()
  }

  // ---- files
  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    // Only re-publish on real changes; the periodic reload below would otherwise churn bindings.
    property string lastText: ""
    onLoaded: {
      var t = text()
      if (t === lastText) return
      var s = root.parse(t)
      if (s) { lastText = t; root.state = s }
    }
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    property string lastText: ""
    onLoaded: {
      var t = text()
      if (t === lastText) return
      var c = root.parse(t)
      if (c) { lastText = t; root.config = c }
    }
  }

  // The CLI replaces these files atomically (rename), which can drop an
  // inotify watch. A cheap periodic reload keeps keybinding-driven changes
  // showing up in the bar.
  Timer {
    interval: 3000
    repeat: true
    running: true
    onTriggered: { stateFile.reload(); configFile.reload() }
  }
}
