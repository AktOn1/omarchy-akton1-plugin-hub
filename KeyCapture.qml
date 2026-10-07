import QtQuick
import "HubModel.js" as Model

// Takes the keyboard while a key is being picked: Esc cancels, Backspace clears.
Item {
  id: root

  required property var hub
  readonly property bool active: hub.capturing !== ""

  onActiveChanged: {
    if (active) forceActiveFocus()
    else if (parent) parent.forceActiveFocus()
  }

  Keys.onPressed: function(event) {
    if (!active) return
    event.accepted = true
    if (event.key === Qt.Key_Escape) { hub.cancelCapture(); return }
    if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) { hub.finishCapture("none"); return }
    const m = event.modifiers
    const key = Model.keyFromEvent(event.key, (m & Qt.ControlModifier) !== 0, (m & Qt.AltModifier) !== 0,
                                   (m & Qt.ShiftModifier) !== 0, (m & Qt.MetaModifier) !== 0)
    if (key !== "") hub.finishCapture(key)
  }
}
