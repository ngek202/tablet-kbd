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
  // v0.2 per-piece presence (evolves `available` into a state enum).
  // tabletPresent gates the toggle; oskPresent only informs.
  property bool tabletPresent: true
  property bool oskPresent: true

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
    // Guarded tap (v0.2): no tablet stack, no toggle attempt — open the
    // menu with Install rows instead. Never a silent detached failure.
    if (!root.tabletPresent) {
      root.checkHealth()
      return
    }
    // Optimistic flip for snappy touch feedback; the poll corrects it.
    root.tabletOn = !root.tabletOn
    root.bar.run("$HOME/.config/hypr/scripts/tablet-mode.sh toggle")
    resyncTimer.restart()
  }

  function checkHealth() {
    Quickshell.execDetached(["bash", "-lc", "exec omarchy-launch-floating-terminal-with-presentation $HOME/.config/hypr/scripts/tablet-verify.sh"])
  }

  function tooltipText() {
    if (!root.tabletPresent) return "Tablet package not installed — right-click for health check"
    if (!root.oskPresent) return root.tabletOn ? "Tablet mode on (OSK missing — right-click to install)" : "Tablet mode off (OSK missing — right-click to install)"
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

    function checkHealth(): void {
      root.checkHealth()
    }
  }

  Process {
    id: statusProc
    command: ["sh", "-c", "$HOME/.config/hypr/scripts/tablet-mode.sh status 2>/dev/null; echo \"TABLET:$([ -x $HOME/.config/hypr/scripts/tablet-mode.sh ] && echo yes || echo no)\"; echo \"OSK:$([ -f $HOME/.config/hypr/scripts/custom-kbd.py ] && [ -f $HOME/.config/hypr/kbd-layouts/en.json ] && echo yes || echo no)\""]
    onRunningChanged: {
      if (!running && root.refreshPending) root.refresh()
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = String(text || "").trim().split("\n")
        for (var i = 0; i < lines.length; i++) {
          var s = lines[i].trim()
          if (s === "on") root.tabletOn = true
          else if (s === "off") root.tabletOn = false
          else if (s === "TABLET:yes") { root.tabletPresent = true; root.available = true }
          else if (s === "TABLET:no") { root.tabletPresent = false; root.available = false }
          else if (s === "OSK:yes") root.oskPresent = true
          else if (s === "OSK:no") root.oskPresent = false
        }
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
    // Click routing lives here. A touch long-press opener was tried
    // twice (TapHandler steal, overlay pressAndHold) — both starved.
    // Right-click only; touch users get verify via the post-update
    // notification → terminal path.
    onPressed: function(b) {
      if (b === Qt.RightButton) {
        root.checkHealth()
        return
      }
      root.toggle()
    }
  }
}
