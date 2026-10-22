-- GOOBER dashboard, launcher, network diagnostics, and settings screens.
local ui = require("ui.components")
local configModule = require("core.config")

local App = {}
App.__index = App

local function onlineCount(devices)
  local total = 0
  for _, device in ipairs(devices) do if device.status == "online" then total = total + 1 end end
  return total
end

function App.new(config, network, detected, display, configNotice)
  return setmetatable({
    config = config,
    network = network,
    detected = detected,
    display = display,
    configNotice = configNotice,
    page = "dashboard",
    buttons = {},
    editingName = false,
    nameBuffer = config.device.name,
    notice = nil,
    pendingRestart = false
  }, App)
end

function App:saveConfig()
  local ok, err = configModule.save(self.config)
  if ok then
    self.notice = "Settings saved"
    if os.setComputerLabel then pcall(os.setComputerLabel, self.config.device.name) end
    return true
  end
  self.notice = "Save failed: " .. tostring(err)
  return false
end

function App:syncName()
  self.network.name = self.config.device.name
  if self.network.devices[self.network.id] then self.network.devices[self.network.id].name = self.config.device.name end
  if self.network.role ~= "controller" then
    self.network.lastRegistration = -100000
    self.network.lastHeartbeat = -100000
  end
end

function App:nav()
  local width = term.getSize()
  local nav
  if width < 42 then
    nav = { { "H", "dashboard" }, { "A", "apps" }, { "N", "network" }, { "S", "settings" } }
  else
    nav = { { "HOME", "dashboard" }, { "APPS", "apps" }, { "NETWORK", "network" }, { "SETTINGS", "settings" } }
  end
  local x = 2
  for _, item in ipairs(nav) do
    local label, page = item[1], item[2]
    local buttonWidth = #label + 2
    ui.button(self.buttons, x, 2, buttonWidth, label, function() self.page = page end, true, self.page == page)
    x = x + buttonWidth + 1
  end
end

function App:drawDashboard(width, height)
  ui.text(2, 4, "FACILITY OVERVIEW", ui.colors.accent)
  local devices = self.network:status().devices
  local cached = self.network.role ~= "controller" and self.network.state ~= "connected"
  local columns = width >= 38 and 2 or 1
  local cardHeight = columns == 1 and 3 or 4
  local cellWidth = math.floor((width - (columns + 1) * 2) / columns)
  local rowY = 6
  local cards = {
    { "NETWORK", self.network.state:upper(), self.network.detail, (self.network.state == "connected" or self.network.state == "controller") and ui.colors.good or ui.colors.warn },
    { "DEVICES", cached and (tostring(#devices) .. " CACHED") or (tostring(onlineCount(devices)) .. " ONLINE"), cached and "Last snapshot; status may be stale" or (tostring(#devices) .. " known to this device"), cached and ui.colors.warn or ui.colors.text },
    { "LOCAL HARDWARE", tostring(self.detected.peripherals.speakers) .. " speakers / " .. tostring(self.detected.peripherals.modems) .. " modems", tostring(self.detected.peripherals.monitors) .. " monitors detected", ui.colors.text },
    { "FACILITY APPS", "INTERFACE READY", "Music and announcements arrive in later phases", ui.colors.muted }
  }
  for index, card in ipairs(cards) do
    local col = (index - 1) % columns
    local row = math.floor((index - 1) / columns)
    local x = 2 + col * (cellWidth + 2)
    local y = rowY + row * cardHeight
    ui.panel(x, y, cellWidth, cardHeight, card[1])
    ui.write(x + 2, y + 1, card[2], card[4], ui.colors.panel_dark, cellWidth - 4)
    if columns == 1 then
      ui.write(x + 2, y + 2, card[3], ui.colors.muted, ui.colors.panel_dark, cellWidth - 4)
    else
      ui.write(x + 2, y + 2, card[3], ui.colors.muted, ui.colors.panel_dark, cellWidth - 4)
      ui.fill(x + 2, y + 3, cellWidth - 2, 1, card[4])
    end
  end
  local listY = rowY + math.ceil(#cards / columns) * cardHeight + 1
  if listY < height - 1 then
    ui.text(2, listY, "RECENT DEVICE STATUS", ui.colors.accent)
    local visible = math.max(0, height - listY - 2)
    for i = 1, math.min(#devices, visible) do
      local device = devices[i]
      local age = device.last_seen_seconds and ("  " .. tostring(device.last_seen_seconds) .. "s") or ""
      local shownStatus = cached and (device.status .. " (cached)") or device.status
      local color = cached and ui.colors.muted or (device.status == "online" and ui.colors.good or ui.colors.warn)
      ui.text(3, listY + i, string.format("%-16s %-9s %-16s ID %d%s", device.name, device.role, shownStatus, device.id, age), color, width - 4)
    end
  end
end

function App:drawApps(width, height)
  ui.text(2, 4, "APPLICATION LAUNCHER", ui.colors.accent)
  local apps = {
    { "OVERVIEW", "Live facility status", "dashboard", true },
    { "NETWORK", "Device diagnostics", "network", true },
    { "SETTINGS", "Device preferences", "settings", true },
    { "MUSIC", "Playback and queues", nil, false },
    { "ANNOUNCEMENTS", "Facility audio messages", nil, false },
    { "LOCKDOWN", "Emergency coordination", nil, false }
  }
  local cols = width >= 70 and 3 or width >= 42 and 2 or 1
  local gap = 2
  local cardWidth = math.floor((width - 4 - gap * (cols - 1)) / cols)
  local startY = 6
  for index, app in ipairs(apps) do
    local col = (index - 1) % cols
    local row = math.floor((index - 1) / cols)
    local x, y = 2 + col * (cardWidth + gap), startY + row * 5
    ui.panel(x, y, cardWidth, 4, app[1])
    ui.write(x + 2, y + 1, app[2], ui.colors.muted, ui.colors.panel_dark, cardWidth - 4)
    local label = app[4] and "OPEN" or "PHASE 4+"
    local enabled, destination, appName = app[4], app[3], app[1]
    ui.button(self.buttons, x + 2, y + 2, cardWidth - 4, label, function() if enabled then self.page = destination else self.notice = appName .. " is not available yet" end end, enabled)
  end
  if startY + math.ceil(#apps / cols) * 5 > height then ui.text(2, height, "Use a larger monitor for the full launcher.", ui.colors.muted) end
end

function App:drawNetwork(width, height)
  ui.text(2, 4, "NETWORK DIAGNOSTICS", ui.colors.accent)
  local healthy = self.network.state == "connected" or self.network.state == "controller"
  ui.text(2, 6, "State: " .. self.network.state, healthy and ui.colors.good or ui.colors.warn)
  ui.text(2, 7, "Controller ID: " .. tostring(self.network.controllerId or "not discovered"), ui.colors.text)
  ui.text(2, 8, "Open modems: " .. tostring(self.network.openedModems), ui.colors.text)
  local cached = self.network.role ~= "controller" and self.network.state ~= "connected"
  ui.text(2, 9, "Device data: " .. (cached and "CACHED / MAY BE STALE" or "LIVE"), cached and ui.colors.warn or ui.colors.good)
  ui.text(2, 10, "Detail: " .. self.network.detail, ui.colors.muted, width - 3)
  ui.fill(1, 12, width, 1, colors.blue)
  ui.write(2, 12, "DEVICE          ROLE      STATUS   SEEN      MODEM SPEAKER", colors.white, colors.blue, width - 3)
  local devices = self.network:status().devices
  for i = 1, math.min(#devices, height - 13) do
    local d = devices[i]
    local caps = d.capabilities or {}
    local p = caps.peripherals or {}
    local age = d.last_seen_seconds and (tostring(d.last_seen_seconds) .. "s") or "current"
    local line = string.format("%-14s %-9s %-8s %-7s M:%s S:%s", d.name, d.role, d.status, age, tostring(p.modems or "?"), tostring(p.speakers or "?"))
    ui.text(2, 12 + i, cached and (line .. " CACHED") or line, cached and ui.colors.muted or (d.status == "online" and ui.colors.good or ui.colors.warn), width - 3)
  end
end

function App:drawSettings(width, height)
  ui.text(2, 4, "DEVICE SETTINGS", ui.colors.accent)
  if self.editingName then
    ui.panel(2, 6, math.max(12, width - 4), 5, "EDIT DEVICE NAME")
    ui.write(4, 8, self.nameBuffer .. "_", ui.colors.text, ui.colors.panel_dark, width - 8)
    ui.text(4, 9, "Type a name, Enter to save, Esc to cancel", ui.colors.muted)
    return
  end
  local rows = {
    { "Device name", self.config.device.name, "name" },
    { "Role", self.config.device.role, "role" },
    { "Monitor scale", tostring(self.config.display.monitor_scale), "scale" },
    { "Default volume", tostring(self.config.music.volume), "volume" },
    { "Loop mode", self.config.music.loop, "loop" }
  }
  for i, row in ipairs(rows) do
    local setting = row[3]
    local y = 5 + (i - 1) * 2
    ui.panel(2, y, math.max(12, width - 4), 2, row[1])
    ui.write(4, y + 1, row[2], ui.colors.text)
    local label = row[3] == "name" and "EDIT" or row[3] == "role" and "CHANGE" or "CYCLE"
    ui.button(self.buttons, math.max(4, width - 15), y + 1, 13, label, function() self:changeSetting(setting) end, true)
  end
  if self.pendingRestart and height >= 17 then ui.text(2, height - 3, "Role saved. Reboot to apply it.", ui.colors.warn) end
  if self.notice and height >= 18 then ui.text(2, height - 2, self.notice, ui.colors.muted, width - 3) end
  if height >= 17 then ui.button(self.buttons, 2, height - 1, 16, "SAVE SETTINGS", function() self:saveConfig() end, true) end
end

function App:changeSetting(key)
  if key == "name" then
    self.editingName = true
    self.nameBuffer = self.config.device.name
  elseif key == "role" then
    local roles = { "controller", "terminal", "audio" }
    local at = 1
    for i, role in ipairs(roles) do if role == self.config.device.role then at = i end end
    self.config.device.role = roles[at % #roles + 1]
    if self.config.device.role == "controller" then self.config.device.controller_id = self.config.device.id else self.config.device.controller_id = nil end
    self.pendingRestart = true
    self:saveConfig()
  elseif key == "scale" then
    local scales = { 0.5, 1, 1.5, 2, 2.5, 3, 4, 5 }
    local at = 1
    for i, scale in ipairs(scales) do if scale == self.config.display.monitor_scale then at = i end end
    self.config.display.monitor_scale = scales[at % #scales + 1]
    self.display = require("ui.display").select(self.config)
    self:saveConfig()
  elseif key == "volume" then
    self.config.music.volume = self.config.music.volume >= 3 and 0 or math.min(3, self.config.music.volume + 0.5)
    self:saveConfig()
  elseif key == "loop" then
    local modes = { "off", "queue", "song" }
    local at = 1
    for i, mode in ipairs(modes) do if mode == self.config.music.loop then at = i end end
    self.config.music.loop = modes[at % #modes + 1]
    self:saveConfig()
  end
end

function App:draw()
  local width, height = term.getSize()
  ui.clear()
  self.buttons = {}
  ui.fill(1, 1, width, 1, colors.gray)
  ui.write(2, 1, "GOOBER OS", colors.cyan, colors.gray)
  local healthy = self.network.state == "connected" or self.network.state == "controller"
  local networkLabel = self.network.state:upper()
  local badgeX = math.max(1, width - #networkLabel - 2)
  ui.fill(badgeX, 1, #networkLabel + 2, 1, healthy and colors.green or colors.red)
  ui.write(badgeX + 1, 1, networkLabel, colors.black, healthy and colors.green or colors.red)
  self:nav()
  if self.page == "dashboard" then self:drawDashboard(width, height)
  elseif self.page == "apps" then self:drawApps(width, height)
  elseif self.page == "network" then self:drawNetwork(width, height)
  elseif self.page == "settings" then self:drawSettings(width, height) end
  if self.notice and self.page ~= "settings" and height > 2 then ui.text(2, height - 1, self.notice, ui.colors.warn, width - 3) end
  ui.fill(1, height, width, 1, colors.gray)
  ui.write(2, height, self.display.monitor and ("MONITOR " .. tostring(self.display.monitor_name)) or "LOCAL TERMINAL", colors.lightGray, colors.gray)
end

function App:handleClick(x, y, button)
  if button and button ~= 1 then return end
  for _, item in ipairs(self.buttons) do
    if item.enabled and x >= item.x and x < item.x + item.width and y >= item.y and y < item.y + item.height then
      item.action()
      self:draw()
      return
    end
  end
end

function App:handleEvent(event, a)
  if not self.editingName then return end
  if event == "char" and #self.nameBuffer < 32 then self.nameBuffer = self.nameBuffer .. a
  elseif event == "key" then
    if a == keys.backspace then self.nameBuffer = self.nameBuffer:sub(1, -2)
    elseif a == keys.enter then
      local name = self.nameBuffer:gsub("[%c]", " "):gsub("^%s+", ""):gsub("%s+$", "")
      if name ~= "" then self.config.device.name = name; self:syncName(); self:saveConfig() end
      self.editingName = false
    elseif a == keys.escape then self.editingName = false end
  end
  self:draw()
end

return App
