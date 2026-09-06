import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Tablet Toggle — bar-widget companion to the tablet-kbd package.
// Shows tablet-mode state, click to enter/exit. Depends on the package
// (tablet-mode.sh on disk), never the reverse. SUPER+B / OSK dispatch
// (osk-toggle.sh) is untouched — B stays.
BarWidget {
  id: root
  moduleName: "io.github.ngek202.tablet-toggle"

  property bool tabletOn: false
  property bool available: true
  property bool refreshPending: false

  function statusScript() {
    return "$HOME/.config/hypr/scripts/tablet-mode.sh status"
  }

  function refresh() {
    if (statusProc.running) {
      refreshPending = true
      return
    }
    refreshPending = false
    statusProc.running = true
  }

  function toggle() {
    if (!root.bar) return
    // Optimistic flip for snappy touch feedback; the poll corrects it.
    root.tabletOn = !root.tabletOn
    root.bar.run("$HOME/.config/hypr/scripts/tablet-mode.sh toggle")
    resyncTimer.restart()
  }

  function tooltipText() {
    if (!root.available) return "Tablet Toggle (tablet-mode.sh not found — install package)"
    return root.tabletOn ? "Tablet mode on — click to exit" : "Tablet mode off — click to enter"
  }

  Component.onCompleted: root.refresh()

  IpcHandler {
    target: "io.github.ngek202.tablet-toggle.widget"

    function refresh(): void {
      root.refresh()
    }

    function toggle(): void {
      root.toggle()
    }
  }

  Process {
    id: statusProc
    command: ["sh", "-c", "$HOME/.config/hypr/scripts/tablet-mode.sh status"]
    onRunningChanged: {
      if (!running && root.refreshPending) root.refresh()
    }
    onExited: function(exitCode) {
      root.available = exitCode === 0
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var s = String(text || "").trim()
        if (s === "on") root.tabletOn = true
        else if (s === "off") root.tabletOn = false
      }
    }
  }

  // Steady-state poll: cheap fork every 2s, only flips bools on change.
  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // Re-read shortly after a toggle (state file lands fast).
  Timer {
    id: resyncTimer
    interval: 600
    onTriggered: root.refresh()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    active: root.tabletOn && root.available
    opacity: root.available ? 1.0 : 0.4
    tooltipText: root.tooltipText()
    onPressed: function(b) {
      root.toggle()
    }
  }
}
