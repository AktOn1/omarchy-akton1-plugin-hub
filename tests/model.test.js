// Run: node tests/model.test.js   (pure logic of HubModel.js, no Quickshell needed)
const assert = require("assert")
const fs = require("fs")
const path = require("path")
const src = fs.readFileSync(path.join(__dirname, "..", "HubModel.js"), "utf8").replace(/^\.pragma library\n/, "")
const mod = { exports: {} }
new Function("module", src)(mod)
const M = mod.exports

let n = 0
function t(name, fn) { fn(); n++; console.log("ok - " + name) }

t("default state has the original scratchpad with Omarchy's own keys", () => {
  const s = M.defaultState()
  assert.strictEqual(s.pads.length, 1)
  assert.strictEqual(s.pads[0].id, "scratchpad")
  assert.strictEqual(s.pads[0].key, "SUPER + S")
  assert.strictEqual(s.pads[0].direction, "bottom")
  assert.strictEqual(s.mode, "connected")
})

t("default state changes nothing: no Hub key, no command", () => {
  const cfg = M.luaConfig(M.defaultState(), {}, { pads: {}, fullscreen: "" })
  assert.deepStrictEqual(cfg.pads, [])
  assert.deepStrictEqual(cfg.commands, [])
})

t("garbage input becomes a valid state", () => {
  for (const bad of [null, 5, "x", [], { pads: "no" }, { pads: [null, 7, { id: "!!", label: "" }] }]) {
    const s = M.cleanState(bad)
    assert.strictEqual(s.pads[0].id, "scratchpad")
    assert.ok(s.pads.every(p => M.DIRECTIONS.includes(p.direction)))
  }
})

t("builtin pad cannot be lost or duplicated, ids stay unique", () => {
  const s = M.cleanState({ pads: [{ id: "a", label: "A" }, { id: "a", label: "B" }, { id: "scratchpad", label: "Mine" }] })
  assert.deepStrictEqual(s.pads.map(p => p.id), ["scratchpad", "a"])
  assert.strictEqual(s.pads[0].label, "Mine")
})

t("slug is unique and safe", () => {
  assert.strictEqual(M.slug("My Notes!", []), "my-notes")
  assert.strictEqual(M.slug("My Notes!", ["my-notes"]), "my-notes-2")
  assert.strictEqual(M.slug("***", []), "pad")
})

t("key normalising", () => {
  assert.strictEqual(M.normalizeKey("super+shift+f9"), "SUPER + SHIFT + F9")
  assert.strictEqual(M.normalizeKey("shift + super + s"), "SUPER + SHIFT + S")
  assert.strictEqual(M.normalizeKey("win + alt + s"), "SUPER + ALT + S")
  for (const bad of ["", "super +", "a b", "super + a + b", null, undefined, "super + $(rm)"]) assert.strictEqual(M.normalizeKey(bad), "")
})

t("keys from Qt events", () => {
  assert.strictEqual(M.keyFromEvent(0x01000038, false, false, false, true), "SUPER + F9")
  assert.strictEqual(M.keyFromEvent(0x53, false, true, true, true), "SUPER + ALT + SHIFT + S")
  assert.strictEqual(M.keyFromEvent(0x01000022, false, false, false, true), "")
  assert.strictEqual(M.keyFromEvent(0x01000000, false, false, false, false), "ESCAPE")
})

t("a bare letter is not a usable key", () => {
  assert.ok(!M.keyUsable("S"))
  assert.ok(M.keyUsable("F9"))
  assert.ok(M.keyUsable("SUPER + S"))
})

t("conflicts are found against hyprctl binds, own binds ignored", () => {
  const binds = [
    { modmask: 64, key: "S", description: "Toggle scratchpad" },
    { modmask: 65, key: "F9", description: "AktOn1 Hub: toggle X" },
    { modmask: 64, key: "d", description: "", dispatcher: "exec", arg: "foo" }
  ]
  assert.strictEqual(M.findConflict("SUPER + S", binds), "Toggle scratchpad")
  assert.strictEqual(M.findConflict("SUPER + SHIFT + F9", binds), "")
  assert.strictEqual(M.findConflict("SUPER + D", binds), "exec foo")
  assert.strictEqual(M.findConflict("SUPER + ALT + S", binds), "")
})

const luaText = `
-- o.bind("SUPER + D", "x", "omarchy-shell fullscreen-app-auto-workspace toggle")
o.bind("SUPER + F", "Toggle fullscreen app workspace", "omarchy-shell fullscreen-app-auto-workspace toggle")
hl.bind("SUPER + N", hl.dsp.workspace.toggle_special("notes"), { description = "Notes" })
o.bind("ALT + G", "Claude", { launch = "claude" })
`
t("hand-written bindings are detected, comments are not", () => {
  const d = M.detectBindings(luaText)
  assert.strictEqual(d.fullscreen, "SUPER + F")
  assert.deepStrictEqual(d.pads, { notes: "SUPER + N" })
  assert.deepStrictEqual(M.detectBindings("").pads, {})
})

t("a detected user binding is kept: the Hub does not register that pad", () => {
  const s = M.cleanState({ pads: [{ id: "notes", label: "Notes", key: "SUPER + N", keepMine: true }] })
  const d = M.detectBindings(luaText)
  assert.deepStrictEqual(M.luaConfig(s, {}, d).pads, [])
  s.pads[1].keepMine = false
  assert.strictEqual(M.luaConfig(s, {}, d).pads.length, 1)
})

t("the same fullscreen key as the user's own binding is not registered twice", () => {
  const s = M.cleanState({ fullscreenKey: "SUPER + F" })
  assert.deepStrictEqual(M.luaConfig(s, {}, M.detectBindings(luaText)).commands, [])
  const s2 = M.cleanState({ fullscreenKey: "SUPER + G" })
  assert.strictEqual(M.luaConfig(s2, {}, M.detectBindings(luaText)).commands.length, 1)
})

t("the builtin pad takes over SUPER + S only when its direction changes", () => {
  const s = M.cleanState({ pads: [{ id: "scratchpad", direction: "top" }] })
  const pads = M.luaConfig(s, {}, { pads: {}, fullscreen: "" }).pads
  assert.strictEqual(pads.length, 1)
  assert.strictEqual(pads[0].builtin, true)
  assert.strictEqual(pads[0].direction, "top")
})

t("the builtin pad on another key does not unbind SUPER + S", () => {
  const s = M.cleanState({ pads: [{ id: "scratchpad", key: "SUPER + F9" }] })
  const pads = M.luaConfig(s, {}, { pads: {}, fullscreen: "" }).pads
  assert.strictEqual(pads[0].builtin, false)
})

t("lua serialising escapes quotes and newlines", () => {
  assert.strictEqual(M.luaValue('a"b\\c\nd'), '"a\\"b\\\\c\\nd"')
  assert.strictEqual(M.luaValue({ a: [1, true, "x"] }), '{["a"]={1,true,"x"}}')
})

t("animation originals follow specialWorkspace > workspaces > global", () => {
  const recs = [[
    { name: "specialWorkspace", overridden: true, bezier: "easeOutQuint", enabled: true, speed: 3, style: "slidevert" },
    { name: "specialWorkspaceIn", overridden: false, bezier: "", enabled: true, speed: 0, style: "" },
    { name: "global", overridden: true, bezier: "default", enabled: true, speed: 10, style: "" }
  ], []]
  const a = M.animSpec(recs)
  assert.deepStrictEqual(a.specialWorkspaceIn, { enabled: true, speed: 3, bezier: "easeOutQuint", style: "slidevert" })
  assert.deepStrictEqual(a.specialWorkspaceOut, { enabled: true, speed: 3, bezier: "easeOutQuint", style: "slidevert" })
})

t("plugin status and views", () => {
  const none = M.pluginStatus("[]")
  assert.deepStrictEqual(M.views(none).map(v => v.id), ["scratchpads"])
  assert.strictEqual(M.missing(none).length, 2)
  const both = M.pluginStatus([{ id: "io.github.akton1.fullscreen-app-auto-workspace", enabled: true }, { id: "other", enabled: true }])
  assert.deepStrictEqual(M.views(both).map(v => v.id), ["scratchpads", "fullscreen"])
  assert.strictEqual(M.missing(both).length, 1)
  const off = M.pluginStatus([{ id: "io.github.akton1.fullscreen-app-auto-workspace", enabled: false }])
  assert.deepStrictEqual(M.views(off).map(v => v.id), ["scratchpads"])
  assert.strictEqual(M.missing(off).length, 2)
  assert.deepStrictEqual(M.pluginStatus("not json")["io.github.akton1.scratchpad-frame"], { installed: false, enabled: false })
})

t("tooltips name the mode", () => {
  assert.ok(M.tooltip("connected", "", ["Scratchpads"]).startsWith("AktOn1 plugins: connected"))
  assert.ok(M.tooltip("separated", "Scratchpads", []).includes("disconnected"))
})

t("install command is the plain omarchy plugin add", () => {
  assert.strictEqual(M.installCommand(M.CATALOG[0]), "omarchy plugin add https://github.com/AktOn1/omarchy-scratchpad-frame.git --enable")
})

t("the Fullscreen layer exists from the start with no apps and the default layout", () => {
  const s = M.defaultState()
  assert.deepStrictEqual(s.fullscreen, { id: "fullscreen", label: "Fullscreen", layer: true, layout: "", apps: [] })
  assert.strictEqual(M.effectiveMagnet(s), "fullscreen")
  assert.strictEqual(M.effectiveMagnet(M.cleanState({ pads: [{ id: "n", label: "N" }], magnet: "n" })), "n")
  assert.strictEqual(M.fullscreenKeepOthers(s), false)
})

t("an old state file without the Fullscreen layer or layouts still loads", () => {
  const s = M.cleanState({ version: 1, pads: [{ id: "scratchpad" }, { id: "game", label: "Music", apps: ["cliamp"] }] })
  assert.strictEqual(s.fullscreen.label, "Fullscreen")
  assert.strictEqual(s.pads[1].layout, "")
  assert.deepStrictEqual(s.pads[1].apps, ["cliamp"])
})

t("the Fullscreen layer keeps its own apps and layout, and apps make it keep non-game windows", () => {
  const s = M.cleanState({ fullscreen: { label: "Games", layer: false, layout: "master", apps: ["steam", "  ", "discord"] } })
  assert.strictEqual(s.fullscreen.label, "Games")
  assert.strictEqual(s.fullscreen.layer, true)
  assert.strictEqual(s.fullscreen.layout, "master")
  assert.deepStrictEqual(s.fullscreen.apps, ["steam", "discord"])
  assert.strictEqual(M.fullscreenKeepOthers(s), true)
})

t("no scratchpad can take the id fullscreen", () => {
  const s = M.cleanState({ pads: [{ id: "fullscreen", label: "Fullscreen" }] })
  assert.ok(s.pads.every(p => p.id !== "fullscreen"))
  assert.strictEqual(M.slug("Fullscreen", []), "fullscreen-2")
  assert.strictEqual(M.findLayer(s, "fullscreen").layer, true)
})

t("layout names: stock and Lua layouts pass, junk becomes default", () => {
  for (const ok of ["dwindle", "master", "scrolling", "monocle", "lua:fractal"]) assert.strictEqual(M.cleanLayout(ok), ok)
  for (const bad of ["", "Dwindle!", "a b", "$(rm)", 5, null, "lua:"]) assert.strictEqual(M.cleanLayout(bad), "")
  const opts = M.layoutOptions(["lua:mine", "master", ""])
  assert.deepStrictEqual(opts.map(o => o.value), ["", "dwindle", "master", "scrolling", "monocle", "lua:mine"])
})

t("every layer, Fullscreen included, hands its layout to the Lua runtime", () => {
  const s = M.cleanState({ pads: [{ id: "n", label: "N", layout: "master" }], fullscreen: { layout: "monocle" } })
  const cfg = M.luaConfig(s, {}, { pads: {}, fullscreen: "" })
  assert.deepStrictEqual(cfg.layouts, [{ id: "scratchpad", layout: "" }, { id: "n", layout: "master" }, { id: "fullscreen", layout: "monocle" }])
})

console.log(n + " passed")

const ENTRIES = [
  { id: "cliamp", name: "cliamp", generic: "Music Player", comment: "", keywords: "music audio winamp", terminal: true, hidden: false, command: ["cliamp"] },
  { id: "org.kde.kate", name: "Kate", generic: "Text Editor", comment: "", keywords: "editor", terminal: false, hidden: false, command: ["kate"] },
  { id: "kitty", name: "kitty", generic: "Terminal", comment: "", keywords: "", terminal: false, hidden: false, command: ["kitty"] },
  { id: "hidden", name: "Hidden", generic: "", comment: "", keywords: "", terminal: false, hidden: true, command: ["hidden"] }
]

t("picked apps start through gtk-launch so terminal apps get a terminal", () => {
  assert.strictEqual(M.startupCommand("app:cliamp"), "uwsm-app -- gtk-launch 'cliamp.desktop'")
  assert.strictEqual(M.startupCommand("app:it's"), "uwsm-app -- gtk-launch 'it'\\''s.desktop'")
  assert.strictEqual(M.startupCommand("kitty -e htop"), "uwsm-app -- kitty -e htop")
})

t("a bare command that is a terminal app is resolved to its desktop entry", () => {
  assert.strictEqual(M.resolveApp("cliamp", ENTRIES), "app:cliamp")
  assert.strictEqual(M.resolveApp("/usr/bin/cliamp", ENTRIES), "app:cliamp")
  assert.strictEqual(M.resolveApp("kitty", ENTRIES), "kitty")
  assert.strictEqual(M.resolveApp("cliamp --x", ENTRIES), "cliamp --x")
})

t("app search finds by name, kind, id or keyword and skips hidden entries", () => {
  assert.deepStrictEqual(M.matchApps(ENTRIES, "clia").map(a => a.app), ["app:cliamp"])
  assert.deepStrictEqual(M.matchApps(ENTRIES, "music player").map(a => a.app), ["app:cliamp"])
  assert.deepStrictEqual(M.matchApps(ENTRIES, "winamp").map(a => a.app), ["app:cliamp"])
  assert.deepStrictEqual(M.matchApps(ENTRIES, "kde").map(a => a.app), ["app:org.kde.kate"])
  assert.deepStrictEqual(M.matchApps(ENTRIES, "hidden"), [])
  assert.deepStrictEqual(M.matchApps(ENTRIES, "  "), [])
  assert.strictEqual(M.matchApps(ENTRIES, "cliamp")[0].terminal, true)
})

t("the app picker lists visible apps by name, with the id in the description", () => {
  const o = M.appOptions(ENTRIES)
  assert.deepStrictEqual(o.map(x => x.value), ["app:cliamp", "app:org.kde.kate", "app:kitty"])
  assert.ok(o[0].description.indexOf("terminal app") >= 0)
})

t("titles: picked apps show their name, missing ones say so, commands stay as typed", () => {
  assert.strictEqual(M.appTitle("app:cliamp", ENTRIES), "cliamp (terminal)")
  assert.strictEqual(M.appTitle("app:gone", ENTRIES), "gone (not installed)")
  assert.strictEqual(M.appTitle("kitty -e htop", ENTRIES), "kitty -e htop")
})
