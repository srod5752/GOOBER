-- Rednet transport setup and bounded message helpers.
local protocol = require("net.protocol")
local M = {}

function M.open()
  if type(rednet) ~= "table" or type(peripheral) ~= "table" then
    return false, "Rednet or peripheral API is unavailable"
  end

  local opened = 0
  local failures = {}
  for _, name in ipairs(peripheral.getNames()) do
    local okType, kind = pcall(peripheral.getType, name)
    local isModem = kind == "modem"
    if type(kind) == "table" then
      for _, item in ipairs(kind) do if item == "modem" then isModem = true end end
    end
    if okType and isModem then
      local okOpen, err = pcall(rednet.open, name)
      if okOpen then opened = opened + 1 else table.insert(failures, tostring(err)) end
    end
  end
  if opened == 0 then
    return false, #failures > 0 and table.concat(failures, "; ") or "no modem is attached"
  end
  return true, opened
end

function M.send(target, message)
  if not rednet.isOpen() then return false, "Rednet is not open" end
  local ok, sent = pcall(rednet.send, target, message, protocol.name)
  if not ok then return false, tostring(sent) end
  if not sent then return false, "message was not sent" end
  return true
end

function M.broadcast(message)
  if not rednet.isOpen() then return false, "Rednet is not open" end
  local ok, sent = pcall(rednet.broadcast, message, protocol.name)
  if not ok then return false, tostring(sent) end
  if sent == false then return false, "message was not sent" end
  return true
end

function M.receive(timeout)
  if not rednet.isOpen() then return nil, nil, "Rednet is not open" end
  local ok, sender, message, receivedProtocol = pcall(rednet.receive, protocol.name, timeout)
  if not ok then return nil, nil, tostring(sender) end
  if sender == nil then return nil end
  if receivedProtocol ~= protocol.name then return nil, nil, "unexpected protocol" end
  return sender, message
end

return M
