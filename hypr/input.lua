-- Keep only your personal input overrides here. Uncommented settings below
-- replace Omarchy's defaults.

-- Keyboard layout and options.
-- See https://wiki.hypr.land/Configuring/Basics/Variables/#input
hl.config({
  input = {
    kb_layout = "us",
    kb_variant = "",
    kb_model = "",
    kb_options = "",
    kb_rules = "",

    -- Change speed of keyboard repeat.
    repeat_rate = 40,
    repeat_delay = 600,

    -- Start with numlock on by default.
    numlock_by_default = true,

    -- Increase sensitivity for mouse/trackpad (default: 0).
    sensitivity = 1.7,

    -- Turn off mouse acceleration (default: adaptive).
    accel_profile = "flat",

    touchpad = {
      -- Use natural (inverse) scrolling.
      natural_scroll = true,

      -- Use two-finger clicks for right-click instead of lower-right corner.
      clickfinger_behavior = true,

      -- Control the speed of your scrolling.
      scroll_factor = 0.5,

      -- Keep dragging when a touchpad click is released and pressed quickly.
      drag_lock = true,
    },
  },
})

-- App-specific touchpad scroll speeds.
-- o.window("(Alacritty|kitty|foot)", { scroll_touchpad = 1.5 })
-- o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })

-- Enable touchpad gestures for changing workspaces.
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Enable touchpad gestures for moving focus (helpful on scrolling layout).
-- hl.gesture({ fingers = 3, direction = "left", action = function() hl.dispatch(hl.dsp.focus({ direction = "l" })) end })
-- hl.gesture({ fingers = 3, direction = "right", action = function() hl.dispatch(hl.dsp.focus({ direction = "r" })) end })
