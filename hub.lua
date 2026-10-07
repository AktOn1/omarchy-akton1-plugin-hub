-- AktOn1 Plugin Hub: scratchpad runtime inside Hyprland.
-- Loaded by the Hub service through `hyprctl eval`. Only raw Hyprland Lua (hl.*),
-- no network, no os.execute / io.popen. Everything it registers is tracked so
-- M.stop() puts the desktop back (the Omarchy SUPER + S binding included).
--
-- M.start(cfg): cfg.pads  = { { id, key, moveKey, direction, label, builtin } ... }
--               cfg.commands = { { key, command, label } ... }  (plain shell commands on a key)
--               cfg.anim  = { specialWorkspaceIn = {enabled, speed, bezier, style}, specialWorkspaceOut = ... }
-- M.launch(id, command): start a command on special:<id> without showing it

local previous = rawget(_G, "__akton1_hub")
if previous and previous.stop then
  pcall(previous.stop)
end

local M = {}
local binds, restores = {}, {}
local anim = nil
local restore_id = 0

local function set_leaf(leaf, spec, style)
  pcall(hl.animation, {
    leaf = leaf,
    enabled = spec.enabled ~= false,
    speed = tonumber(spec.speed) or 3,
    bezier = spec.bezier or "default",
    style = style or spec.style or "",
  })
end

-- Hyprland's special workspace slide is one setting for all special workspaces,
-- so a pad sets its own direction just before it moves and the original comes back after.
local function with_direction(direction, fn)
  if not anim then
    fn()
    return
  end
  local longest = 0
  for leaf, spec in pairs(anim) do
    set_leaf(leaf, spec, "slide " .. direction)
    longest = math.max(longest, (tonumber(spec.speed) or 3) * 100)
  end
  fn()
  restore_id = restore_id + 1
  local id = restore_id
  hl.timer(function()
    if id == restore_id and anim then
      for leaf, spec in pairs(anim) do
        set_leaf(leaf, spec)
      end
    end
  end, { timeout = math.floor(math.min(longest, 5000)) + 200, type = "oneshot" })
end

local function add_bind(keys, dispatcher, description)
  local ok, bind = pcall(hl.bind, keys, dispatcher, { description = description })
  if ok and bind then
    binds[#binds + 1] = bind
  end
end

function M.toggle(id, direction)
  with_direction(direction or "bottom", function()
    hl.dispatch(hl.dsp.workspace.toggle_special(id))
  end)
end

function M.start(cfg)
  M.stop()
  anim = cfg.anim
  for _, item in ipairs(cfg.commands or {}) do
    if item.key and item.key ~= "" and item.command and item.command ~= "" then
      add_bind(item.key, hl.dsp.exec_cmd(item.command), "AktOn1 Hub: " .. (item.label or item.command))
    end
  end
  for _, pad in ipairs(cfg.pads or {}) do
    local id, direction = pad.id, pad.direction or "bottom"
    if pad.key and pad.key ~= "" then
      if pad.builtin then
        -- Take over Omarchy's own SUPER + S so the scratchpad can slide from another side.
        pcall(hl.unbind, pad.key)
        restores[#restores + 1] = function()
          pcall(hl.bind, pad.key, hl.dsp.workspace.toggle_special(id), { description = "Toggle scratchpad" })
        end
      end
      add_bind(pad.key, function() M.toggle(id, direction) end, "AktOn1 Hub: toggle " .. (pad.label or id))
    end
    if pad.moveKey and pad.moveKey ~= "" and not pad.builtin then
      add_bind(pad.moveKey, hl.dsp.window.move({ workspace = "special:" .. id, follow = false }),
        "AktOn1 Hub: move window to " .. (pad.label or id))
    end
  end
end

function M.launch(id, command)
  hl.exec_cmd(command, { workspace = "special:" .. id .. " silent" })
end

function M.stop()
  restore_id = restore_id + 1
  if anim then
    for leaf, spec in pairs(anim) do
      set_leaf(leaf, spec)
    end
  end
  anim = nil
  for _, bind in ipairs(binds) do
    pcall(function() bind:remove() end)
  end
  for _, restore in ipairs(restores) do
    pcall(restore)
  end
  binds, restores = {}, {}
end

_G.__akton1_hub = M
return M
