.pragma library

// Pure helpers for the AktOn1 Plugin Hub: no Quickshell types, so the same file
// runs under plain node for the tests in tests/model.test.js.

var DEFAULT_KEY = "SUPER + S"
var DEFAULT_MOVE_KEY = "SUPER + ALT + S"
var DIRECTIONS = ["bottom", "top", "left", "right"]
var MODES = ["connected", "separated"]

// The AktOn1 plugins the Hub knows about. None of them is bundled: the Hub only
// knows where each one lives and how to add it.
var CATALOG = [
  {
    id: "io.github.akton1.scratchpad-frame",
    name: "Scratchpad Frame",
    target: "scratchpad-frame",
    view: "scratchpads",
    repo: "https://github.com/AktOn1/omarchy-scratchpad-frame.git",
    blurb: "A frame around each scratchpad that slides in and out with it."
  },
  {
    id: "io.github.akton1.fullscreen-app-auto-workspace",
    name: "Fullscreen App Auto Workspace",
    target: "fullscreen-app-auto-workspace",
    view: "fullscreen",
    repo: "https://github.com/AktOn1/omarchy-fullscreen-app-auto-workspace.git",
    blurb: "Fullscreen games get their own layer and come and go with one key."
  }
]

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
           direction: "bottom", style: "", keepMine: false, apps: [] }
}

function defaultState() {
  return { version: 1, mode: "connected", pads: [builtinPad()], magnet: "", fullscreenKey: "" }
}

function cleanText(v, max) {
  return String(v === undefined || v === null ? "" : v).replace(/[\r\n\t]+/g, " ").trim().slice(0, max)
}

function slug(label, taken) {
  var base = cleanText(label, 24).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
  if (base === "") base = "pad"
  var id = base
  var n = 2
  while (taken.indexOf(id) >= 0) id = base + "-" + (n++)
  return id
}

function cleanPad(p, taken) {
  if (!p || typeof p !== "object") return null
  var builtin = p.id === "scratchpad"
  var id = builtin ? "scratchpad" : String(p.id || "")
  if (!builtin && !/^[a-z0-9][a-z0-9-]{0,23}$/.test(id)) id = slug(p.label || id, taken)
  if (taken.indexOf(id) >= 0) return null
  var apps = []
  if (Array.isArray(p.apps)) {
    for (var i = 0; i < p.apps.length && apps.length < 20; i++) {
      var c = cleanText(p.apps[i], 400)
      if (c !== "") apps.push(c)
    }
  }
  return {
    id: id,
    label: cleanText(p.label, 24) || (builtin ? "Scratchpad" : id),
    builtin: builtin,
    key: p.key === undefined && builtin ? DEFAULT_KEY : normalizeKey(p.key),
    moveKey: builtin ? DEFAULT_MOVE_KEY : normalizeKey(p.moveKey),
    direction: DIRECTIONS.indexOf(p.direction) >= 0 ? p.direction : "bottom",
    style: cleanText(p.style, 40),
    keepMine: p.keepMine === true,
    apps: apps
  }
}

// Accepts whatever was on disk (or typed) and returns a complete, valid state.
function cleanState(raw) {
  var s = defaultState()
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return s
  if (MODES.indexOf(raw.mode) >= 0) s.mode = raw.mode
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
  s.magnet = typeof raw.magnet === "string" && taken.concat(["scratchpad"]).indexOf(raw.magnet) >= 0 ? raw.magnet : ""
  s.fullscreenKey = normalizeKey(raw.fullscreenKey)
  return s
}

function findPad(state, id) {
  for (var i = 0; i < state.pads.length; i++) if (state.pads[i].id === id) return state.pads[i]
  return null
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
  return { pads: pads, commands: commands, anim: anim }
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

// The "fullscreen magnet": which special workspace the fullscreen layer is.
function fullscreenLayer(state) {
  return state.magnet !== "" ? state.magnet : ""
}

function startupCommand(command) {
  return "uwsm-app -- " + command
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
  if (fs && fs.installed && fs.enabled) out.push({ id: "fullscreen", title: "Fullscreen layer", glyph: glyph(0xf0293),
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

function tooltip(mode, viewTitle, titles) {
  if (mode === "connected") return "AktOn1 plugins: connected" + (titles.length ? " (" + titles.join(", ") + ")" : "")
  return viewTitle + ": AktOn1 plugin, disconnected"
}

if (typeof module !== "undefined") module.exports = {
  DEFAULT_KEY: DEFAULT_KEY, DIRECTIONS: DIRECTIONS, CATALOG: CATALOG, defaultState: defaultState, cleanState: cleanState,
  cleanPad: cleanPad, slug: slug, normalizeKey: normalizeKey, keyParts: keyParts, keyFromEvent: keyFromEvent,
  keyUsable: keyUsable, findConflict: findConflict, detectBindings: detectBindings, luaConfig: luaConfig,
  luaValue: luaValue, luaStart: luaStart, animSpec: animSpec, framePads: framePads, views: views, missing: missing,
  pluginStatus: pluginStatus, tooltip: tooltip, installCommand: installCommand, padNeedsHubBind: padNeedsHubBind,
  findPad: findPad, glyph: glyph, catalogEntry: catalogEntry, startupCommand: startupCommand
}
