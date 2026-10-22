-- Device configuration validation and defaults.
local storage = require("core.storage")
local M = {}

M.PATH = "/goober/data/config.json"
M.ROLES = { controller = true, terminal = true, audio = true }

local function cleanName(value, fallback)
  if type(value) ~= "string" then return fallback end
  value = value:gsub("[%c]", " "):gsub("^%s+", ""):gsub("%s+$", "")
  if value == "" then return fallback end
  if #value > 32 then value = value:sub(1, 32) end
  return value
end

function M.defaults()
  local id = os.getComputerID()
  return {
    schema = 1,
    device = {
      id = id,
      name = os.getComputerLabel() or ("GOOBER-" .. tostring(id)),
      role = "terminal",
      controller_id = nil
    },
    display = { monitor_scale = 1 },
    music = { volume = 1.5, loop = "off" },
    network = { heartbeat_seconds = 10, stale_seconds = 30 }
  }
end

function M.validate(candidate)
  if type(candidate) ~= "table" then return nil, "configuration is not an object" end
  local defaults = M.defaults()
  local inputDevice = type(candidate.device) == "table" and candidate.device or {}
  local role = inputDevice.role
  if not M.ROLES[role] then role = "terminal" end

  local id = os.getComputerID()
  local controllerId = inputDevice.controller_id
  if type(controllerId) ~= "number" or controllerId < 0 then controllerId = nil end
  if role == "controller" then controllerId = id end

  local volume = type(candidate.music) == "table" and candidate.music.volume or nil
  if type(volume) ~= "number" then volume = defaults.music.volume end
  volume = math.max(0, math.min(3, volume))

  local loop = type(candidate.music) == "table" and candidate.music.loop or "off"
  if loop ~= "off" and loop ~= "queue" and loop ~= "song" then loop = "off" end

  local scale = type(candidate.display) == "table" and candidate.display.monitor_scale or 1
  if type(scale) ~= "number" or scale < 0.5 or scale > 5 or scale * 2 % 1 ~= 0 then scale = 1 end

  return {
    schema = 1,
    device = {
      id = id,
      name = cleanName(inputDevice.name, "GOOBER-" .. tostring(id)),
      role = role,
      controller_id = controllerId
    },
    display = { monitor_scale = scale },
    music = { volume = volume, loop = loop },
    network = {
      heartbeat_seconds = 10,
      stale_seconds = 30
    }
  }
end

function M.load()
  local value, reason = storage.readJson(M.PATH)
  if not value then
    if reason ~= "missing" then storage.quarantine(M.PATH, ".invalid") end
    local defaults = M.defaults()
    local ok, err = storage.writeJson(M.PATH, defaults)
    if not ok then return defaults, "using defaults; save failed: " .. tostring(err) end
    return defaults, reason == "missing" and "created defaults" or "recovered defaults"
  end

  local validated, validationError = M.validate(value)
  if not validated then
    storage.quarantine(M.PATH, ".invalid")
    local defaults = M.defaults()
    storage.writeJson(M.PATH, defaults)
    return defaults, "recovered defaults: " .. tostring(validationError)
  end

  if textutils.serialiseJSON(value) ~= textutils.serialiseJSON(validated) then
    storage.writeJson(M.PATH, validated)
  end
  return validated
end

function M.save(value)
  local validated, err = M.validate(value)
  if not validated then return false, err end
  return storage.writeJson(M.PATH, validated)
end

return M
