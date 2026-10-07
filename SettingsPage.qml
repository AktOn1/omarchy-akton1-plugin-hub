import QtQuick
import qs.Commons
import qs.Ui
import "HubModel.js" as Model

Column {
  id: root

  required property var hub
  readonly property var state: hub.snap.state
  readonly property string mode: state.mode
  readonly property var rows: Model.pluginRows(hub.snap.plugins)

  spacing: Style.space(12)

  component Note: Text {
    textFormat: Text.PlainText
    width: root.width
    color: root.hub.dim
    font.family: root.hub.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }

  component Check: Row {
    id: check
    property bool checked: false
    property bool interactive: true
    property string label: ""
    signal toggled()
    spacing: Style.space(8)
    opacity: interactive ? 1 : 0.45
    ToggleSwitch {
      checked: check.checked
      interactive: check.interactive
      cursorRing: true
      foreground: root.hub.foreground
      onToggled: check.toggled()
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: root.width - Style.space(60)
      textFormat: Text.PlainText
      text: check.label
      wrapMode: Text.WordWrap
      color: root.hub.foreground
      font.family: root.hub.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  PanelSectionHeader { text: "BAR ICONS"; foreground: root.hub.foreground; fontFamily: root.hub.fontFamily }

  Row {
    spacing: Style.space(8)
    Button {
      text: "All in one icon"
      bordered: true
      focusable: true
      selected: root.mode === "connected"
      fontFamily: root.hub.fontFamily
      foreground: root.hub.foreground
      tooltipText: "Connected: one icon, every plugin has its pane in one flyout"
      onClicked: root.hub.run(["mode", "connected"])
    }
    Button {
      text: "One icon each"
      bordered: true
      focusable: true
      selected: root.mode === "separated"
      fontFamily: root.hub.fontFamily
      foreground: root.hub.foreground
      tooltipText: "Separated: every plugin gets its own icon and flyout"
      onClicked: root.hub.run(["mode", "separated"])
    }
  }

  Note {
    text: root.mode === "mixed" ? "Mixed: you chose per plugin below."
        : (root.mode === "connected" ? "All plugins are inside the Hub icon. Switch a plugin below to give it its own icon."
                                     : "Each plugin has its own icon. Hide the ones you do not want in the bar.")
  }

  PanelSeparator { foreground: root.hub.foreground }

  PanelSectionHeader { text: "AKTON1 PLUGINS"; foreground: root.hub.foreground; fontFamily: root.hub.fontFamily }

  Repeater {
    model: root.rows
    delegate: Column {
      id: row
      required property var modelData
      readonly property bool active: modelData.state === "builtin" || modelData.state === "on"
      readonly property bool hasIcon: active && modelData.viewId !== ""
      readonly property bool joined: root.state.separate.indexOf(modelData.viewId) < 0
      readonly property bool shownInBar: joined || root.state.hidden.indexOf(modelData.viewId) < 0
      readonly property bool lastIcon: root.hub.icons.length === 1 && root.hub.icons[0].id === modelData.viewId
      readonly property string link: modelData.entry ? Model.storeLink(modelData.entry) : ""
      readonly property string command: modelData.entry ? Model.commandFor(modelData) : ""
      readonly property string statusText: modelData.state === "builtin" ? "Part of the Hub"
        : (modelData.state === "on" ? "Installed" : (modelData.state === "off" ? "Installed, turned off" : "Not installed"))

      width: root.width
      spacing: Style.space(6)

      Row {
        width: parent.width
        spacing: Style.space(8)

        Text {
          id: nameText
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: row.modelData.name
          color: root.hub.foreground
          font.family: root.hub.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }

        BorderSurface {
          id: infoDot
          anchors.verticalCenter: parent.verticalCenter
          implicitWidth: Style.space(18)
          implicitHeight: Style.space(18)
          radius: width / 2
          color: "transparent"
          borderSpec: Border.controlSpec(infoMouse.containsMouse ? "hover-cursor" : "normal", root.hub.foreground, Color.accent)
          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "i"
            color: root.hub.foreground
            font.family: root.hub.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
          MouseArea {
            id: infoMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
          }
          PanelToolTip {
            visible: infoMouse.containsMouse
            text: row.modelData.info
            fontFamily: root.hub.fontFamily
          }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: row.statusText
          color: root.hub.dim
          font.family: root.hub.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }

      Check {
        visible: row.hasIcon
        checked: row.joined
        label: "Connected: inside the Hub icon"
        onToggled: root.hub.run(["separate", row.modelData.viewId, row.joined ? "on" : "off"])
      }

      Check {
        visible: row.hasIcon
        checked: row.shownInBar
        interactive: !row.joined && !(row.shownInBar && row.lastIcon)
        label: row.joined ? "In the bar: through the Hub icon" : "Show its own icon in the bar"
        onToggled: root.hub.run(["barShow", row.modelData.viewId, row.shownInBar ? "off" : "on"])
      }

      Note {
        visible: row.modelData.state === "on" && row.modelData.viewId === ""
        text: "No icon of its own: its frame styles appear on the scratchpad cards."
      }

      Column {
        visible: !row.active
        width: parent.width
        spacing: Style.space(6)

        Row {
          spacing: Style.space(8)
          Button {
            readonly property bool present: row.modelData.state === "off"
            text: root.hub.snap.installing === row.modelData.name ? "Working..." : (present ? "Enable" : "Install")
            bordered: true
            focusable: true
            fontFamily: root.hub.fontFamily
            foreground: root.hub.foreground
            tooltipText: row.command
            onClicked: if (root.hub.snap.installing === "") root.hub.run(["install", row.modelData.entry.id])
          }
          Button {
            visible: row.link !== ""
            text: "Omarchy store"
            bordered: true
            focusable: true
            fontFamily: root.hub.fontFamily
            foreground: root.hub.foreground
            tooltipText: row.link
            onClicked: root.hub.openLink(row.link)
          }
          Button {
            text: "GitHub"
            bordered: true
            focusable: true
            fontFamily: root.hub.fontFamily
            foreground: root.hub.foreground
            tooltipText: row.modelData.entry.page
            onClicked: root.hub.openLink(row.modelData.entry.page)
          }
        }

        Note { visible: row.link === "" && row.modelData.state === "missing"; text: "Not on the Omarchy store yet. Install it from GitHub with the command below." }

        Row {
          width: parent.width
          spacing: Style.space(8)
          Text {
            id: commandText
            width: parent.width - copyButton.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: row.command
            wrapMode: Text.WrapAnywhere
            color: root.hub.foreground
            font.family: root.hub.fontFamily
            font.pixelSize: Style.font.caption
          }
          Button {
            id: copyButton
            text: "Copy"
            bordered: true
            focusable: true
            fontFamily: root.hub.fontFamily
            foreground: root.hub.foreground
            tooltipText: "Copy the command, then paste it in a terminal"
            onClicked: root.hub.copyText(row.command)
          }
        }
      }

      PanelSeparator { foreground: root.hub.foreground }
    }
  }
}
