-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- SUPER SHIFT ALT + A was bound to Grok by default; override with Gemini.
hl.unbind("SUPER + SHIFT + ALT + A")
o.bind("SUPER + SHIFT + ALT + A", "Gemini", { webapp = "https://gemini.google.com" })

-- Dictation keys from before Alt + Space and Right Alt became the defaults.
-- Remove these lines to give the keys back to applications.
if o.dictation_installed and o.dictation_installed() then
  o.bind("SUPER + CTRL + X", "Toggle dictation", "omarchy-dictation toggle")
  o.bind_hold("F9", "Start dictation (push-to-talk)", "omarchy-dictation start", "Stop dictation (push-to-talk)", "omarchy-dictation stop")
end

-- Fixed monitor split for workspace keys:
--   SUPER + 1-5 -> LED (DP-2) workspaces 1-5
--   SUPER + 6-0 -> laptop (eDP-1) workspaces 1-5
-- The laptop key numbers start at 6, but its workspace numbers start at 1:
-- 6 -> 1, 7 -> 2, 8 -> 3, 9 -> 4, 0 -> 5.
-- Omarchy 4.5 gives every monitor its own 1-10. These binds keep the old
-- global-key feel while leaving the per-monitor engine in charge.
local function workspace_key(number)
  return "code:" .. tostring(number + 9)
end

local function switch_to(slot, monitor_name)
  return function()
    if hl.get_monitor(monitor_name) then
      o.workspaces.focus(slot, monitor_name)()
    else
      o.workspaces.focus(slot)()
    end
  end
end

local function move_window_to(slot, monitor_name, follow)
  return function()
    local window = hl.get_active_window()
    local origin = hl.get_active_workspace()
    local origin_monitor = hl.get_active_monitor()
    local monitor = hl.get_monitor(monitor_name) or origin_monitor
    if not window or not monitor then
      return
    end

    local address = window.address
    local origin_id = origin and origin.id
    local origin_monitor_name = origin_monitor and origin_monitor.name

    -- Focus the target slot first so an empty workspace is created on the
    -- right monitor before the window moves there.
    o.workspaces.focus(slot, monitor.name)()

    hl.dispatch(hl.dsp.window.move({
      window = "address:" .. address,
      workspace = tostring(o.workspaces.workspace_id(monitor, slot)),
      follow = follow,
    }))

    -- Silent moves keep focus where it was. Focus the origin monitor first so
    -- a workspace that emptied out is recreated there, not on the target.
    if not follow and origin_id and origin_id > 0 and origin_monitor_name then
      hl.dispatch(hl.dsp.focus({ monitor = origin_monitor_name }))
      hl.dispatch(hl.dsp.focus({ workspace = tostring(origin_id) }))
    end
  end
end

for slot = 1, 5 do
  local key = workspace_key(slot)
  o.rebind("SUPER + " .. key, "Switch to LED workspace " .. slot, switch_to(slot, "DP-2"))
  o.rebind("SUPER + SHIFT + " .. key, "Move window to LED workspace " .. slot, move_window_to(slot, "DP-2", true))
  o.rebind("SUPER + SHIFT + ALT + " .. key, "Move window silently to LED workspace " .. slot, move_window_to(slot, "DP-2", false))
end

for key_number = 6, 10 do
  local slot = key_number - 5
  local key = workspace_key(key_number)
  o.rebind("SUPER + " .. key, "Switch to laptop workspace " .. slot, switch_to(slot, "eDP-1"))
  o.rebind("SUPER + SHIFT + " .. key, "Move window to laptop workspace " .. slot, move_window_to(slot, "eDP-1", true))
  o.rebind("SUPER + SHIFT + ALT + " .. key, "Move window silently to laptop workspace " .. slot, move_window_to(slot, "eDP-1", false))
end
