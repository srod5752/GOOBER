-- Runtime feature detection. Optional peripherals do not prevent startup.
local M = {}

local function countType(wanted)
  local count = 0
  for _, name in ipairs(peripheral.getNames()) do
    local ok, kind = pcall(peripheral.getType, name)
    if ok then
      if type(kind) == "table" then
        for _, item in ipairs(kind) do
          if item == wanted then count = count + 1; break end
        end
      elseif kind == wanted then
        count = count + 1
      end
    end
  end
  return count
end

function M.detect()
  local width, height = term.getSize()
  local color = false
  if term.isColor then
    local ok, result = pcall(term.isColor)
    color = ok and result or false
  end
  return {
    computer_id = os.getComputerID(),
    computer_label = os.getComputerLabel(),
    terminal = { width = width, height = height, color = color },
    peripherals = {
      monitors = countType("monitor"),
      speakers = countType("speaker"),
      modems = countType("modem")
    },
    apis = {
      http = type(http) == "table",
      rednet = type(rednet) == "table",
      dfpwm = pcall(require, "cc.audio.dfpwm")
    }
  }
end

return M
