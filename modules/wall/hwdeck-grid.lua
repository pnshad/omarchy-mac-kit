-- hwdeck views (opened from the Touch Bar strip or the screensaver) float in a fixed 3 x 2 grid so
-- all six fit the screen at once: cpu | thermal | network over memory | power | battery.
-- 8 px gaps, below Omarchy's 26 px bar. Expressions on monitor_w/h: any resolution.
do
  local col = "((monitor_w-32)/3)"
  local half = "((monitor_h-26-24)/2)"
  local x = { "(8)", "(16+" .. col .. ")", "(24+2*" .. col .. ")" }
  local y = { "(34)", "(42+" .. half .. ")" }
  local hwdeck_grid = {
    cpu = { 1, 1 }, thermal = { 2, 1 }, network = { 3, 1 },
    memory = { 1, 2 }, power = { 2, 2 }, battery = { 3, 2 },
  }
  for view, g in pairs(hwdeck_grid) do
    o.window("org.omk.hwdeck-" .. view, { float = true, size = { col, half }, move = { x[g[1]], y[g[2]] } })
  end
end
