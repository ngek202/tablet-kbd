-- Tablet mode base config — finger touch only (pen deferred).
-- Pins finger touch to eDP-1 and guarantees a clean boot (no lockout).

-- Boot safety: wipe tablet/touch off-states on fresh login.
-- Marker lives in tmpfs (/run/user) so it vanishes on reboot.
do
  local uid = tostring(tonumber(os.getenv("UID") or "1000") or 1000)
  -- Fallback: resolve via id if UID env is unset.
  if os.getenv("UID") == nil then
    local f = io.popen("id -u 2>/dev/null")
    if f then
      local out = f:read("*l")
      f:close()
      if out and out:match("^%d+$") then uid = out end
    end
  end
  local marker = "/run/user/" .. uid .. "/omarchy-tablet-booted"
  local m = io.open(marker, "r")
  if not m then
    os.remove((os.getenv("HOME") or "") .. "/.local/state/omarchy/toggles/hypr/tablet-mode-on")
    os.remove((os.getenv("HOME") or "") .. "/.local/state/omarchy/toggles/hypr/tablet-draw-on")
    os.remove((os.getenv("HOME") or "") .. "/.local/state/omarchy/toggles/hypr/touch-off")
    local w = io.open(marker, "w")
    if w then w:write("booted") w:close() end
  else
    m:close()
  end
end

-- Finger touch follows the internal display.
hl.device({
  name = "wacom-hid-5272-finger",
  output = "eDP-1",
  enabled = true,
})

-- wvkbd stays out of the way until summoned (squeekboard rule kept: fallback).
o.window({ class = "wvkbd-mobintl" }, { float = true, no_initial_focus = true })
o.window({ class = "squeekboard" }, { float = true, no_initial_focus = true })

-- Touch EXIT overlay never steals focus.
o.window({ title = "tablet-exit" }, { float = true, no_focus = true, no_initial_focus = true })

-- Custom keyboard prototype (Phase 1): never steals focus.
o.window({ title = "custom-kbd" }, { float = true, no_focus = true, no_initial_focus = true })
