import QtQuick
import qs.Commons
import qs.Ui
import "HubModel.js" as Model

Column {
  id: root

  required property var hub
  required property var pad
  readonly property bool isLayer: pad.layer === true
  readonly property string userKey: isLayer ? "" : (hub.snap.detected.pads[pad.id] || "")
  readonly property int running: hub.snap.running ? (hub.snap.running[pad.id] || 0) : 0
  readonly property var layoutOptions: Model.layoutOptions([pad.layout])
  readonly property bool frameOn: hub.snap.plugins["io.github.akton1.scratchpad-frame"].enabled
  readonly property bool fullscreenOn: hub.snap.plugins["io.github.akton1.fullscreen-app-auto-workspace"].enabled
  readonly property var styleOptions: [{ value: "default", label: "Shared style" }].concat(hub.snap.styles.map(s => ({ value: s, label: s })))

  spacing: Style.space(8)

  component Caption: Text {
    textFormat: Text.PlainText
    color: root.hub.dim
    font.family: root.hub.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
  }

  Row {
    spacing: Style.space(8)
    width: parent.width

    Text {
      visible: root.isLayer
      width: parent.width - showButton.width - parent.spacing
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: root.pad.label
      color: root.hub.foreground
      font.family: root.hub.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }
    TextField {
      id: nameField
      visible: !root.isLayer
      width: parent.width - showButton.width - (removeButton.visible ? removeButton.width : 0) - parent.spacing * (removeButton.visible ? 2 : 1)
      text: root.pad.label
      foreground: root.hub.foreground
      font.family: root.hub.fontFamily
      onEditingFinished: if (text !== root.pad.label && text.trim() !== "") root.hub.run(["padSet", root.pad.id, "label", text.trim()])
    }
    Button {
      id: showButton
      text: "Show"
      bordered: true
      focusable: true
      fontFamily: root.hub.fontFamily
      foreground: root.hub.foreground
      tooltipText: root.isLayer ? "Show or hide the Fullscreen layer (opens only when something is on it)" : "Slide this scratchpad in or out"
      onClicked: root.hub.run(["toggle", root.pad.id])
    }
    Button {
      id: removeButton
      visible: !root.pad.builtin
      text: "Remove"
      bordered: true
      focusable: true
      fontFamily: root.hub.fontFamily
      foreground: root.hub.foreground
      onClicked: root.hub.run(["padRemove", root.pad.id])
    }
  }

  Caption { visible: !root.isLayer; text: "KEY" }
  KeyButton {
    visible: !root.isLayer
    hub: root.hub
    slot: root.pad.id + "|key"
    value: root.pad.key || ""
    emptyText: root.pad.builtin ? "SUPER + S (Omarchy default)" : "not set"
  }

  Column {
    visible: root.userKey !== ""
    width: parent.width
    spacing: Style.space(4)
    Text {
      textFormat: Text.PlainText
      width: parent.width
      text: "Your bindings.lua already binds " + root.userKey + " for this scratchpad. The Hub leaves it alone."
      color: root.hub.dim
      font.family: root.hub.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
    }
    Row {
      spacing: Style.space(8)
      ToggleSwitch {
        checked: root.pad.keepMine === true
        foreground: root.hub.foreground
        onToggled: root.hub.run(["padSet", root.pad.id, "keepMine", checked ? "false" : "true"])
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - Style.space(60)
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        text: "Keep my binding (the slide direction needs the Hub's own key)"
        color: root.hub.foreground
        font.family: root.hub.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }
  }

  Column {
    visible: !root.pad.builtin && !root.isLayer
    width: parent.width
    spacing: Style.space(8)
    Caption { text: "MOVE WINDOW HERE" }
    KeyButton {
      hub: root.hub
      slot: root.pad.id + "|moveKey"
      value: root.pad.moveKey || ""
    }
  }

  Row {
    visible: !root.isLayer
    spacing: Style.space(12)
    Dropdown {
      width: Style.space(150)
      label: "Slides in from"
      fontFamily: root.hub.fontFamily
      options: [{ value: "bottom", label: "Bottom" }, { value: "top", label: "Top" }, { value: "left", label: "Left" }, { value: "right", label: "Right" }]
      value: root.pad.direction || "bottom"
      onChanged: function(v) { root.hub.run(["padSet", root.pad.id, "direction", v]) }
    }
    Dropdown {
      visible: root.frameOn
      width: Style.space(190)
      label: "Frame"
      fontFamily: root.hub.fontFamily
      options: root.styleOptions
      value: root.pad.style ? root.pad.style : "default"
      onChanged: function(v) { root.hub.run(["padSet", root.pad.id, "style", v]) }
    }
  }

  Dropdown {
    width: Style.space(190)
    label: "Layout"
    fontFamily: root.hub.fontFamily
    options: root.layoutOptions
    value: root.pad.layout
    onChanged: function(v) { root.hub.run(["padSet", root.pad.id, "layout", v === "" ? "default" : v]) }
  }

  Row {
    visible: root.fullscreenOn && !root.isLayer
    spacing: Style.space(8)
    ToggleSwitch {
      checked: root.hub.snap.state.magnet === root.pad.id
      foreground: root.hub.foreground
      onToggled: root.hub.run(["magnet", checked ? "none" : root.pad.id])
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: root.width - Style.space(60)
      wrapMode: Text.WordWrap
      textFormat: Text.PlainText
      text: "Fullscreen games land here (only one scratchpad can)"
      color: root.hub.foreground
      font.family: root.hub.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  Row {
    spacing: Style.space(8)
    width: parent.width
    Caption {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - restartButton.width - parent.spacing
      text: "APPS STARTED AT LOGIN" + (root.running > 0 ? "  (" + root.running + " open)" : "")
    }
    Button {
      id: restartButton
      visible: root.pad.apps.length > 0
      text: root.running > 0 ? "Restart apps" : "Start apps"
      bordered: true
      focusable: true
      fontFamily: root.hub.fontFamily
      foreground: root.hub.foreground
      tooltipText: root.running > 0 ? "Close the apps the Hub started here and start them again" : "Start these apps now"
      onClicked: root.hub.run(["appsRestart", root.pad.id])
    }
  }
  Repeater {
    model: root.pad.apps
    delegate: Row {
      required property string modelData
      required property int index
      spacing: Style.space(8)
      width: root.width
      Text {
        width: parent.width - dropApp.width - parent.spacing
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: modelData
        elide: Text.ElideRight
        color: root.hub.foreground
        font.family: root.hub.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
      Button {
        id: dropApp
        text: "Remove"
        focusable: true
        fontFamily: root.hub.fontFamily
        foreground: root.hub.foreground
        onClicked: root.hub.run(["appRemove", root.pad.id, String(index)])
      }
    }
  }
  TextField {
    width: parent.width
    placeholderText: "command, then Enter (e.g. kitty)"
    foreground: root.hub.foreground
    font.family: root.hub.fontFamily
    onAccepted: if (text.trim() !== "") { root.hub.run(["appAdd", root.pad.id, text.trim()]); text = "" }
  }
}
