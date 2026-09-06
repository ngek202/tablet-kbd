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
      width: parent.width
      labelVisible: true
      text: "Check tablet health"
      tooltipText: "Run tablet-verify.sh (read-only)"
      onPressed: function(b) {
        if (b === Qt.LeftButton) menu.runCheck()
      }
    }

    WidgetButton {
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
