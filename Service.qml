// AktOn1 Plugin Hub: service. Keeps the Hub settings, registers scratchpad keys inside
// Hyprland (hub.lua, runtime only, bindings.lua is never written), pushes pads to
// Scratchpad Frame and the magnet to Fullscreen App Auto Workspace when they are installed,
// and publishes a snapshot the bar widget reads.
//
// IPC: omarchy-shell akton1-hub state | mode <connected|separated> | separate <scratchpads|fullscreen> <on|off> | barShow <scratchpads|fullscreen> <on|off> | padAdd <label> [direction]
//      padRemove <id> | padSet <id> <label|key|moveKey|direction|style|keepMine|layout> <value>
//      appAdd <id> <command> | appRemove <id> <index> | magnet <id|none|off> | fullscreenKey <keys|none>
//      toggle <id> | install <plugin id> | refresh
//      padSet also takes layout (dwindle, master, scrolling, monocle, lua:<name>, default); id "fullscreen" is the Fullscreen layer
//      appsStart <id> | appsRestart <id>   (id "fullscreen" is the Fullscreen layer)
//      appSearch <words>   lists installed apps; appAdd takes "app:<id>" from that list or a plain command
//      padSet also takes label for the Fullscreen layer (its name)

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "HubModel.js" as Model

Scope {
  id: root

  property var omarchyPath
  property var shell
  property var manifest

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateDir: home + "/.local/state/akton1-hub"
  readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/akton1-hub"
  readonly property string hubLua: Qt.resolvedUrl("hub.lua").toString().replace(/^file:\/\//, "")

  property bool ready: false
  property var state: Model.defaultState()
  property var plugins: Model.pluginStatus([])
  property var detected: ({ pads: {}, fullscreen: "" })
  property var binds: []
  property var anim: ({})
  property var styles: []
  property string message: ""
  property string installing: ""
  property bool startupDone: false
  property bool framePushed: false
  property bool magnetPushed: false
  property bool autoMoveOffPushed: false
  property var keepPushed: null
  property var clients: []
  property var owned: ({})
  property var tracking: ({})
  property var restarting: ({})
  property bool ownedLoaded: false
  property bool ownedMissing: false
  property bool adoptPending: false

  function say(text) {
    message = text
    messageTimer.restart()
    publish()
  }

  Timer { id: messageTimer; interval: 9000; onTriggered: { root.message = ""; root.publish() } }

  // ---- files ------------------------------------------------------------------

  Process {
    id: init
    command: ["mkdir", "-p", root.stateDir, root.runtimeDir]
    onExited: root.ready = true
  }

  FileView {
    id: stateFile
    path: root.ready ? root.stateDir + "/state.json" : ""
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      let raw = null
      try { raw = JSON.parse(text()) } catch (e) { raw = null }
      const next = Model.cleanState(raw)
      if (JSON.stringify(next) !== JSON.stringify(root.state) || !root.startupDone) {
        root.state = next
        root.scheduleApply()
      }
    }
    onLoadFailed: { root.state = Model.defaultState(); root.scheduleApply() }
  }

  FileView {
    id: bindingsFile
    path: root.home + "/.config/hypr/bindings.lua"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { root.detected = Model.detectBindings(text()); root.scheduleApply() }
    onLoadFailed: root.detected = ({ pads: {}, fullscreen: "" })
  }

  FileView {
    id: ownedFile
    path: root.ready ? root.runtimeDir + "/owned.json" : ""
    atomicWrites: true
    onLoaded: {
      let raw = {}
      try { raw = JSON.parse(text()) } catch (e) { raw = {} }
      const clean = {}
      for (const id in raw) if (Array.isArray(raw[id])) clean[id] = raw[id].filter(a => /^0x[0-9a-f]+$/.test(a))
      root.owned = clean
      root.ownedLoaded = true
      root.refreshClients()
    }
    onLoadFailed: { root.ownedMissing = true; root.ownedLoaded = true }
  }

  FileView {
    id: snapshotFile
    path: root.ready ? root.runtimeDir + "/snapshot.json" : ""
    atomicWrites: true
  }

  function saveState() {
    stateFile.setText(JSON.stringify(state, null, 2) + "\n")
  }

  function publish() { publishTimer.restart() }
  Timer {
    id: publishTimer
    interval: 60
    onTriggered: if (root.ready) snapshotFile.setText(JSON.stringify(root.snapshot()) + "\n")
  }

  function snapshot() {
    const running = {}
    for (const id in owned) running[id] = owned[id].length
    return { state: state, plugins: plugins, detected: detected, styles: styles, message: message,
             installing: installing, catalog: Model.CATALOG, running: running }
  }

  // ---- reading the desktop ------------------------------------------------------

  property int pluginTries: 0
  Process {
    id: pluginsProc
    command: ["omarchy-shell", "shell", "listPlugins"]
    stdout: StdioCollector { id: pluginsOut }
    onExited: (code) => {
      if (code !== 0) {
        if (root.pluginTries++ < 10) pluginRetry.restart()
        return
      }
      root.pluginTries = 0
      const next = Model.pluginStatus(pluginsOut.text)
      if (JSON.stringify(next) !== JSON.stringify(root.plugins)) {
        root.plugins = next
        root.scheduleApply()
      }
      root.publish()
    }
  }
  Timer { id: pluginRetry; interval: 2000; onTriggered: root.refreshPlugins() }
  Timer { interval: 30000; repeat: true; running: root.ready; onTriggered: root.refreshPlugins() }
  function refreshPlugins() { pluginsProc.running = false; pluginsProc.running = true }

  Process {
    id: bindsProc
    command: ["hyprctl", "-j", "binds"]
    stdout: StdioCollector { id: bindsOut }
    onExited: (code) => {
      if (code !== 0) return
      try { root.binds = JSON.parse(bindsOut.text) } catch (e) {}
    }
  }
  function refreshBinds() { bindsProc.running = false; bindsProc.running = true }

  Process {
    id: stylesProc
    command: ["omarchy-shell", "scratchpad-frame", "list"]
    stdout: StdioCollector { id: stylesOut }
    onExited: (code) => {
      if (code !== 0) return
      const list = stylesOut.text.trim().split(/\s+/).filter(s => s !== "")
      if (JSON.stringify(list) !== JSON.stringify(root.styles)) { root.styles = list; root.publish() }
    }
  }

  // ---- which windows belong to a layer's apps -------------------------------------
  // Apps the Hub starts are remembered by window address (for this Hyprland session), so Restart
  // closes only those and never a window you put on the scratchpad yourself or a game.

  Process {
    id: clientsProc
    command: ["hyprctl", "-j", "clients"]
    stdout: StdioCollector { id: clientsOut }
    onExited: (code) => {
      if (code !== 0) return
      let list = []
      try { list = JSON.parse(clientsOut.text) } catch (e) { return }
      root.clients = list.filter(c => c && c.workspace && typeof c.address === "string")
      root.onClients()
    }
  }
  function refreshClients() { clientsProc.running = false; clientsProc.running = true }
  Timer { id: clientsDebounce; interval: 350; onTriggered: root.refreshClients() }
  Timer { id: restartWatch; interval: 1000; repeat: true; running: Object.keys(root.restarting).length > 0; onTriggered: root.refreshClients() }

  // Games are never "the layer's apps": the Fullscreen layer holds them and Restart must not close one.
  function isGame(c) {
    return /\.exe$|^steam_app_|^gamescope$/.test(c.class || "") || (c.tags || []).some(t => String(t).replace(/\*$/, "") === "game")
  }
  function onPad(id) { return root.clients.filter(c => c.workspace.name === "special:" + id && !isGame(c)) }

  function onClients() {
    const now = Date.now()
    const next = {}
    let changed = false
    const everyLayer = Model.allLayers(state)
    for (const layer of everyLayer) {
      const here = onPad(layer.id).map(c => c.address)
      let mine = (owned[layer.id] || []).filter(a => here.indexOf(a) >= 0)
      const t = tracking[layer.id]
      if (t && now < t.until) {
        for (const a of here) if (t.before.indexOf(a) < 0 && mine.indexOf(a) < 0) mine.push(a)
      } else if (t) {
        delete tracking[layer.id]
      }
      if (adoptPending && layer.apps.length > 0 && layer.id !== Model.FULLSCREEN_ID) mine = here.slice()
      next[layer.id] = mine
      if (JSON.stringify(mine) !== JSON.stringify(owned[layer.id] || [])) changed = true
    }
    adoptPending = false
    if (changed || Object.keys(owned).length !== Object.keys(next).length) {
      owned = next
      ownedFile.setText(JSON.stringify(next) + "\n")
      publish()
    }
    for (const id in restarting) {
      if ((owned[id] || []).length === 0 || now > restarting[id]) {
        delete restarting[id]
        restarting = Object.assign({}, restarting)
        launchApps(id)
      }
    }
  }

  function desktopEntries() {
    return (DesktopEntries.applications.values || []).map(Model.entryInfo)
  }

  function launchApps(id) {
    const layer = Model.findLayer(state, id)
    if (!layer || layer.apps.length === 0) return
    const entries = desktopEntries()
    tracking[id] = { until: Date.now() + 30000, before: clients.map(c => c.address) }
    launchChecks = Object.assign({}, launchChecks, { [id]: true })
    launchCheckTimer.restart()
    let code = ""
    for (const app of layer.apps)
      code += "__akton1_hub.launch(" + Model.luaValue(id) + ", " + Model.luaValue(Model.startupCommand(Model.resolveApp(app, entries))) + "); "
    Quickshell.execDetached(["hyprctl", "eval", code])
    clientsDebounce.restart()
  }

  // A launch that opens no window (wrong command, app not installed, a terminal app started without a terminal) says so.
  property var launchChecks: ({})
  Timer {
    id: launchCheckTimer
    interval: 12000
    onTriggered: {
      const missed = []
      for (const id in root.launchChecks) {
        const layer = Model.findLayer(root.state, id)
        const opened = (root.owned[id] || []).length
        if (layer && opened < layer.apps.length) missed.push(layer.label + " (" + opened + " of " + layer.apps.length + " opened)")
      }
      root.launchChecks = ({})
      if (missed.length > 0) root.say("Some apps did not open: " + missed.join(", ") + ". Remove the app and add it again from the search list.")
    }
  }

  function startApps(id, restart) {
    const layer = Model.findLayer(state, id)
    if (!layer) return "error: no scratchpad '" + id + "'"
    if (layer.apps.length === 0) return "error: " + layer.label + " has no apps listed"
    const mine = owned[id] || []
    if (mine.length > 0 && !restart) return "error: " + layer.label + " apps are already running (use restart)"
    if (restart && mine.length > 0) {
      let code = ""
      for (const a of mine) code += "__akton1_hub.close(" + Model.luaValue(a) + "); "
      Quickshell.execDetached(["hyprctl", "eval", code])
      restarting = Object.assign({}, restarting, { [id]: Date.now() + 6000 })
      return "ok"
    }
    launchApps(id)
    return "ok"
  }

  // ---- applying -----------------------------------------------------------------

  function scheduleApply() { applyTimer.restart() }
  Timer { id: applyTimer; interval: 200; onTriggered: root.apply() }

  function apply() {
    if (!ready) return
    animProc.running = false
    animProc.running = true
  }

  Process {
    id: animProc
    command: ["hyprctl", "-j", "animations"]
    stdout: StdioCollector { id: animOut }
    onExited: (code) => {
      if (code !== 0) { console.warn("akton1-hub: could not read Hyprland animations (exit " + code + ")"); return }
      try { root.anim = Model.animSpec(JSON.parse(animOut.text)) } catch (e) { root.anim = ({}) }
      root.runLua()
    }
  }

  function runLua() {
    const cfg = Model.luaConfig(state, anim, detected)
    luaProc.command = ["hyprctl", "eval", Model.luaStart(hubLua, cfg)]
    luaProc.running = false
    luaProc.running = true
  }

  Process {
    id: luaProc
    stdout: StdioCollector { id: luaOut }
    stderr: StdioCollector { id: luaErr }
    onExited: (code) => {
      if (code !== 0) {
        console.warn("akton1-hub: could not load hub.lua into Hyprland (exit " + code + "). Needs hyprctl and a Hyprland with Lua config support. "
                     + (luaErr.text || luaOut.text).trim())
        root.say("Could not register the scratchpad keys (see journalctl --user)")
        return
      }
      root.afterLua()
    }
  }

  function afterLua() {
    refreshBinds()
    pushToPlugins()
    if (!startupDone) { startupDone = true; startupProc.running = true }
    publish()
  }

  function pluginReady(id) {
    const p = plugins[id]
    return !!(p && p.installed && p.enabled)
  }

  function pushToPlugins() {
    if (pluginReady("io.github.akton1.scratchpad-frame")) {
      const touched = state.pads.length > 1 || state.pads.some(p => p.direction !== "bottom" || p.style !== "")
      if (touched || framePushed) {
        Quickshell.execDetached(["omarchy-shell", "scratchpad-frame", "padsSet", JSON.stringify({ pads: Model.framePads(state) })])
        framePushed = true
      }
      stylesProc.running = false
      stylesProc.running = true
    }
    if (pluginReady("io.github.akton1.fullscreen-app-auto-workspace")) {
      const padMagnet = state.magnet !== "" && state.magnet !== "off"
      if (padMagnet || magnetPushed) {
        Quickshell.execDetached(["omarchy-shell", "fullscreen-app-auto-workspace", "option", "layer", padMagnet ? state.magnet : "unset"])
        magnetPushed = padMagnet
      }
      const autoOff = state.magnet === "off"
      if (autoOff || autoMoveOffPushed) {
        Quickshell.execDetached(["omarchy-shell", "fullscreen-app-auto-workspace", "option", "autoMove", autoOff ? "false" : "unset"])
        autoMoveOffPushed = autoOff
      }
      const keep = Model.fullscreenKeepOthers(state)
      if (keep !== (keepPushed === true) && (keep || keepPushed !== null)) {
        Quickshell.execDetached(["omarchy-shell", "fullscreen-app-auto-workspace", "option", "keepOthers", keep ? "true" : "unset"])
      }
      keepPushed = keep
    }
  }

  // Apps listed for a scratchpad start once per Hyprland session, on that scratchpad, hidden.
  Process {
    id: startupProc
    command: ["sh", "-c", "m=\"$1/started-${HYPRLAND_INSTANCE_SIGNATURE:-none}\"; if [ -e \"$m\" ]; then echo skip; else : > \"$m\"; echo launch; fi", "sh", root.runtimeDir]
    stdout: StdioCollector { id: startupOut }
    onExited: {
      if (startupOut.text.trim() === "launch") root.launchStartupApps()
      else if (root.ownedMissing) { root.adoptPending = true; root.refreshClients() }
    }
  }

  function launchStartupApps() {
    for (const layer of Model.allLayers(state)) launchApps(layer.id)
  }

  // ---- changing settings -------------------------------------------------------------

  function clone(v) { return JSON.parse(JSON.stringify(v)) }

  // fn edits the copy it is given and returns "" or an error text; on success the new state is saved and applied.
  function mutate(fn) {
    const draft = clone(state)
    const err = fn(draft)
    if (err) return "error: " + err
    const next = Model.cleanState(draft)
    state = next
    saveState()
    scheduleApply()
    publish()
    return "ok"
  }

  function keyOwner(key, draft, exceptPad, exceptField) {
    for (const p of draft.pads) {
      if (p.key === key && !(p.id === exceptPad && exceptField === "key")) return p.label + " (Hub)"
      if (!p.builtin && p.moveKey === key && !(p.id === exceptPad && exceptField === "moveKey")) return "Move to " + p.label + " (Hub)"
    }
    if (draft.fullscreenKey === key && exceptPad !== "fullscreen") return draft.fullscreen.label + " (Hub)"
    return ""
  }

  function checkKey(raw, draft, exceptPad, exceptField, currentOwnKey) {
    const key = Model.normalizeKey(raw)
    if (key === "") return { error: "'" + raw + "' is not a key (example: SUPER + SHIFT + F9)" }
    if (!Model.keyUsable(key)) return { error: key + " would swallow normal typing; add SUPER, CTRL or ALT" }
    if (key === currentOwnKey) return { key: key }
    const own = keyOwner(key, draft, exceptPad, exceptField)
    if (own !== "") return { error: key + " is already used by " + own }
    const other = Model.findConflict(key, binds)
    if (other !== "") return { error: key + " is already used by: " + other }
    return { key: key }
  }

  function setKey(draft, pad, field, raw) {
    if (raw === "" || raw === "none") {
      if (field === "key" && pad.builtin) pad.key = Model.DEFAULT_KEY
      else pad[field] = ""
      return ""
    }
    if (pad.builtin && field === "key" && raw === "default") { pad.key = Model.DEFAULT_KEY; return "" }
    const res = checkKey(raw, draft, pad.id, field, pad[field])
    if (res.error) return res.error
    pad[field] = res.key
    return ""
  }

  function setMode(mode) {
    return mutate(d => {
      if (mode !== "connected" && mode !== "separated") return "mode is connected or separated"
      d.separate = mode === "separated" ? Model.VIEW_IDS.slice() : []
      return ""
    })
  }

  function viewArg(view, d) {
    if (Model.VIEW_IDS.indexOf(view) < 0) return "unknown plugin '" + view + "' (" + Model.VIEW_IDS.join(", ") + ")"
    return ""
  }

  function flag(value) { return value === "on" || value === "true" || value === "1" }

  // separate <view> on|off: on = its own icon, off = joined to the Hub icon
  function setSeparate(view, value) {
    return mutate(d => {
      const err = viewArg(view, d)
      if (err) return err
      d.separate = d.separate.filter(v => v !== view)
      if (flag(value)) d.separate.push(view)
      return ""
    })
  }

  // barShow <view> on|off: whether a separated plugin has its icon in the bar
  function setBarShow(view, value) {
    return mutate(d => {
      const err = viewArg(view, d)
      if (err) return err
      d.hidden = d.hidden.filter(v => v !== view)
      if (!flag(value)) d.hidden.push(view)
      return ""
    })
  }

  function padAdd(label, direction) {
    let newId = ""
    const res = mutate(d => {
      if (d.pads.length >= 12) return "twelve scratchpads is the limit"
      const taken = d.pads.map(p => p.id)
      newId = Model.slug(label, taken)
      d.pads.push({ id: newId, label: label !== "" ? label : "Pad " + d.pads.length, key: "", moveKey: "",
                    direction: Model.DIRECTIONS.indexOf(direction) >= 0 ? direction : "bottom", style: "", keepMine: false, apps: [] })
      return ""
    })
    return res === "ok" ? newId : res
  }

  function padRemove(id) {
    return mutate(d => {
      const i = d.pads.findIndex(p => p.id === id)
      if (i < 0) return "no scratchpad '" + id + "'"
      if (d.pads[i].builtin) return "the original scratchpad stays"
      d.pads.splice(i, 1)
      if (d.magnet === id) d.magnet = ""
      return ""
    })
  }

  function padSet(id, field, value) {
    return mutate(d => {
      const pad = Model.findLayer(d, id)
      if (!pad) return "no scratchpad '" + id + "'"
      if (field === "layout") {
        const v = value.trim().toLowerCase()
        if (v === "" || v === "default" || v === "none") { pad.layout = ""; return "" }
        if (Model.cleanLayout(v) !== v) return "layout is default, dwindle, master, scrolling, monocle or lua:<name>"
        pad.layout = v
        return ""
      }
      if (field === "label") {
        if (value.trim() === "") return "give a name"
        pad.label = value
        return ""
      }
      if (pad.layer) return "the Fullscreen layer has a name, a layout and apps here (its key is the fullscreenKey command)"
      if (field === "key" || field === "moveKey") {
        if (field === "moveKey" && pad.builtin) return "the original scratchpad keeps Omarchy's own move key"
        return setKey(d, pad, field, value)
      }
      if (field === "direction") {
        if (Model.DIRECTIONS.indexOf(value) < 0) return "direction is " + Model.DIRECTIONS.join(", ")
        pad.direction = value
        return ""
      }
      if (field === "style") { pad.style = value === "default" || value === "none" ? "" : value; return "" }
      if (field === "keepMine") { pad.keepMine = value === "true" || value === "on" || value === "1"; return "" }
      return "unknown field '" + field + "' (label, key, moveKey, direction, style, keepMine, layout)"
    })
  }

  function appAdd(id, command) {
    return mutate(d => {
      const pad = Model.findLayer(d, id)
      if (!pad) return "no scratchpad '" + id + "'"
      const cmd = command.trim()
      if (cmd === "") return "give a command"
      const wanted = Model.appId(cmd)
      if (wanted !== "" && !desktopEntries().some(e => e.id === wanted)) return "no installed app '" + wanted + "' (omarchy-shell akton1-hub appSearch <name>)"
      pad.apps.push(cmd)
      return ""
    })
  }

  function appRemove(id, index) {
    return mutate(d => {
      const pad = Model.findLayer(d, id)
      const i = parseInt(index)
      if (!pad) return "no scratchpad '" + id + "'"
      if (!(i >= 0 && i < pad.apps.length)) return "no app " + index
      pad.apps.splice(i, 1)
      return ""
    })
  }

  function setMagnet(id) {
    return mutate(d => {
      if (id === "off") { d.magnet = "off"; return "" }
      if (id === "none" || id === "" || id === Model.FULLSCREEN_ID) { d.magnet = ""; return "" }
      if (!d.pads.some(p => p.id === id)) return "no scratchpad '" + id + "'"
      d.magnet = id
      return ""
    })
  }

  function setFullscreenKey(raw) {
    return mutate(d => {
      if (raw === "" || raw === "none") { d.fullscreenKey = ""; return "" }
      const res = checkKey(raw, d, "fullscreen", "key", d.fullscreenKey)
      if (res.error) return res.error
      d.fullscreenKey = res.key
      return ""
    })
  }

  function toggle(id) {
    if (id === Model.FULLSCREEN_ID) {
      Quickshell.execDetached(["omarchy-shell", "fullscreen-app-auto-workspace", "toggle"])
      return "ok"
    }
    const pad = Model.findPad(state, id)
    if (!pad) return "error: no scratchpad '" + id + "'"
    Quickshell.execDetached(["hyprctl", "eval", "__akton1_hub.toggle(" + Model.luaValue(id) + ", " + Model.luaValue(pad.direction) + ")"])
    return "ok"
  }

  Process {
    id: installProc
    stdout: StdioCollector { id: installOut }
    stderr: StdioCollector { id: installErr }
    onExited: (code) => {
      const name = root.installing
      root.installing = ""
      if (code === 0) root.say(name + " installed and enabled")
      else root.say("Could not install " + name + ": " + ((installErr.text || installOut.text).trim().split("\n").pop() || "exit " + code))
      root.refreshPlugins()
      refreshLater.restart()
    }
  }
  Timer { id: refreshLater; interval: 4000; onTriggered: root.refreshPlugins() }

  function install(id) {
    const entry = Model.catalogEntry(id)
    if (!entry) return "error: unknown plugin '" + id + "'"
    if (installProc.running) return "error: an install is already running"
    if (plugins[id] && plugins[id].installed && plugins[id].enabled) return "error: " + entry.name + " is already installed and on"
    installing = entry.name
    installProc.command = plugins[id] && plugins[id].installed ? ["omarchy", "plugin", "enable", id]
                                                             : ["omarchy", "plugin", "add", entry.repo, "--enable", "--yes"]
    installProc.running = true
    publish()
    return "ok"
  }

  IpcHandler {
    target: "akton1-hub"
    function state(): string { return JSON.stringify(root.snapshot()) }
    function mode(value: string): string { return value === "" ? root.state.mode : root.setMode(value) }
    function separate(view: string, value: string): string { return root.setSeparate(view, value) }
    function barShow(view: string, value: string): string { return root.setBarShow(view, value) }
    function padAdd(label: string, direction: string): string { return root.padAdd(label, direction) }
    function padRemove(id: string): string { return root.padRemove(id) }
    function padSet(id: string, field: string, value: string): string { return root.padSet(id, field, value) }
    function appAdd(id: string, command: string): string { return root.appAdd(id, command) }
    function appRemove(id: string, index: string): string { return root.appRemove(id, index) }
    function appSearch(words: string): string { return JSON.stringify(Model.matchApps(root.desktopEntries(), words)) }
    function magnet(id: string): string { return root.setMagnet(id) }
    function fullscreenKey(keys: string): string { return root.setFullscreenKey(keys) }
    function toggle(id: string): string { return root.toggle(id) }
    function appsStart(id: string): string { return root.startApps(id, false) }
    function appsRestart(id: string): string { return root.startApps(id, true) }
    function install(id: string): string { return root.install(id) }
    function refresh(): string { root.refreshPlugins(); root.refreshBinds(); bindingsFile.reload(); root.scheduleApply(); return "ok" }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "configreloaded") {
        root.refreshBinds()
        bindingsFile.reload()
        root.scheduleApply()
      } else if (event.name === "openwindow" || event.name === "closewindow" || event.name.indexOf("movewindow") === 0) {
        clientsDebounce.restart()
      }
    }
  }

  Component.onCompleted: {
    init.running = true
    refreshPlugins()
    refreshBinds()
  }

  Component.onDestruction: {
    Quickshell.execDetached(["hyprctl", "eval", "if __akton1_hub then __akton1_hub.shutdown(); __akton1_hub = nil end"])
  }
}
