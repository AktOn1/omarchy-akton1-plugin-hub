.pragma library

// Pure helpers for the AktOn1 Plugin Hub: no Quickshell types, so the same file
// runs under plain node for the tests in tests/model.test.js.

var DEFAULT_KEY = "SUPER + S"
var DEFAULT_MOVE_KEY = "SUPER + ALT + S"
var DIRECTIONS = ["bottom", "top", "left", "right"]
var MODES = ["connected", "separated"]
var FULLSCREEN_ID = "fullscreen"
var LAYOUTS = [
  { value: "", label: "Default" },
  { value: "dwindle", label: "Dwindle" },
  { value: "master", label: "Master" },
  { value: "scrolling", label: "Scrolling" },
  { value: "monocle", label: "Monocle" }
]

// The AktOn1 plugins the Hub knows about. None of them is bundled: the Hub only
// knows where each one lives and how to add it.
var STORE_URL = "https://plugins.omarchy.org/"
var VIEW_IDS = ["scratchpads", "fullscreen"]

var CATALOG = [
  {
    id: "io.github.akton1.scratchpad-frame",
    name: "Scratchpad Frame",
    target: "scratchpad-frame",
    view: "scratchpads",
    ownView: false,
    listed: false,
    repo: "https://github.com/AktOn1/omarchy-scratchpad-frame.git",
    page: "https://github.com/AktOn1/omarchy-scratchpad-frame",
    blurb: "A frame around each scratchpad that slides in and out with it.",
    info: "Draws a decorative frame (24 styles) around the scratchpad and slides it in and out with it. Works alone on SUPER+S; with the Hub every scratchpad can have its own frame.",
    note: "No icon of its own: its frame styles appear on the scratchpad cards."
  },
  {
    id: "io.github.akton1.fullscreen-app-auto-workspace",
    name: "Fullscreen App Auto Workspace",
    target: "fullscreen-app-auto-workspace",
    view: "fullscreen",
    ownView: true,
    listed: true,
    repo: "https://github.com/AktOn1/omarchy-fullscreen-app-auto-workspace.git",
    page: "https://github.com/AktOn1/omarchy-fullscreen-app-auto-workspace",
    blurb: "Fullscreen games get their own layer and come and go with one key.",
    info: "Moves every game that goes fullscreen to its own hidden layer, so your normal workspace stays clean. One key brings the game back or sends it away; it can mute the game while hidden."
  },
  {
    id: "io.github.akton1.background-worker-talk-to-me",
    name: "Background Worker Talk To Me",
    target: "background-worker-talk-to-me",
    view: "",
    ownView: false,
    listed: false,
    repo: "https://github.com/AktOn1/omarchy-background-worker-talk-to-me.git",
    page: "https://github.com/AktOn1/omarchy-background-worker-talk-to-me",
    blurb: "An AI agent that changes your desktop asks you quick questions, and a TESTING banner shows while it works.",
    info: "When a script or AI agent moves windows or changes the bar, it shows a countdown and a TESTING banner and asks you one-key questions (Y / N / ?) or a typed reply, instead of slow screenshot loops. Experimental: agents can also ask a plain question outside a test (off by default). Settings are on the command line: talk-to-me settings.",
    note: "No icon: it works from the command line (talk-to-me). Settings: talk-to-me settings. Experimental questions outside a test: talk-to-me settings set questions on."
  }
]

// The Hub's own scratchpads: always there, nothing to install.
var BUILTIN_VIEW = {
  id: "scratchpads",
  name: "Scratchpads",
  info: "Create several scratchpads, each with its own key, slide-in side, layout and apps that start at login. Part of the Hub itself."
}

function storeLink(entry) {
  return entry.listed ? STORE_URL + "plugin.html?id=" + encodeURIComponent(entry.id) : ""
}

function catalogEntry(id) {
  for (var i = 0; i < CATALOG.length; i++) if (CATALOG[i].id === id) return CATALOG[i]
  return null
}

function installCommand(entry) {
  return "omarchy plugin add " + entry.repo + " --enable"
}

// ---- state ------------------------------------------------------------------

function builtinPad() {
  return { id: "scratchpad", label: "Scratchpad", builtin: true, key: DEFAULT_KEY, moveKey: DEFAULT_MOVE_KEY,
           direction: "bottom", style: "", keepMine: false, layout: "", apps: [] }
}

function fullscreenLayer() {
  return { id: FULLSCREEN_ID, label: "Fullscreen", layer: true, layout: "", apps: [] }
}

function defaultState() {
  return { version: 1, mode: "connected", separate: [], hidden: [], pads: [builtinPad()], magnet: "", fullscreenKey: "", fullscreen: fullscreenLayer() }
}

function cleanText(v, max) {
  return String(v === undefined || v === null ? "" : v).replace(/[\r\n\t]+/g, " ").trim().slice(0, max)
}

function slug(label, taken) {
  var base = cleanText(label, 24).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
  if (base === "") base = "pad"
  var id = base
  var n = 2
  while (taken.indexOf(id) >= 0 || id === FULLSCREEN_ID) id = base + "-" + (n++)
  return id
}

// "dwindle", "master", "lua:name": what Hyprland accepts as a workspace layout; anything else is "default".
function cleanLayout(v) {
  var t = cleanText(v, 40)
  return /^[a-z][a-z0-9_-]*(:[A-Za-z0-9_.-]+)?$/.test(t) ? t : ""
}

function cleanApps(list) {
  var apps = []
  if (Array.isArray(list)) {
    for (var i = 0; i < list.length && apps.length < 20; i++) {
      var c = cleanText(list[i], 400)
      if (c !== "") apps.push(c)
    }
  }
  return apps
}

function cleanLayer(raw) {
  var l = fullscreenLayer()
  if (raw && typeof raw === "object" && !Array.isArray(raw)) {
    l.label = cleanText(raw.label, 24) || l.label
    l.layout = cleanLayout(raw.layout)
    l.apps = cleanApps(raw.apps)
  }
  return l
}

function cleanPad(p, taken) {
  if (!p || typeof p !== "object") return null
  var builtin = p.id === "scratchpad"
  var id = builtin ? "scratchpad" : String(p.id || "")
  if (!builtin && (!/^[a-z0-9][a-z0-9-]{0,23}$/.test(id) || id === FULLSCREEN_ID)) id = slug(p.label || id, taken)
  if (taken.indexOf(id) >= 0) return null
  var apps = cleanApps(p.apps)
  return {
    id: id,
    label: cleanText(p.label, 24) || (builtin ? "Scratchpad" : id),
    builtin: builtin,
    key: p.key === undefined && builtin ? DEFAULT_KEY : normalizeKey(p.key),
    moveKey: builtin ? DEFAULT_MOVE_KEY : normalizeKey(p.moveKey),
    direction: DIRECTIONS.indexOf(p.direction) >= 0 ? p.direction : "bottom",
    style: cleanText(p.style, 40),
    keepMine: p.keepMine === true,
    layout: cleanLayout(p.layout),
    apps: apps
  }
}

function cleanViewList(list) {
  var out = []
  if (Array.isArray(list)) for (var i = 0; i < list.length; i++) if (VIEW_IDS.indexOf(list[i]) >= 0 && out.indexOf(list[i]) < 0) out.push(list[i])
  return out
}

// "connected" (one icon for all), "separated" (one icon each) or "mixed".
function modeOf(separate) {
  var n = VIEW_IDS.filter(function (v) { return separate.indexOf(v) >= 0 }).length
  return n === 0 ? "connected" : (n === VIEW_IDS.length ? "separated" : "mixed")
}

// Accepts whatever was on disk (or typed) and returns a complete, valid state.
function cleanState(raw) {
  var s = defaultState()
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return s
  s.separate = Array.isArray(raw.separate) ? cleanViewList(raw.separate) : (raw.mode === "separated" ? VIEW_IDS.slice() : [])
  s.hidden = cleanViewList(raw.hidden)
  s.mode = modeOf(s.separate)
  var pads = []
  var taken = []
  if (Array.isArray(raw.pads)) {
    for (var i = 0; i < raw.pads.length && pads.length < 12; i++) {
      var pad = cleanPad(raw.pads[i], taken)
      if (pad) { pads.push(pad); taken.push(pad.id) }
    }
  }
  if (taken.indexOf("scratchpad") < 0) pads.unshift(builtinPad())
  else pads.sort(function (a, b) { return (b.builtin ? 1 : 0) - (a.builtin ? 1 : 0) })
  s.pads = pads
  s.magnet = typeof raw.magnet === "string" && (raw.magnet === "off" || taken.concat(["scratchpad"]).indexOf(raw.magnet) >= 0) ? raw.magnet : ""
  s.fullscreenKey = normalizeKey(raw.fullscreenKey)
  s.fullscreen = cleanLayer(raw.fullscreen)
  return s
}

function findPad(state, id) {
  for (var i = 0; i < state.pads.length; i++) if (state.pads[i].id === id) return state.pads[i]
  return null
}

// A scratchpad or the Fullscreen layer, by id (the Fullscreen layer has no key, side or frame of its own here).
function findLayer(state, id) {
  return id === FULLSCREEN_ID ? state.fullscreen : findPad(state, id)
}

function allLayers(state) {
  return state.pads.concat([state.fullscreen])
}

// Layouts to offer: the stock ones, plus any custom one in use (a Lua layout, or one found on a workspace).
function layoutOptions(inUse) {
  var out = LAYOUTS.slice()
  var seen = {}
  for (var i = 0; i < out.length; i++) seen[out[i].value] = true
  for (var j = 0; j < (inUse || []).length; j++) {
    var v = cleanLayout(inUse[j])
    if (v !== "" && !seen[v]) { seen[v] = true; out.push({ value: v, label: v.replace(/^lua:/, "") + (v.indexOf("lua:") === 0 ? " (Lua)" : "") }) }
  }
  return out
}

// With apps of its own, the Fullscreen layer must not push non-game windows away.
function fullscreenKeepOthers(state) {
  return state.fullscreen.apps.length > 0
}

// ---- keys -------------------------------------------------------------------

var MOD_ORDER = ["SUPER", "CTRL", "ALT", "SHIFT"]
var MOD_BITS = { SHIFT: 1, CAPS: 2, CTRL: 4, ALT: 8, SUPER: 64 }
var MOD_ALIAS = { SUPER: "SUPER", META: "SUPER", WIN: "SUPER", MOD4: "SUPER", CTRL: "CTRL", CONTROL: "CTRL",
                  ALT: "ALT", MOD1: "ALT", SHIFT: "SHIFT" }

// "super+shift+f9" -> "SUPER + SHIFT + F9"; "" when it is not a usable key.
function normalizeKey(text) {
  if (text === undefined || text === null) return ""
  var parts = String(text).split(/\s*\+\s*/)
  var mods = {}
  var key = ""
  for (var i = 0; i < parts.length; i++) {
    var p = parts[i].trim().toUpperCase()
    if (p === "") continue
    if (MOD_ALIAS[p] && i < parts.length - 1) mods[MOD_ALIAS[p]] = true
    else if (key === "") key = p
    else return ""
  }
  if (key === "" || !/^[A-Z0-9_]{1,24}$/.test(key)) return ""
  var out = []
  for (var m = 0; m < MOD_ORDER.length; m++) if (mods[MOD_ORDER[m]]) out.push(MOD_ORDER[m])
  out.push(key)
  return out.join(" + ")
}

function keyParts(text) {
  var n = normalizeKey(text)
  if (n === "") return null
  var parts = n.split(" + ")
  var key = parts.pop()
  var mask = 0
  for (var i = 0; i < parts.length; i++) mask |= MOD_BITS[parts[i]]
  return { mask: mask, key: key }
}

var QT_NAMES = {
  0x20: "SPACE", 0x01000000: "ESCAPE", 0x01000001: "TAB", 0x01000004: "RETURN", 0x01000005: "RETURN",
  0x01000003: "BACKSPACE", 0x01000007: "DELETE", 0x01000006: "INSERT", 0x01000010: "HOME", 0x01000011: "END",
  0x01000016: "PRIOR", 0x01000017: "NEXT", 0x01000012: "LEFT", 0x01000013: "UP", 0x01000014: "RIGHT",
  0x01000015: "DOWN", 0x2c: "COMMA", 0x2e: "PERIOD", 0x2f: "SLASH", 0x3b: "SEMICOLON", 0x27: "APOSTROPHE",
  0x5b: "BRACKETLEFT", 0x5d: "BRACKETRIGHT", 0x5c: "BACKSLASH", 0x2d: "MINUS", 0x3d: "EQUAL", 0x60: "GRAVE"
}
var MODIFIER_KEYS = [0x01000020, 0x01000021, 0x01000022, 0x01000023, 0x01000024, 0x01000025, 0x01001103, 0x01000026, 0x01000027]

// A Qt key press (key code + modifier flags) as a Hyprland key string, "" while only a modifier is held.
function keyFromEvent(qtKey, ctrl, alt, shift, meta) {
  if (MODIFIER_KEYS.indexOf(qtKey) >= 0) return ""
  var name = ""
  if (qtKey >= 0x01000030 && qtKey <= 0x01000047) name = "F" + (qtKey - 0x01000030 + 1)
  else if (QT_NAMES[qtKey]) name = QT_NAMES[qtKey]
  else if (qtKey >= 0x41 && qtKey <= 0x5a) name = String.fromCharCode(qtKey)
  else if (qtKey >= 0x30 && qtKey <= 0x39) name = String.fromCharCode(qtKey)
  if (name === "") return ""
  var parts = []
  if (meta) parts.push("SUPER")
  if (ctrl) parts.push("CTRL")
  if (alt) parts.push("ALT")
  if (shift) parts.push("SHIFT")
  parts.push(name)
  return normalizeKey(parts.join(" + "))
}

// A key that would swallow normal typing (no modifier) is refused.
function keyUsable(text) {
  var p = keyParts(text)
  if (!p) return false
  if (p.mask === 0 && !/^F([1-9]|1[0-9]|2[0-4])$/.test(p.key)) return false
  return true
}

// Which existing Hyprland binding already uses this key?
// `binds` is the parsed `hyprctl -j binds`; the Hub's own bindings are ignored.
function findConflict(text, binds) {
  var want = keyParts(text)
  if (!want || !Array.isArray(binds)) return ""
  for (var i = 0; i < binds.length; i++) {
    var b = binds[i]
    if (!b || String(b.key || "").toUpperCase() !== want.key) continue
    if ((Number(b.modmask) & ~2) !== want.mask) continue
    var d = String(b.description || "")
    if (d.indexOf("AktOn1 Hub:") === 0) continue
    return d !== "" ? d : (b.dispatcher || "another binding") + (b.arg ? " " + b.arg : "")
  }
  return ""
}

// ---- bindings the user wrote by hand ------------------------------------------

// Reads ~/.config/hypr/bindings.lua (text only, never written) and reports the
// keys the user already bound for a scratchpad or for the fullscreen layer.
function detectBindings(luaText) {
  var found = { pads: {}, fullscreen: "" }
  var lines = String(luaText || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (/^\s*--/.test(line)) continue
    var q = /["']([^"']+)["']/.exec(line)
    if (!q) continue
    var key = normalizeKey(q[1])
    if (key === "") continue
    var m = /toggle_special\(\s*["']([a-z0-9_-]+)["']\s*\)/.exec(line) || /togglespecialworkspace[ ,]+([a-z0-9_-]+)/.exec(line)
    if (m && (line.indexOf("bind") >= 0)) found.pads[m[1]] = key
    if (/fullscreen-app-auto-workspace\s+toggle/.test(line)) found.fullscreen = key
  }
  return found
}

// ---- what the Hub hands to its Lua runtime / the other plugins -------------------

function sameKey(a, b) { return normalizeKey(a) !== "" && normalizeKey(a) === normalizeKey(b) }

function padNeedsHubBind(pad, detected) {
  if (pad.keepMine && detected.pads[pad.id]) return false
  if (pad.builtin) return pad.direction !== "bottom" || !sameKey(pad.key, DEFAULT_KEY)
  return pad.key !== ""
}

function luaConfig(state, anim, detected) {
  var pads = []
  for (var i = 0; i < state.pads.length; i++) {
    var p = state.pads[i]
    if (!padNeedsHubBind(p, detected)) continue
    pads.push({ id: p.id, key: p.key, moveKey: p.moveKey, direction: p.direction, label: p.label,
                builtin: p.builtin && sameKey(p.key, DEFAULT_KEY) })
  }
  var commands = []
  var fsKey = state.fullscreenKey
  if (fsKey !== "" && !(detected.fullscreen && sameKey(detected.fullscreen, fsKey)))
    commands.push({ key: fsKey, command: "omarchy-shell fullscreen-app-auto-workspace toggle", label: "toggle fullscreen layer" })
  var layouts = allLayers(state).map(function (l) { return { id: l.id, layout: l.layout } })
  return { pads: pads, commands: commands, anim: anim, layouts: layouts }
}

function luaValue(v) {
  if (v === null || v === undefined) return "nil"
  if (typeof v === "boolean") return v ? "true" : "false"
  if (typeof v === "number") return String(v)
  if (typeof v === "string") {
    return '"' + v.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\r?\n/g, "\\n") + '"'
  }
  if (Array.isArray(v)) return "{" + v.map(luaValue).join(",") + "}"
  var out = []
  for (var k in v) if (v[k] !== undefined) out.push("[" + luaValue(k) + "]=" + luaValue(v[k]))
  return "{" + out.join(",") + "}"
}

function luaStart(hubLuaPath, cfg) {
  return "local m = dofile(" + luaValue(hubLuaPath) + "); m.start(" + luaValue(cfg) + ")"
}

// First explicitly set value up the chain specialWorkspace > workspaces > global
// (the same rule Hyprland itself uses), for both special workspace leaves.
function animSpec(records) {
  var list = Array.isArray(records) && Array.isArray(records[0]) ? records[0] : records
  var byName = {}
  for (var i = 0; i < (list || []).length; i++) byName[list[i].name] = list[i]
  function inherited(key) {
    var chain = ["specialWorkspace", "workspaces", "global"]
    for (var c = 0; c < chain.length; c++) {
      var rec = byName[chain[c]]
      if (rec && rec.overridden && rec[key] !== "" && rec[key] !== undefined) return rec[key]
    }
    return undefined
  }
  var out = {}
  var leaves = ["specialWorkspaceIn", "specialWorkspaceOut"]
  for (var l = 0; l < leaves.length; l++) {
    var cur = byName[leaves[l]]
    var own = cur && cur.overridden
    out[leaves[l]] = {
      enabled: own ? cur.enabled !== false : inherited("enabled") !== false,
      speed: Number(own ? cur.speed : (inherited("speed") || 1)),
      bezier: (own && cur.bezier) || inherited("bezier") || "default",
      style: (own ? cur.style : inherited("style")) || ""
    }
  }
  return out
}

// What Scratchpad Frame needs: one entry per pad.
function framePads(state) {
  return state.pads.map(function (p) {
    return { name: p.id, label: p.label.toUpperCase(), direction: p.direction, style: p.style }
  })
}

// Where fullscreen games go: the Fullscreen layer unless a scratchpad holds the magnet; "off" = nowhere.
function effectiveMagnet(state) {
  return state.magnet === "off" ? "none" : state.magnet !== "" ? state.magnet : FULLSCREEN_ID
}

function shellQuote(s) {
  return "'" + String(s).replace(/'/g, "'\\''") + "'"
}

// A layer's app is either "app:<desktop id>" (picked from the installed apps) or a plain command.
function appId(app) {
  var m = /^app:(.+)$/.exec(String(app))
  return m ? m[1] : ""
}

// Picked apps go through gtk-launch, like Omarchy's own launcher, so terminal apps (cliamp, btop...) get their terminal.
function startupCommand(app) {
  var id = appId(app)
  if (id !== "") return "uwsm-app -- gtk-launch " + shellQuote(id + ".desktop")
  return "uwsm-app -- " + app
}

// Plain object from a Quickshell DesktopEntry.
function entryInfo(e) {
  return {
    id: String(e.id || ""), name: String(e.name || e.id || ""), generic: String(e.genericName || ""),
    comment: String(e.comment || ""), keywords: (e.keywords || []).map(String).join(" "),
    terminal: e.runInTerminal === true, hidden: e.noDisplay === true,
    command: (e.command || []).map(String)
  }
}

function appOptions(entries) {
  return entries.filter(function (e) { return e.id !== "" && !e.hidden })
    .sort(function (a, b) { return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1 })
    .map(function (e) {
      var what = e.generic || e.comment
      return { value: "app:" + e.id, label: e.name, description: (what ? what + " - " : "") + (e.terminal ? "terminal app, " : "") + e.id }
    })
}

// Installed apps whose name, kind, id or keywords contain every word of the query (names starting with it first).
function matchApps(entries, query) {
  var words = String(query).toLowerCase().split(/\s+/).filter(function (w) { return w !== "" })
  if (words.length === 0) return []
  var hits = entries.filter(function (e) {
    if (e.id === "" || e.hidden) return false
    var hay = (e.name + " " + e.generic + " " + e.id + " " + e.keywords).toLowerCase()
    return words.every(function (w) { return hay.indexOf(w) >= 0 })
  })
  hits.sort(function (a, b) {
    var pa = a.name.toLowerCase().indexOf(words[0]) === 0 ? 0 : 1
    var pb = b.name.toLowerCase().indexOf(words[0]) === 0 ? 0 : 1
    return pa !== pb ? pa - pb : (a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1)
  })
  return hits.slice(0, 10).map(function (e) { return { app: "app:" + e.id, name: e.name, kind: e.generic, terminal: e.terminal } })
}

// A bare command that is really a terminal app (cliamp, btop) is started through its desktop entry, which opens the terminal.
function resolveApp(app, entries) {
  if (appId(app) !== "" || /\s/.test(String(app).trim())) return app
  var base = String(app).trim().split("/").pop()
  for (var i = 0; i < entries.length; i++) {
    var e = entries[i]
    if (e.terminal && e.command.length === 1 && e.command[0].split("/").pop() === base) return "app:" + e.id
  }
  return app
}

function appTitle(app, entries) {
  var id = appId(app)
  if (id === "") return String(app)
  for (var i = 0; i < entries.length; i++) if (entries[i].id === id) return entries[i].name + (entries[i].terminal ? " (terminal)" : "")
  return id + " (not installed)"
}

// ---- views (what the bar shows) ---------------------------------------------------

function glyph(cp) {
  var c = cp - 0x10000
  return String.fromCharCode(0xd800 + (c >> 10), 0xdc00 + (c & 0x3ff))
}

// `plugins` = the Hub's idea of what is installed: { id: { installed, enabled } }
function views(plugins) {
  var out = [{ id: "scratchpads", title: "Scratchpads", glyph: glyph(0xf05b2), plugin: "io.github.akton1.scratchpad-frame" }]
  var fs = plugins["io.github.akton1.fullscreen-app-auto-workspace"]
  if (fs && fs.installed && fs.enabled) out.push({ id: "fullscreen", title: "Fullscreen", glyph: glyph(0xf0293),
                                     plugin: "io.github.akton1.fullscreen-app-auto-workspace" })
  return out
}

function missing(plugins) {
  return CATALOG.filter(function (c) { return !(plugins[c.id] && plugins[c.id].installed && plugins[c.id].enabled) })
}

function pluginStatus(listJson) {
  var out = {}
  var list = []
  try { list = typeof listJson === "string" ? JSON.parse(listJson) : listJson } catch (e) { list = [] }
  for (var i = 0; i < CATALOG.length; i++) out[CATALOG[i].id] = { installed: false, enabled: false }
  for (var j = 0; j < (list || []).length; j++) {
    var p = list[j]
    if (out[p.id]) out[p.id] = { installed: true, enabled: p.enabled === true }
  }
  return out
}

// The list in the settings page: the Hub's own scratchpads first, then every AktOn1 plugin the Hub knows.
// state: "builtin" | "on" | "off" (installed, turned off) | "missing"; viewId is "" when the plugin has no icon of its own.
function pluginRows(plugins) {
  var rows = [{ key: BUILTIN_VIEW.id, name: BUILTIN_VIEW.name, info: BUILTIN_VIEW.info, viewId: BUILTIN_VIEW.id, state: "builtin", entry: null }]
  CATALOG.forEach(function (c) {
    var p = plugins[c.id]
    rows.push({ key: c.id, name: c.name, info: c.info, viewId: c.ownView ? c.view : "", entry: c,
                state: p && p.installed ? (p.enabled ? "on" : "off") : "missing" })
  })
  return rows
}

// What to type in a terminal to get (or turn on) this plugin.
function commandFor(row) {
  return row.state === "off" ? "omarchy plugin enable " + row.entry.id : installCommand(row.entry)
}

// What the bar shows: one Hub icon for the connected plugins, one icon per separated plugin that is not hidden.
// If that leaves nothing, the Hub icon shows everything, so the settings gear can always be reached.
function barIcons(state, plugins) {
  var vs = views(plugins)
  var joined = vs.filter(function (v) { return state.separate.indexOf(v.id) < 0 })
  var out = []
  if (joined.length > 0) out.push({ id: "all", glyph: glyph(0xf0337), title: "AktOn1 plugins" })
  vs.forEach(function (v) {
    if (state.separate.indexOf(v.id) >= 0 && state.hidden.indexOf(v.id) < 0) out.push({ id: v.id, glyph: v.glyph, title: v.title })
  })
  if (out.length === 0) out.push({ id: "all", glyph: glyph(0xf0337), title: "AktOn1 plugins" })
  return out
}

// The sections a flyout shows: "all" = the connected plugins (everything when none are connected).
function viewsFor(state, plugins, id) {
  var vs = views(plugins)
  if (id !== "all") return vs.filter(function (v) { return v.id === id })
  var joined = vs.filter(function (v) { return state.separate.indexOf(v.id) < 0 })
  return joined.length > 0 ? joined : vs
}

function tooltip(mode, viewTitle, titles) {
  if (mode === "connected") return "AktOn1 plugins: connected" + (titles.length ? " (" + titles.join(", ") + ")" : "")
  return viewTitle + ": AktOn1 plugin, disconnected"
}

if (typeof module !== "undefined") module.exports = {
  DEFAULT_KEY: DEFAULT_KEY, FULLSCREEN_ID: FULLSCREEN_ID, LAYOUTS: LAYOUTS, cleanLayout: cleanLayout, findLayer: findLayer,
  allLayers: allLayers, effectiveMagnet: effectiveMagnet, layoutOptions: layoutOptions, fullscreenKeepOthers: fullscreenKeepOthers, DIRECTIONS: DIRECTIONS, CATALOG: CATALOG, defaultState: defaultState, cleanState: cleanState,
  cleanPad: cleanPad, slug: slug, normalizeKey: normalizeKey, keyParts: keyParts, keyFromEvent: keyFromEvent,
  keyUsable: keyUsable, findConflict: findConflict, detectBindings: detectBindings, luaConfig: luaConfig,
  luaValue: luaValue, luaStart: luaStart, animSpec: animSpec, framePads: framePads, views: views, missing: missing,
  pluginStatus: pluginStatus, tooltip: tooltip, barIcons: barIcons, viewsFor: viewsFor, modeOf: modeOf, storeLink: storeLink,
  pluginRows: pluginRows, commandFor: commandFor, STORE_URL: STORE_URL, VIEW_IDS: VIEW_IDS, BUILTIN_VIEW: BUILTIN_VIEW, installCommand: installCommand, padNeedsHubBind: padNeedsHubBind,
  findPad: findPad, glyph: glyph, catalogEntry: catalogEntry, startupCommand: startupCommand,
  appId: appId, entryInfo: entryInfo, appOptions: appOptions, matchApps: matchApps, resolveApp: resolveApp, appTitle: appTitle
}
