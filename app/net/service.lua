-- Controller registry and terminal/audio-node client service.
local protocol = require("net.protocol")
local transport = require("net.transport")
local configModule = require("core.config")

local Service = {}
Service.__index = Service

local function copyDevice(entry, now, staleSeconds)
  local age = math.max(0, now - entry.last_seen)
  return {
    id = entry.id,
    name = entry.name,
    role = entry.role,
    capabilities = entry.capabilities,
    status = age <= staleSeconds and "online" or "offline",
    last_seen_seconds = age
  }
end

local function createSessionId()
  local timestamp = tostring(os.clock and os.clock() or 0)
  if type(os.epoch) == "function" then
    local ok, value = pcall(os.epoch, "utc")
    if ok then timestamp = tostring(value) end
  end
  local random = math.random and tostring(math.random(0, 2147483647)) or "0"
  return timestamp .. "-" .. random
end

function Service.new(config, capabilities)
  local self = setmetatable({}, Service)
  self.config = config
  self.capabilities = capabilities
  self.id = os.getComputerID()
  self.role = config.device.role
  self.name = config.device.name
  self.tick = 0
  self.sequence = 0
  self.sessionId = createSessionId()
  self.devices = {}
  self.snapshot = {}
  self.lastRegistration = -100000
  self.lastHeartbeat = -100000
  self.lastDiscovery = -100000
  self.lastSnapshot = -100000
  self.lastControllerMessage = nil
  self.controllerId = config.device.controller_id
  self.state = "starting"
  self.detail = "Opening modem network"
  self.openedModems = 0
  self.seenMessages = {}
  self.seenOrder = {}
  self.started = false
  self.hosted = false
  return self
end

function Service:nextMessage(kind, payload)
  self.sequence = self.sequence + 1
  return protocol.make(kind, self.id, self.sequence, payload, self.sessionId)
end

function Service:start()
  local ok, value = transport.open()
  if not ok then
    self.started = false
    self.openedModems = 0
    self.state = "offline"
    self.detail = "Network unavailable: " .. tostring(value)
    return false, self.detail
  end
  self.openedModems = value
  self.started = true

  if self.role == "controller" then
    if not self.hosted then
      local hostOk, hostError = pcall(rednet.host, protocol.name, protocol.controller_host)
      if not hostOk then
        self.started = false
        self.state = "offline"
        self.detail = "Could not host controller service: " .. tostring(hostError)
        return false, self.detail
      end
      self.hosted = true
    end
    self.controllerId = self.id
    self.state = "controller"
    self.detail = "Controller active; waiting for devices"
    self.devices[self.id] = {
      id = self.id,
      name = self.name,
      role = self.role,
      capabilities = self.capabilities,
      last_seen = self.tick
    }
    return true
  end

  self.state = "searching"
  self.detail = self.controllerId and ("Connecting to controller " .. self.controllerId) or "Looking for one controller"
  return true
end

function Service:deviceList()
  if self.role == "controller" then
    local result = {}
    for _, entry in pairs(self.devices) do
      table.insert(result, copyDevice(entry, self.tick, self.config.network.stale_seconds))
    end
    table.sort(result, function(a, b) return a.id < b.id end)
    return result
  end
  return self.snapshot
end

function Service:publishSnapshot(force)
  if self.role ~= "controller" then return end
  if not force and self.tick - self.lastSnapshot < 5 then return end
  self.lastSnapshot = self.tick
  local devices = self:deviceList()
  for id in pairs(self.devices) do
    if id ~= self.id then
      transport.send(id, self:nextMessage("state", {
        devices = devices,
        controller_id = self.id,
        published_at_tick = self.tick
      }))
    end
  end
end

function Service:registerDevice(sender, payload)
  if type(payload.name) ~= "string" or #payload.name < 1 or #payload.name > 32 then return end
  if type(payload.role) ~= "string" or (payload.role ~= "terminal" and payload.role ~= "audio") then return end
  local entry = self.devices[sender] or { id = sender }
  entry.name = payload.name:gsub("[%c]", " ")
  entry.role = payload.role
  entry.capabilities = type(payload.capabilities) == "table" and payload.capabilities or {}
  entry.last_seen = self.tick
  self.devices[sender] = entry
  transport.send(sender, self:nextMessage("registered", { controller_id = self.id, tick = self.tick }))
  self:publishSnapshot(true)
end

function Service:handleController(sender, message)
  if sender == self.id then return end
  if message.kind == "discover" then
    transport.send(sender, self:nextMessage("controller", { controller_id = self.id, name = self.name }))
  elseif message.kind == "register" then
    self:registerDevice(sender, message.payload)
  elseif message.kind == "heartbeat" then
    local entry = self.devices[sender]
    if entry then
      entry.last_seen = self.tick
      transport.send(sender, self:nextMessage("heartbeat_ack", { controller_id = self.id, tick = self.tick }))
      self:publishSnapshot(false)
    else
      self:registerDevice(sender, message.payload)
    end
  end
end

function Service:handleClient(sender, message)
  if not self.controllerId or sender ~= self.controllerId then return end
  if message.kind == "controller" then
    self.lastControllerMessage = self.tick
    self.state = "connected"
    self.detail = "Controller found: " .. tostring(sender)
  elseif message.kind == "registered" then
    if message.payload.controller_id ~= sender then return end
    self.lastControllerMessage = self.tick
    self.state = "connected"
    self.detail = "Registered with controller " .. tostring(sender)
  elseif message.kind == "heartbeat_ack" then
    if message.payload.controller_id ~= sender then return end
    self.lastControllerMessage = self.tick
    self.state = "connected"
  elseif message.kind == "state" then
    if message.payload.controller_id ~= sender or type(message.payload.devices) ~= "table" then return end
    self.snapshot = message.payload.devices
    self.lastControllerMessage = self.tick
    self.state = "connected"
    self.detail = "Shared status received"
  end
end

function Service:onRednetMessage(sender, message, receivedProtocol)
  if receivedProtocol ~= protocol.name then return end
  local valid = protocol.validate(message, sender)
  if not valid then return end
  if self.seenMessages[message.id] then return end
  self.seenMessages[message.id] = true
  table.insert(self.seenOrder, message.id)
  if #self.seenOrder > 128 then
    local oldest = table.remove(self.seenOrder, 1)
    self.seenMessages[oldest] = nil
  end

  if self.role == "controller" then
    self:handleController(sender, message)
  else
    self:handleClient(sender, message)
  end
end

function Service:discover()
  transport.broadcast(self:nextMessage("discover", { name = self.name }))
  -- This protocol is hosted only by controllers, so inspect every host to
  -- detect accidental multiple controllers rather than asking for one name.
  local found = { rednet.lookup(protocol.name, nil, 0.5) }
  local unique = {}
  for _, id in ipairs(found) do unique[id] = true end
  local ids = {}
  for id in pairs(unique) do table.insert(ids, id) end
  table.sort(ids)

  if self.controllerId then
    local present = false
    for _, id in ipairs(ids) do if id == self.controllerId then present = true end end
    if present then
      self.state = "connecting"
      self.detail = "Controller " .. tostring(self.controllerId) .. " is responding"
    else
      self.state = "offline"
      self.detail = "Configured controller " .. tostring(self.controllerId) .. " is unavailable"
    end
    return
  end

  if #ids == 1 then
    self.controllerId = ids[1]
    self.config.device.controller_id = self.controllerId
    configModule.save(self.config)
    self.state = "connecting"
    self.detail = "Found controller " .. tostring(self.controllerId)
  elseif #ids > 1 then
    self.state = "conflict"
    self.detail = "Multiple controllers found; set controller_id in config"
  else
    self.state = "searching"
    self.detail = "No controller found; retrying"
  end
end

function Service:sendClientPulse()
  if not self.controllerId then return end
  local kind = self.lastRegistration < 0 and "register" or "heartbeat"
  local message = self:nextMessage(kind, {
    name = self.name,
    role = self.role,
    capabilities = self.capabilities,
    version = "0.3.0-interface"
  })
  local ok, err = transport.send(self.controllerId, message)
  if not ok then
    self.state = "offline"
    self.detail = "Controller send failed: " .. tostring(err)
    return
  end
  if kind == "register" then self.lastRegistration = self.tick end
  self.lastHeartbeat = self.tick
end

function Service:step()
  self.tick = self.tick + 1
  if not self.started then
    self:start()
    return
  end

  if self.role == "controller" then
    local selfEntry = self.devices[self.id]
    if selfEntry then
      selfEntry.last_seen = self.tick
      selfEntry.capabilities = self.capabilities
    end
    self:publishSnapshot(false)
    return
  end

  local lastContact = self.lastControllerMessage or self.lastHeartbeat
  if self.controllerId and self.lastHeartbeat >= 0 and self.tick - lastContact > self.config.network.stale_seconds then
    self.state = "offline"
    self.detail = "Controller heartbeat timed out"
  end

  if not self.controllerId and self.tick - self.lastDiscovery >= 5 then
    self.lastDiscovery = self.tick
    self:discover()
  elseif self.controllerId and self.tick - self.lastHeartbeat >= self.config.network.heartbeat_seconds then
    self:sendClientPulse()
  end
end

function Service:status()
  return {
    state = self.state,
    detail = self.detail,
    controller_id = self.controllerId,
    modem_count = self.openedModems,
    devices = self:deviceList()
  }
end

return Service
