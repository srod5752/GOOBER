-- GOOBER foundation boot screen. Later phases add networking and applications.
package.path = "/goober/app/?.lua;/goober/app/?/init.lua;" .. package.path

local configModule = require("core.config")
local capabilities = require("core.capabilities")
local config, configNotice = configModule.load()
local detected = capabilities.detect()

local function color(name, fallback)
  return colors[name] or fallback
end

local function writeLine(y, text, valueColor)
  if y > detected.terminal.height then return end
  local width = detected.terminal.width
  if width < 1 then return end
  text = tostring(text):sub(1, width)
  term.setCursorPos(1, y)
  term.setTextColor(valueColor or colors.white)
  term.write(text)
end

term.setBackgroundColor(colors.black)
term.clear()
local compact = detected.terminal.width < 28 or detected.terminal.height < 10
local rows
if compact then
  rows = {
    { "GOOBER OS 0.1.0", color("cyan", colors.white) },
    { config.device.name .. " / " .. config.device.role, colors.white },
    { string.format("Screen %dx%d", detected.terminal.width, detected.terminal.height), colors.lightGray },
    { "Local foundation ready", colors.yellow },
    { "Network services pending", colors.gray }
  }
else
  rows = {
    { "GOOBER OS  |  FOUNDATION 0.1.0", color("cyan", colors.white) },
    { "General Operations & Onboard Base Environment Response", colors.gray },
    { "", colors.white },
    { "LOCAL DEVICE", colors.lightGray },
    { "Name: " .. config.device.name, colors.white },
    { "Role: " .. config.device.role, colors.white },
    { "Computer ID: " .. tostring(config.device.id), colors.white },
    { "", colors.white },
    { "DETECTED CAPABILITIES", colors.lightGray },
    { string.format("Display: %dx%d %s", detected.terminal.width, detected.terminal.height, detected.terminal.color and "color" or "monochrome"), colors.white },
    { string.format("Monitor / speaker / modem: %d / %d / %d", detected.peripherals.monitors, detected.peripherals.speakers, detected.peripherals.modems), colors.white },
    { string.format("HTTP / Rednet / DFPWM: %s / %s / %s", tostring(detected.apis.http), tostring(detected.apis.rednet), tostring(detected.apis.dfpwm)), colors.white },
    { "", colors.white },
    { "Foundation installed. Shared network services are added in Step 2.", colors.yellow },
    { configNotice and ("Config: " .. tostring(configNotice)) or "", colors.lightGray },
    { "Shared facility actions are not available yet.", colors.gray }
  }
end

for index, row in ipairs(rows) do writeLine(index, row[1], row[2]) end
