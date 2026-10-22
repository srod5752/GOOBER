-- Versioned GOOBER control-plane messages. Network data is never executed.
local M = {
  name = "goober.v1",
  version = 1,
  controller_host = "goober-controller"
}

function M.make(kind, senderId, sequence, payload, sessionId)
  return {
    version = M.version,
    kind = kind,
    id = tostring(senderId) .. ":" .. tostring(sessionId or "0") .. ":" .. tostring(sequence),
    from = senderId,
    payload = payload or {}
  }
end

function M.validate(message, rednetSender)
  if type(message) ~= "table" then return false, "message is not a table" end
  if message.version ~= M.version then return false, "protocol version mismatch" end
  if type(message.kind) ~= "string" or #message.kind > 40 then return false, "invalid message kind" end
  if type(message.id) ~= "string" or #message.id > 80 then return false, "invalid message id" end
  if type(message.from) ~= "number" or message.from ~= rednetSender then return false, "sender id mismatch" end
  if type(message.payload) ~= "table" then return false, "invalid payload" end
  return true
end

return M
