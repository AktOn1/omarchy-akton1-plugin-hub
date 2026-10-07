import QtQuick
import qs.Commons
import qs.Ui
import "HubModel.js" as Model

Column {
  id: root

  required property var hub
  property string title: "More AktOn1 plugins"
  readonly property var missing: Model.missing(hub.snap.plugins)

  visible: missing.length > 0
  spacing: Style.space(8)

  PanelSectionHeader { text: root.title.toUpperCase(); foreground: root.hub.foreground; fontFamily: root.hub.fontFamily }

  Repeater {
    model: root.missing
    delegate: Item {
      required property var modelData
      width: root.width
      height: info.implicitHeight

      Column {
        id: info
        anchors.left: parent.left
        anchors.right: installButton.left
        anchors.rightMargin: Style.space(8)
        spacing: 2
        Text {
          textFormat: Text.PlainText
          text: modelData.name
          color: root.hub.foreground
          font.family: root.hub.fontFamily
          font.pixelSize: Style.font.body
        }
        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: (installButton.present ? "Installed but turned off. " : "") + modelData.blurb
          color: root.hub.dim
          font.family: root.hub.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }
      }

      Button {
        id: installButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        readonly property bool present: !!(root.hub.snap.plugins[modelData.id] && root.hub.snap.plugins[modelData.id].installed)
        text: root.hub.snap.installing === modelData.name ? "Working..." : (present ? "Enable" : "Install")
        bordered: true
        focusable: true
        fontFamily: root.hub.fontFamily
        foreground: root.hub.foreground
        tooltipText: present ? "omarchy plugin enable " + modelData.id : Model.installCommand(modelData)
        onClicked: if (root.hub.snap.installing === "") root.hub.run(["install", modelData.id])
      }
    }
  }
}
