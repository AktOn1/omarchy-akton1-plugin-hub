import QtQuick
import qs.Commons
import qs.Ui

Column {
  id: root

  required property var hub
  spacing: Style.space(14)

  PanelSectionHeader { text: "SCRATCHPADS"; foreground: root.hub.foreground; fontFamily: root.hub.fontFamily }

  Repeater {
    model: root.hub.snap.state.pads
    delegate: Column {
      required property var modelData
      width: root.width
      spacing: Style.space(14)
      PadCard { hub: root.hub; pad: modelData; width: parent.width }
      PanelSeparator { width: parent.width; foreground: root.hub.foreground }
    }
  }

  TextField {
    width: parent.width
    placeholderText: "New scratchpad name, then Enter"
    foreground: root.hub.foreground
    font.family: root.hub.fontFamily
    onAccepted: { root.hub.run(["padAdd", text.trim(), "bottom"]); text = "" }
  }
}
