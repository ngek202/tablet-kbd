import QtQuick
import qs.Commons
import qs.Ui

// HealthMenu — right-click / long-press menu for the tablet toggle.
// Two deliberate actions; both open a floating terminal so output is
// visible (bar.run is detached). Repair is explicit user intent —
// the post-update hook still never auto-repairs.
PopupCard {
  id: menu

  property var host: null
  // v0.2 install hub: rows render only for missing pieces.
  // Both missing → one combined row; OSK-only missing → OSK row.
  property bool showInstallTablet: false
  property bool showInstallOsk: false

  // One installer behind every row (Phase B one-liner, fresh clone to
  // /tmp so a partial/broken tree can't block repair). Visible terminal,
  // explicit tap — the plugin owns nothing.
  function installCmd() {
    return "rm -rf /tmp/tablet-kbd-install && git clone https://github.com/ngek202/tablet-kbd.git /tmp/tablet-kbd-install && /tmp/tablet-kbd-install/install.sh"
  }

  function runInstall() {
    menu.open = false
    if (host && host.bar) host.bar.run("omarchy-launch-floating-terminal-with-presentation " + installCmd())
  }

  contentWidth: menu.fittedContentWidth(Style.space(280))
  contentHeight: menu.fittedContentHeight(menuColumn.implicitHeight)

  function runCheck() {
    menu.open = false
    if (host && host.bar) host.bar.run("$HOME/.config/hypr/scripts/tablet-verify.sh")
  }

  function runRepair() {
    menu.open = false
    if (host && host.bar) host.bar.run("$HOME/.config/hypr/scripts/tablet-verify.sh --fix")
  }

  Column {
    id: menuColumn
    anchors.fill: parent
    spacing: Style.space(4)

    WidgetButton {
      visible: menu.showInstallTablet
      width: parent.width
      labelVisible: true
      text: "Install tablet package"
      tooltipText: "Clone tablet-kbd and run its installer (visible terminal)"
      onPressed: function(b) {
        if (b === Qt.LeftButton) menu.runInstall()
      }
    }

    WidgetButton {
      visible: menu.showInstallOsk && !menu.showInstallTablet
      width: parent.width
      labelVisible: true
      text: "Install OSK"
      tooltipText: "Repair the keyboard engine via the package installer"
      onPressed: function(b) {
        if (b === Qt.LeftButton) menu.runInstall()
      }
    }

    WidgetButton {
      visible: !menu.showInstallTablet
      width: parent.width
      labelVisible: true
      text: "Check tablet health"
      tooltipText: "Run tablet-verify.sh (read-only)"
      onPressed: function(b) {
        if (b === Qt.LeftButton) menu.runCheck()
      }
    }

    WidgetButton {
      visible: !menu.showInstallTablet
      width: parent.width
      labelVisible: true
      text: "Repair tablet stack"
      tooltipText: "Run tablet-verify.sh --fix (mechanical repairs only)"
      onPressed: function(b) {
        if (b === Qt.LeftButton) menu.runRepair()
      }
    }
  }
}
