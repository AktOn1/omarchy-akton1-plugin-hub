import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "HubModel.js" as Model

Panel {
  id: root
  moduleName: "io.github.akton1.hub"

  readonly property string snapshotPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/akton1-hub/snapshot.json"
  readonly property string linkGlyph: Model.glyph(0xf0337)
  readonly property string unlinkGlyph: Model.glyph(0xf0338)

  property var snap: ({ state: Model.defaultState(), plugins: Model.pluginStatus([]), detected: { pads: {}, fullscreen: "" },
                        styles: [], message: "", installing: "", catalog: Model.CATALOG })
  property bool serviceUp: false
  property var fullscreenState: ({})
  property string activeView: "all"
  property string capturing: ""
  property string notice: ""

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property bool connected: snap.state.mode === "connected"
  readonly property var viewList: Model.views(snap.plugins)
  readonly property var icons: connected
    ? [{ id: "all", glyph: linkGlyph, title: "AktOn1 plugins" }]
    : viewList.map(v => ({ id: v.id, glyph: v.glyph, title: v.title }))

  readonly property var appEntries: (DesktopEntries.applications.values || []).map(Model.entryInfo)
  readonly property var appChoices: Model.appOptions(appEntries)
  function appTitle(app) { return Model.appTitle(app, appEntries) }

  function viewsFor(view) {
    return view === "all" ? viewList : viewList.filter(v => v.id === view)
  }

  function tooltipFor(icon) {
    return Model.tooltip(snap.state.mode, icon.title, viewList.map(v => v.title))
  }

  // ---- talking to the service ---------------------------------------------------
  property var queue: []
  function run(args) {
    queue.push(args)
    if (!runner.running) nextCommand()
  }
  function nextCommand() {
    if (queue.length === 0) return
    runner.command = ["omarchy-shell", "akton1-hub"].concat(queue.shift())
    runner.running = true
  }
  function setFullscreenOption(key, value) {
    Quickshell.execDetached(["omarchy-shell", "fullscreen-app-auto-workspace", "option", key, value])
    fullscreenTimer.restart()
  }
  function notify(text) { notice = text; noticeTimer.restart() }

  Process {
    id: runner
    stdout: StdioCollector { id: runnerOut }
    onExited: {
      const text = runnerOut.text.trim()
      if (text.indexOf("error:") === 0) root.notify(text.slice(6).trim())
      root.nextCommand()
    }
  }
  Timer { id: noticeTimer; interval: 7000; onTriggered: root.notice = "" }

  Process {
    id: fullscreenReader
    command: ["omarchy-shell", "fullscreen-app-auto-workspace", "state"]
    stdout: StdioCollector { id: fullscreenOut }
    onExited: (code) => {
      if (code !== 0) return
      try { root.fullscreenState = JSON.parse(fullscreenOut.text) } catch (e) {}
    }
  }
  Timer { id: fullscreenTimer; interval: 400; onTriggered: { fullscreenReader.running = false; fullscreenReader.running = true } }

  FileView {
    id: snapshotFile
    path: root.snapshotPath
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try {
        const next = JSON.parse(text())
        if (next && next.state) { root.snap = next; root.serviceUp = true }
      } catch (e) {}
    }
    onLoadFailed: root.serviceUp = false
  }

  // ---- picking a key ----------------------------------------------------------------
  function beginCapture(slot) { capturing = slot }
  function cancelCapture() { capturing = "" }
  function finishCapture(key) {
    const parts = capturing.split("|")
    capturing = ""
    if (parts[0] === "fullscreen") run(["fullscreenKey", key])
    else run(["padSet", parts[0], parts[1], key])
  }

  // ---- opening ------------------------------------------------------------------------
  function toggleView(id) {
    if (opened && activeView === id) { close(); return }
    activeView = id
    open()
  }

  IpcHandler {
    target: "akton1-hub.panel"
    function toggle(view: string): string {
      const known = root.icons.map(i => i.id)
      root.toggleView(known.indexOf(view) >= 0 ? view : known[0])
      return root.opened ? "open" : "closed"
    }
    function close(): string { root.close(); return "closed" }
  }

  onOpenedChanged: if (!opened) capturing = ""
  onConnectedChanged: if (opened) close()

  implicitWidth: grid.implicitWidth
  implicitHeight: grid.implicitHeight

  Component.onCompleted: fullscreenTimer.restart()

  Grid {
    id: grid
    columns: root.vertical ? 1 : Math.max(1, root.icons.length)
    spacing: 0

    Repeater {
      model: root.icons
      delegate: Item {
        id: slot
        required property var modelData
        implicitWidth: button.implicitWidth
        implicitHeight: button.implicitHeight
        width: implicitWidth
        height: implicitHeight

        BarIconButton {
          id: button
          bar: root.bar
          text: slot.modelData.glyph
          tooltipText: root.tooltipFor(slot.modelData)
          active: root.opened && root.activeView === slot.modelData.id
          onPressed: function(buttonCode) {
            if (buttonCode === Qt.RightButton) root.run(["mode", root.connected ? "separated" : "connected"])
            else root.toggleView(slot.modelData.id)
          }
        }

        KeyboardPanel {
          id: panel
          anchorItem: button
          owner: root
          bar: root.bar
          open: root.opened && root.activeView === slot.modelData.id
          focusTarget: keys
          contentWidth: panel.fittedContentWidth(Style.space(420))
          contentHeight: panel.fittedContentHeight(body.implicitHeight, Style.space(680))

          Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.close()

            KeyCapture { hub: root }

            Flickable {
              id: flick
              anchors.fill: parent
              contentWidth: width
              contentHeight: body.implicitHeight
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              flickableDirection: Flickable.VerticalFlick
              interactive: contentHeight > height
              ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

              FlyoutBody {
                id: body
                hub: root
                view: slot.modelData.id
                width: flick.width
              }
            }
          }
        }
      }
    }
  }
}
