import QtQuick
import qs.Commons
import qs.Ui
import "HubModel.js" as Model

Column {
  id: root

  required property var hub
  readonly property var fsState: hub.fullscreenState
  readonly property var padOptions: [{ value: "none", label: hub.snap.state.fullscreen.label + " (default)" }].concat(hub.snap.state.pads.map(p => ({ value: p.id, label: p.label })))
  spacing: Style.space(10)

  PanelSectionHeader { text: "FULLSCREEN"; foreground: root.hub.foreground; fontFamily: root.hub.fontFamily }

  Text {
    textFormat: Text.PlainText
    width: parent.width
    text: "Fullscreen games move to this layer by themselves."
    color: root.hub.dim
    font.family: root.hub.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }

  PadCard {
    hub: root.hub
    pad: root.hub.snap.state.fullscreen
    width: parent.width
  }

  Dropdown {
    width: Style.space(260)
    label: "Where fullscreen games go"
    fontFamily: root.hub.fontFamily
    options: root.padOptions
    value: root.hub.snap.state.magnet !== "" ? root.hub.snap.state.magnet : "none"
    onChanged: function(v) { root.hub.run(["magnet", v]) }
  }

  Row {
    spacing: Style.space(8)
    ToggleSwitch {
      checked: root.fsState.muteOnHide === true
      foreground: root.hub.foreground
      onToggled: root.hub.setFullscreenOption("muteOnHide", checked ? "unset" : "true")
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: "Mute the game while the layer is hidden"
      color: root.hub.foreground
      font.family: root.hub.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }
}
