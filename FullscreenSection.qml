import QtQuick
import qs.Commons
import qs.Ui

Column {
  id: root

  required property var hub
  readonly property var fsState: hub.fullscreenState
  readonly property string userKey: hub.snap.detected.fullscreen || ""
  readonly property var padOptions: [{ value: "none", label: "Its own layer (default)" }].concat(hub.snap.state.pads.map(p => ({ value: p.id, label: p.label })))
  spacing: Style.space(10)

  PanelSectionHeader { text: "FULLSCREEN LAYER"; foreground: root.hub.foreground; fontFamily: root.hub.fontFamily }

  Text {
    textFormat: Text.PlainText
    width: parent.width
    text: "Fullscreen games move to their own layer by themselves. This key hides and shows it."
    color: root.hub.dim
    font.family: root.hub.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }

  KeyButton {
    hub: root.hub
    slot: "fullscreen|key"
    value: root.hub.snap.state.fullscreenKey
    emptyText: root.userKey !== "" ? root.userKey + " (your own binding)" : "not set"
  }

  Text {
    visible: root.userKey !== ""
    textFormat: Text.PlainText
    width: parent.width
    text: "Your bindings.lua already binds " + root.userKey + " for this. The Hub leaves it alone."
    color: root.hub.dim
    font.family: root.hub.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
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
