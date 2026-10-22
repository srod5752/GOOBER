-- GOOBER OS interface and network event loop.
package.path = "/goober/app/?.lua;/goober/app/?/init.lua;" .. package.path

local configModule = require("core.config")
local capabilities = require("core.capabilities")
local NetworkService = require("net.service")
local Display = require("ui.display")
local Components = require("ui.components")
local Interface = require("ui.app")

local config, configNotice = configModule.load()
local display = Display.select(config)

local function bootScreen(status, index)
  local width, height = term.getSize()
  Components.clear()
  Components.centered(math.max(2, math.floor(height / 2) - 2), "GOOBER OS", colors.cyan)
  Components.centered(math.max(3, math.floor(height / 2)), "GENERAL OPERATIONS & ONBOARD BASE ENVIRONMENT RESPONSE", colors.lightGray)
  local barY = math.min(height - 1, math.floor(height / 2) + 2)
  local barX = math.max(1, math.floor((width - 18) / 2) + 1)
  Components.fill(barX, barY, 18, 1, colors.gray)
  Components.fill(barX, barY, index * 6, 1, colors.green)
  Components.centered(math.min(height, math.floor(height / 2) + 4), status, colors.white)
end

bootScreen("Loading configuration", 1)
local detected = capabilities.detect()
bootScreen("Checking display and peripherals", 2)
local network = NetworkService.new(config, detected)
network:start()
bootScreen("Starting network services", 3)
local app = Interface.new(config, network, detected, display, configNotice)
app:draw()

local timer = os.startTimer(1)
while true do
  local event, a, b, c = os.pullEvent()
  if event == "timer" and a == timer then
    network:step()
    app:draw()
    timer = os.startTimer(1)
  elseif event == "rednet_message" then
    network:onRednetMessage(a, b, c)
    app:draw()
  elseif event == "mouse_click" then
    app:handleClick(b, c, a)
  elseif event == "monitor_touch" then
    if not display.monitor_name or a == display.monitor_name then app:handleClick(b, c, 1) end
  elseif event == "char" or event == "key" then
    app:handleEvent(event, a)
  elseif event == "peripheral" or event == "peripheral_detach" then
    display = Display.select(config)
    detected = capabilities.detect()
    network.capabilities = detected
    network:start()
    app.display = display
    app.detected = detected
    app:draw()
  elseif event == "term_resize" or event == "monitor_resize" then
    display = Display.select(config)
    detected = capabilities.detect()
    app.display = display
    app.detected = detected
    app:draw()
  end
end
