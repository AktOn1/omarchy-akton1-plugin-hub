import QtQuick
import qs.Commons
import qs.Ui
import "HubModel.js" as Model

Column {
  id: root

  required property var hub
  spacing: Style.space(10)

  PanelSectionHeader { text: "FULLSCREEN"; foreground: root.hub.foreground; fontFamily: root.hub.fontFamily }

  Text {
    textFormat: Text.PlainText
    width: parent.width
    text: "Switch on \"Fullscreen games land here\" for one layer or scratchpad. With none on, games are not moved by themselves."
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
}
