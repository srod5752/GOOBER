-- Small, clipped drawing helpers shared by GOOBER screens.
local M = {}

M.colors = {
  background = colors.black,
  panel = colors.gray,
  panel_dark = colors.gray,
  border = colors.cyan,
  accent = colors.cyan,
  text = colors.white,
  muted = colors.lightGray,
  good = colors.green,
  warn = colors.yellow,
  bad = colors.red
}

local function put(x, y, text, fg, bg, width)
  local screenWidth, screenHeight = term.getSize()
  if y < 1 or y > screenHeight or x > screenWidth then return end
  text = tostring(text or "")
  local max = math.min(width or (screenWidth - x + 1), screenWidth - x + 1)
  if max <= 0 then return end
  term.setCursorPos(x, y)
  term.setTextColor(fg or M.colors.text)
  term.setBackgroundColor(bg or M.colors.background)
  term.write(text:sub(1, max))
end

function M.clear()
  term.setBackgroundColor(M.colors.background)
  term.setTextColor(M.colors.text)
  term.setCursorBlink(false)
  term.clear()
end

function M.text(x, y, value, color, width)
  put(x, y, value, color, M.colors.background, width)
end

function M.fill(x, y, width, height, bg)
  local screenWidth, screenHeight = term.getSize()
  width = math.max(0, math.min(width, screenWidth - x + 1))
  local row = string.rep(" ", width)
  for line = y, math.min(y + height - 1, screenHeight) do put(x, line, row, M.colors.text, bg, width) end
end

function M.panel(x, y, width, height, title)
  if width < 1 or height < 1 then return end
  M.fill(x, y, width, height, M.colors.panel_dark)
  M.fill(x, y, math.min(2, width), height, M.colors.accent)
  if title and #title > 0 and width > 4 then
    M.fill(x + 2, y, width - 2, 1, colors.blue)
    put(x + 3, y, title:upper(), colors.white, colors.blue, width - 4)
  end
end

function M.button(buttons, x, y, width, label, action, enabled, selected)
  if width < 1 then return end
  local bg = enabled == false and colors.gray or selected and colors.cyan or colors.blue
  local fg = enabled == false and colors.lightGray or selected and colors.black or colors.white
  M.fill(x, y, width, 1, bg)
  local text = tostring(label)
  local labelX = x + math.max(0, math.floor((width - #text) / 2))
  put(labelX, y, text, fg, bg, width - (labelX - x))
  table.insert(buttons, { x = x, y = y, width = width, height = 1, action = action, enabled = enabled ~= false })
end

function M.centered(y, value, color)
  local width = term.getSize()
  value = tostring(value or "")
  local x = math.max(1, math.floor((width - #value) / 2) + 1)
  put(x, y, value, color, M.colors.background, width - x + 1)
end

function M.write(x, y, value, fg, bg, width)
  put(x, y, value, fg, bg, width)
end

return M
