-- Small JSON-backed storage helpers. Data files are kept separate from code.
local M = {}

local function ensureParent(path)
  local parent = fs.getDir(path)
  if parent ~= "" and not fs.exists(parent) then fs.makeDir(parent) end
end

function M.readJson(path)
  if not fs.exists(path) then return nil, "missing" end
  if fs.isDir(path) then return nil, "is a directory" end

  local handle, openError = fs.open(path, "r")
  if not handle then return nil, openError or "could not open file" end
  local contents = handle.readAll()
  handle.close()

  local ok, value = pcall(textutils.unserialiseJSON, contents)
  if not ok or type(value) ~= "table" then
    return nil, "invalid JSON"
  end
  return value
end

function M.writeJson(path, value)
  ensureParent(path)
  local ok, encoded = pcall(textutils.serialiseJSON, value)
  if not ok or type(encoded) ~= "string" then
    return false, "could not encode data"
  end

  local temporary = path .. ".tmp"
  local backup = path .. ".bak"
  if fs.exists(temporary) then fs.delete(temporary) end

  local handle, openError = fs.open(temporary, "w")
  if not handle then return false, openError or "could not create temporary file" end
  local writeOk, writeError = pcall(handle.write, encoded)
  handle.close()
  if not writeOk then
    if fs.exists(temporary) then fs.delete(temporary) end
    return false, tostring(writeError)
  end

  -- Keep one prior copy so a failed replacement can be recovered.
  if fs.exists(path) then
    if fs.exists(backup) then fs.delete(backup) end
    local copyOk, copyError = pcall(fs.copy, path, backup)
    if not copyOk then
      fs.delete(temporary)
      return false, tostring(copyError)
    end
    fs.delete(path)
  end

  local moveOk, moveError = pcall(fs.move, temporary, path)
  if not moveOk then
    if fs.exists(backup) and not fs.exists(path) then
      pcall(fs.copy, backup, path)
    end
    if fs.exists(temporary) then fs.delete(temporary) end
    return false, tostring(moveError)
  end
  return true
end

function M.quarantine(path, suffix)
  if not fs.exists(path) then return false end
  local target = path .. (suffix or ".corrupt")
  if fs.exists(target) then fs.delete(target) end
  local ok = pcall(fs.move, path, target)
  return ok, target
end

return M
