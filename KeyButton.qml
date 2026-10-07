import QtQuick
import qs.Commons
import qs.Ui

// Shows a key and, when clicked, waits for the next key combination.
Button {
  id: root

  required property var hub
  property string slot: ""
  property string value: ""
  property string emptyText: "not set"
  readonly property bool waiting: hub.capturing === slot

  text: waiting ? "press the keys... (Esc cancels, Backspace clears)" : (value !== "" ? value : emptyText)
  bordered: true
  focusable: true
  active: waiting
  fontFamily: hub.fontFamily
  foreground: hub.foreground
  onClicked: hub.beginCapture(slot)
}
