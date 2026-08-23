-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1.25

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Configure a specific monitor.
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- External monitor (LED) at its maximum 2K resolution (2560x1440), left of the laptop.
hl.monitor({ output = "DP-2", mode = "2560x1440@60", position = "-2560x0", scale = 1 })

-- Laptop display (right of the external monitor).
hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })

-- Pin workspaces 1-5 to the external monitor, 6-10 to the laptop.
for i = 1, 5 do
  hl.workspace_rule({ workspace = tostring(i), monitor = "DP-2" })
end
for i = 6, 10 do
  hl.workspace_rule({ workspace = tostring(i), monitor = "eDP-1", persistent = true })
end
