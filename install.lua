-- Self-contained CC:Tweaked installer. Enter the raw-content repository root
-- when prompted, e.g. https://raw.githubusercontent.com/OWNER/REPO/main.
local installRoot = "/goober"
local stagingRoot = installRoot .. "/staging"
local backupRoot = installRoot .. "/backups"
local appRoot = installRoot .. "/app"

local function say(text, color)
  if color then term.setTextColor(color) end
  print(text)
  term.setTextColor(colors.white)
end

local function prompt(label, default)
  write(label)
  if default and default ~= "" then write(" [" .. default .. "]") end
  write(": ")
  local value = read()
  if value == "" then return default end
  return value
end

local function normalizeRoot(value)
  if type(value) ~= "string" then return nil end
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  value = value:gsub("/+$", "")
  if not value:match("^https://") then return nil end
  if value:find("%?") or value:find("#") then return nil end
  return value
end

local function safeRelative(path)
  if type(path) ~= "string" or path == "" then return false end
  if path:sub(1, 1) == "/" or path:find("\\") or path:find(":") then return false end
  for part in path:gmatch("[^/]+") do
    if part == "." or part == ".." then return false end
  end
  return true
end

local function fetch(url)
  local ok, handle, err = pcall(http.get, url)
  if not ok then return nil, tostring(handle) end
  if not handle then return nil, tostring(err or "request failed") end
  local code, message = 200, "OK"
  if handle.getResponseCode then
    local codeOk, responseCode, responseMessage = pcall(handle.getResponseCode)
    if codeOk and responseCode then code, message = responseCode, responseMessage end
  end
  local bodyOk, body = pcall(handle.readAll)
  pcall(handle.close)
  if not bodyOk then return nil, tostring(body) end
  if code < 200 or code >= 300 then
    return nil, "HTTP " .. tostring(code) .. " " .. tostring(message)
  end
  if type(body) ~= "string" or #body == 0 then return nil, "empty response" end
  return body
end

local function save(path, content)
  local parent = fs.getDir(path)
  if parent ~= "" and not fs.exists(parent) then fs.makeDir(parent) end
  local handle, err = fs.open(path, "w")
  if not handle then return false, err or "could not open destination" end
  local ok, writeError = pcall(handle.write, content)
  handle.close()
  if not ok then return false, tostring(writeError) end
  return true
end

local function copyIfExists(source, target)
  if not fs.exists(source) then return true end
  local parent = fs.getDir(target)
  if parent ~= "" and not fs.exists(parent) then fs.makeDir(parent) end
  local ok, err = pcall(fs.copy, source, target)
  return ok, err
end

local function chooseRole()
  print("Choose this computer's primary role:")
  print("  1) Controller - coordinates shared facility state")
  print("  2) Terminal   - full user interface")
  print("  3) Audio node - speaker output service")
  while true do
    local choice = prompt("Role", "2")
    if choice == "1" then return "controller" end
    if choice == "2" then return "terminal" end
    if choice == "3" then return "audio" end
    say("Enter 1, 2, or 3.", colors.yellow)
  end
end

term.setTextColor(colors.cyan)
print("GOOBER OS installer - foundation 0.1.0")
term.setTextColor(colors.white)
if not http then
  say("HTTP API is unavailable. Check the CC:Tweaked installation.", colors.red)
  return
end
if not http.checkURL then
  say("This CC:Tweaked build does not provide http.checkURL.", colors.red)
  return
end

local root = normalizeRoot(prompt("Raw GitHub content root (https://raw.githubusercontent.com/OWNER/REPO/BRANCH)"))
if not root then
  say("Use an HTTPS raw-content root without a query string or fragment.", colors.red)
  return
end
local manifestUrl = root .. "/manifest.json"
local urlOk, urlReason = http.checkURL(manifestUrl)
if not urlOk then
  say("HTTP access is disabled or this URL is blocked: " .. tostring(urlReason), colors.red)
  say("Enable HTTP access for this domain in the server's CC:Tweaked configuration.", colors.yellow)
  return
end

say("Fetching manifest...")
local manifestBody, manifestError = fetch(manifestUrl)
if not manifestBody then
  say("Could not download manifest: " .. tostring(manifestError), colors.red)
  return
end
local manifestOk, manifest = pcall(textutils.unserialiseJSON, manifestBody)
if not manifestOk or type(manifest) ~= "table" or type(manifest.files) ~= "table" or type(manifest.version) ~= "string" then
  say("The repository manifest is invalid.", colors.red)
  return
end

if (fs.exists(installRoot) and fs.exists(appRoot)) or fs.exists("/startup.lua") then
  say("An existing GOOBER installation or startup.lua was found.", colors.yellow)
  say("Program files and startup.lua will be backed up. /goober/data will be kept.", colors.yellow)
  if prompt("Continue with repair/install? (y/N)", "n"):lower() ~= "y" then
    say("Cancelled; no files changed.")
    return
  end
end

if fs.exists(stagingRoot) then fs.delete(stagingRoot) end
fs.makeDir(stagingRoot)
local downloaded = 0
for _, relative in ipairs(manifest.files) do
  if not safeRelative(relative) then
    say("Unsafe path in manifest: " .. tostring(relative), colors.red)
    fs.delete(stagingRoot)
    return
  end
  local body, downloadError = fetch(root .. "/" .. relative)
  if not body then
    say("Download failed for " .. relative .. ": " .. tostring(downloadError), colors.red)
    fs.delete(stagingRoot)
    return
  end
  if relative:match("%.lua$") then
    local compileOk, compileError = load(body, "@" .. relative)
    if not compileOk then
      say("Lua syntax check failed for " .. relative .. ": " .. tostring(compileError), colors.red)
      fs.delete(stagingRoot)
      return
    end
  end
  local saved, saveError = save(stagingRoot .. "/" .. relative, body)
  if not saved then
    say("Could not stage " .. relative .. ": " .. tostring(saveError), colors.red)
    fs.delete(stagingRoot)
    return
  end
  downloaded = downloaded + 1
end
if downloaded == 0 then
  say("The manifest has no installable files.", colors.red)
  fs.delete(stagingRoot)
  return
end

local role = chooseRole()
local id = os.getComputerID()
local defaultName = os.getComputerLabel() or ("GOOBER-" .. tostring(id))
local name = prompt("Device name (up to 32 characters)", defaultName)
name = tostring(name or defaultName):gsub("[%c]", " "):gsub("^%s+", ""):gsub("%s+$", "")
if name == "" then name = defaultName end
name = name:sub(1, 32)

if not fs.exists(installRoot) then fs.makeDir(installRoot) end
if not fs.exists(backupRoot) then fs.makeDir(backupRoot) end
local backupName = "install-" .. tostring(id) .. "-" .. tostring(os.clock and math.floor(os.clock() * 1000) or 0)
local backupPath = backupRoot .. "/" .. backupName
fs.makeDir(backupPath)
local backupOk, backupError = copyIfExists(appRoot, backupPath .. "/app")
if not backupOk then
  say("Could not back up existing application files: " .. tostring(backupError), colors.red)
  fs.delete(stagingRoot)
  return
end
backupOk, backupError = copyIfExists("/startup.lua", backupPath .. "/startup.lua")
if not backupOk then
  say("Could not back up startup.lua: " .. tostring(backupError), colors.red)
  fs.delete(stagingRoot)
  return
end

local configPath = "/goober/data/config.json"
local configExists = fs.exists(configPath)
if configExists then
  say("Existing device configuration detected; role and name will be preserved.", colors.yellow)
else
  local config = {
    schema = 1,
    device = { id = id, name = name, role = role, controller_id = role == "controller" and id or nil },
    display = { monitor_scale = 1 },
    music = { volume = 1.5, loop = "off" },
    network = { heartbeat_seconds = 10, stale_seconds = 30 }
  }
  local encoded = textutils.serialiseJSON(config)
  local saved, saveError = save(configPath, encoded)
  if not saved then
    say("Could not save device configuration: " .. tostring(saveError), colors.red)
    fs.delete(stagingRoot)
    return
  end
end
local repositoryPath = "/goober/data/repository.json"
if not fs.exists(repositoryPath) then
  local repositoryConfig = textutils.serialiseJSON({ root = root, version = manifest.version })
  local repoSaved, repoError = save(repositoryPath, repositoryConfig)
  if not repoSaved then
    say("Could not save repository settings: " .. tostring(repoError), colors.red)
    fs.delete(stagingRoot)
    return
  end
end

-- Swap application files only after every file has been downloaded and checked.
if fs.exists(appRoot) then fs.delete(appRoot) end
local stagedApp = stagingRoot .. "/app"
if not fs.exists(stagedApp) then fs.makeDir(stagedApp) end
local stagedStartup = stagingRoot .. "/startup.lua"
if fs.exists(stagedApp) then fs.move(stagedApp, appRoot) end
if fs.exists(stagedStartup) then
  local tempStartup = "/startup.lua.goober-tmp"
  if fs.exists(tempStartup) then fs.delete(tempStartup) end
  fs.move(stagedStartup, tempStartup)
  if fs.exists("/startup.lua") then fs.delete("/startup.lua") end
  fs.move(tempStartup, "/startup.lua")
end
fs.delete(stagingRoot)

if os.setComputerLabel then pcall(os.setComputerLabel, name) end
say("Installed GOOBER " .. manifest.version .. " (" .. tostring(downloaded) .. " files).", colors.green)
say("Device: " .. name .. " | Role: " .. role)
say("Persistent data is stored under /goober/data and was preserved.")
if prompt("Launch GOOBER now? (Y/n)", "y"):lower() ~= "n" then
  shell.run("/goober/app/main.lua")
else
  say("Run: shell.run(\"/goober/app/main.lua\") or reboot to start automatically.", colors.yellow)
end
