-- Select a responsive terminal, preferring the largest attached monitor.
local M = {}

local function hasType(value, wanted)
  if type(value) == "table" then
    for _, kind in ipairs(value) do if kind == wanted then return true end end
    return false
  end
  return value == wanted
end

function M.select(config)
  if term.native then pcall(term.redirect, term.native()) end
  local best, bestName, bestArea
  for _, name in ipairs(peripheral.getNames()) do
    local okType, kinds = pcall(peripheral.getType, name)
    if okType and hasType(kinds, "monitor") then
      local ok, monitor = pcall(peripheral.wrap, name)
      if ok and monitor then
        if monitor.setTextScale then pcall(monitor.setTextScale, config.display.monitor_scale or 1) end
        local sizeOk, width, height = pcall(monitor.getSize)
        local area = sizeOk and width * height or 0
        if area > (bestArea or 0) then best, bestName, bestArea = monitor, name, area end
      end
    end
  end
  if best then pcall(term.redirect, best) end
  local width, height = term.getSize()
  return {
    width = width,
    height = height,
    monitor = best ~= nil,
    monitor_name = bestName,
    color = term.isColor and term.isColor() or false
  }
end

return M
