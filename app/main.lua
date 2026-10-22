-- GOOBER network-status screen. Later phases add facility applications.
package.path = "/goober/app/?.lua;/goober/app/?/init.lua;" .. package.path

local configModule = require("core.config")
local capabilities = require("core.capabilities")
local NetworkService = require("net.service")
local config, configNotice = configModule.load()
local detected = capabilities.detect()
local network = NetworkService.new(config, detected)
network:start()

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
local function draw()
  local state = network:status()
  local compact = detected.terminal.width < 28 or detected.terminal.height < 10
  local statusColor = (state.state == "connected" or state.state == "controller") and colors.green or colors.yellow
  local rows
  if compact then
    rows = {
      { "GOOBER OS 0.2", color("cyan", colors.white) },
      { config.device.name .. " / " .. config.device.role, colors.white },
      { "Network: " .. state.state, statusColor },
      { state.detail, colors.lightGray },
      { "Devices: " .. tostring(#state.devices), colors.white }
    }
  else
    rows = {
      { "GOOBER OS  |  NETWORK FOUNDATION 0.2", color("cyan", colors.white) },
      { "General Operations & Onboard Base Environment Response", colors.gray },
      { "", colors.white },
      { "LOCAL DEVICE", colors.lightGray },
      { "Name: " .. config.device.name, colors.white },
      { "Role: " .. config.device.role .. " | Computer ID: " .. tostring(config.device.id), colors.white },
      { "", colors.white },
      { "NETWORK", colors.lightGray },
      { "Status: " .. state.state, statusColor },
      { "Controller ID: " .. tostring(state.controller_id or "not found"), colors.white },
      { "Modems open: " .. tostring(state.modem_count), colors.white },
      { state.detail, colors.lightGray },
      { "Devices: " .. tostring(#state.devices), colors.white },
      { "", colors.white },
      { "CONNECTED / RECENT DEVICES", colors.lightGray }
    }
    for _, device in ipairs(state.devices) do
      local deviceColor = device.status == "online" and colors.green or colors.yellow
      table.insert(rows, {
        string.format("%s | %s | ID %d | %s", device.name, device.role, device.id, device.status),
        deviceColor
      })
    end
    if configNotice then table.insert(rows, { "Config: " .. tostring(configNotice), colors.lightGray }) end
  end

  term.setBackgroundColor(colors.black)
  term.clear()
  for index, row in ipairs(rows) do writeLine(index, row[1], row[2]) end
end

local timer = os.startTimer(1)
draw()
while true do
  local event, parameter, message, messageProtocol = os.pullEvent()
  if event == "timer" and parameter == timer then
    network:step()
    draw()
    timer = os.startTimer(1)
  elseif event == "rednet_message" then
    network:onRednetMessage(parameter, message, messageProtocol)
    draw()
  elseif event == "peripheral" or event == "peripheral_detach" then
    detected = capabilities.detect()
    network.capabilities = detected
    network:start()
    draw()
  elseif event == "term_resize" or event == "monitor_resize" then
    detected = capabilities.detect()
    draw()
  end
end
