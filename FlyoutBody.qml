import QtQuick
import qs.Commons
import qs.Ui
import "HubModel.js" as Model

Column {
  id: fly

  required property var hub
  property string view: "all"
  readonly property var shown: hub.viewsFor(view)
  readonly property bool connected: hub.snap.state.mode === "connected"

  spacing: Style.space(14)

  PanelHero {
    id: hero
    width: parent.width
    title: fly.view === "all" ? "AktOn1 Plugins" : (fly.shown.length ? fly.shown[0].title : "AktOn1")
    meta: fly.connected ? "AktOn1 plugins: connected" : "AktOn1 plugin: disconnected"
    foreground: fly.hub.foreground
    fontFamily: fly.hub.fontFamily
    iconComponent: Component {
      Text {
        textFormat: Text.PlainText
        text: fly.connected ? fly.hub.linkGlyph : fly.hub.unlinkGlyph
        color: fly.hub.foreground
        font.family: fly.hub.fontFamily
        font.pixelSize: Style.font.display
      }
    }
    trailingControl: Component {
      ToggleSwitch {
        id: modeSwitch
        checked: !fly.connected
        foreground: fly.hub.foreground
        onToggled: fly.hub.run(["mode", fly.connected ? "separated" : "connected"])
        PanelToolTip {
          visible: modeSwitch.containsMouse
          text: fly.connected ? "Disconnect: one icon per plugin" : "Connect: one icon for all"
          fontFamily: fly.hub.fontFamily
        }
      }
    }
  }

  Text {
    textFormat: Text.PlainText
    visible: fly.hub.notice !== "" || fly.hub.snap.message !== ""
    width: parent.width
    text: fly.hub.notice !== "" ? fly.hub.notice : fly.hub.snap.message
    color: fly.hub.notice !== "" ? fly.hub.urgent : fly.hub.dim
    font.family: fly.hub.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }

  Text {
    textFormat: Text.PlainText
    visible: !fly.hub.serviceUp
    width: parent.width
    text: "The Hub service has not started yet. Check that the plugin is enabled."
    color: fly.hub.dim
    font.family: fly.hub.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }

  ScratchpadsSection {
    visible: fly.view === "all" || fly.view === "scratchpads"
    hub: fly.hub
    width: parent.width
  }

  FullscreenSection {
    visible: (fly.view === "all" || fly.view === "fullscreen") && fly.hub.snap.plugins["io.github.akton1.fullscreen-app-auto-workspace"].enabled
    hub: fly.hub
    width: parent.width
  }

  InstallSection {
    visible: missing.length > 0 && fly.view !== "fullscreen"
    hub: fly.hub
    width: parent.width
  }
}
