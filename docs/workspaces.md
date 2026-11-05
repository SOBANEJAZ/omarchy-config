# Workspace layout

How the dual-monitor workspace keys work, why the old pinning rules are gone, and how to debug them after an Omarchy update.

## Current key map

| Keys | Monitor | Workspace slot | Hyprland ID |
|---|---|---|---|
| `Super+1` | LED (`DP-2`) | 1 | 11 |
| `Super+2` | LED (`DP-2`) | 2 | 12 |
| `Super+3` | LED (`DP-2`) | 3 | 13 |
| `Super+4` | LED (`DP-2`) | 4 | 14 |
| `Super+5` | LED (`DP-2`) | 5 | 15 |
| `Super+6` | laptop (`eDP-1`) | 1 | 1 |
| `Super+7` | laptop (`eDP-1`) | 2 | 2 |
| `Super+8` | laptop (`eDP-1`) | 3 | 3 |
| `Super+9` | laptop (`eDP-1`) | 4 | 4 |
| `Super+0` | laptop (`eDP-1`) | 5 | 5 |

- `Super+Shift+<n>` moves the active window to the same workspace and follows it.
- `Super+Shift+Alt+<n>` moves the window silently and leaves focus where it was.
- `Ctrl+Alt+Tab` and `Shift+Ctrl+Alt+Tab` focus the next and previous monitor.
- The mapping lives in `hypr/bindings.lua`.

## Why Omarchy 4.5 changed the behavior

Omarchy 4.5 introduced per-monitor workspaces in `default/hypr/monitor-workspaces.lua`. Each physical monitor owns a block of ten Hyprland workspace IDs. The bar labels each block as `1-10`.

On this machine the state file `~/.local/state/omarchy/monitor-workspaces` assigns:

```
0	eDP-1	BOE 0x07BC
1	DP-2	Lenovo Group Limited P27h-20 V90B5249
```

So:

- Laptop `eDP-1` owns IDs 1-10, displayed as 1-0.
- LED `DP-2` owns IDs 11-20, displayed as 1-0.

The old `hypr/monitors.lua` pinned workspaces 1-5 to `DP-2` and 6-10 to `eDP-1`. Those rules fought the new engine. Empty pinned workspaces moved home, keyboard shortcuts targeted the wrong monitor, and the LED bar showed only the first five slots. Removing the rules fixed placement but made `Super+6` select the LED's sixth slot instead of the laptop's workspace 6.

## What this config does instead

It keeps Omarchy's per-monitor engine and changes only the keys:

- The LED uses its own slots 1-5.
- The laptop uses its own slots 1-5, reached with keys 6-0.
- The laptop's keys are offset by five: key 6 selects slot 1, key 0 selects slot 5.
- Both monitors still have hidden slots 6-10. Number keys never target them, but `Super+Tab`, mouse scroll, and bar clicks can reach them.

The LED fallback is deliberate. If `DP-2` is unplugged, `Super+1-5` switch slots on the focused monitor instead of doing nothing.

## Implementation notes

`hypr/bindings.lua` uses Omarchy's public workspace API:

- `o.workspaces.focus(slot, monitor_name)` focuses a slot on a named monitor.
- `o.workspaces.workspace_id(monitor, slot)` resolves the Hyprland ID for that slot.
- `hl.dsp.window.move({ window = "address:...", workspace = id, follow = ... })` moves a window by address.

`hypr/monitors.lua` now contains monitor placement only. Do not add `hl.workspace_rule({ monitor = ... })` lines back; they conflict with per-monitor workspaces.

`install.sh` restores `hypr/bindings.lua` alongside the other Hyprland files.

## Validate after a change

```bash
hyprctl reload
hyprctl configerrors
omarchy menu keybindings --print | grep -E "LED workspace|laptop workspace"
hyprctl monitors | grep -E "Monitor|active workspace|focused"
hyprctl workspaces
cat ~/.local/state/omarchy/monitor-workspaces
```

Expected:

- `hyprctl configerrors` prints nothing.
- The keybindings menu shows `Switch to laptop workspace 1` through `5` on keys 6-0.
- The LED active workspace stays in IDs 11-15 when using keys 1-5.
- The laptop active workspace stays in IDs 1-5 when using keys 6-0.
- `Ctrl+Alt+Tab` changes the focused monitor without changing the workspace mapping.

## Troubleshooting

**`Super+6` stays on the LED.**
The rebinds did not load. Run `hyprctl reload`, then `hyprctl configerrors`. Check `omarchy menu keybindings --print` for the `LED workspace` and `laptop workspace` descriptions.

**LED bar shows only 1-5, laptop bar shows more.**
Expected. Both bars always show their first five slots. Slots 6-10 appear only when a workspace still uses them. Number keys do not target those extra slots.

**Keys focus the wrong workspace after an Omarchy update.**
Check whether `o.workspaces.focus` or `o.workspaces.workspace_id` changed. Run:

```bash
cat /usr/share/omarchy/default/hypr/monitor-workspaces.lua
```

Adjust `hypr/bindings.lua` if the API changed.

**Monitor blocks changed.**
The state file keeps blocks per physical monitor, not per connector. Inspect it with `cat ~/.local/state/omarchy/monitor-workspaces`. The documents above assume the laptop keeps block 0 and the LED keeps block 1.

**Old pinning rules reappear.**
Remove any `hl.workspace_rule({ workspace = ..., monitor = ... })` entries from `hypr/monitors.lua` and reload.

## History

- `b75d796` removed the 1-5/6-10 pinning rules that conflicted with Omarchy 4.5.
- `3b64835` added the fixed monitor key mapping.
- `4aa2e8c` offset the laptop keys so `Super+6` selects laptop workspace 1.

## Rollback

Restore the live backups:

```bash
ls ~/.config/hypr/bindings.lua.bak.*
```

Or revert the commits above and copy `hypr/bindings.lua` back with `install.sh`. Removing the workspace key block restores Omarchy's focused-monitor behavior: `Super+N` selects slot N on whichever monitor has focus.
