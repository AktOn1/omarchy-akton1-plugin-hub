import QtQuick
import qs.Commons
import qs.Ui
import "HubModel.js" as Model

Column {
  id: fly

  required property var hub
  property string view: "all"
  readonly property var shown: hub.viewsFor(view)
  readonly property bool connected: view === "all"
  readonly property bool settings: hub.settingsOpen
  function has(id) { return shown.some(v => v.id === id) }

  spacing: Style.space(14)

  PanelHero {
    id: hero
    width: parent.width
    title: fly.settings ? "AktOn1 settings" : (fly.view === "all" ? "AktOn1 Plugins" : (fly.shown.length ? fly.shown[0].title : "AktOn1"))
    meta: fly.settings ? "Bar icons, plugins and where to get them" : (fly.connected ? "AktOn1 plugins: connected" : "AktOn1 plugin: disconnected")
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
      Button {
        id: gear
        iconText: fly.settings ? "" : fly.hub.gearGlyph
        text: fly.settings ? "Back" : ""
        bordered: true
        focusable: true
        selected: fly.settings
        fontFamily: fly.hub.fontFamily
        foreground: fly.hub.foreground
        tooltipText: fly.settings ? "Back to the plugin settings" : "Settings: bar icons, plugins, install"
        onClicked: fly.hub.settingsOpen = !fly.hub.settingsOpen
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

  SettingsPage {
    visible: fly.settings
    hub: fly.hub
    width: parent.width
  }

  ScratchpadsSection {
    visible: !fly.settings && fly.has("scratchpads")
    hub: fly.hub
    width: parent.width
  }

  FullscreenSection {
    visible: !fly.settings && fly.has("fullscreen")
    hub: fly.hub
    width: parent.width
  }
}
