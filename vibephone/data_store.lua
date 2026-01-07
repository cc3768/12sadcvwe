-- /vibephone/data_store.lua
local M = {}

local function readFile(path)
  if not fs.exists(path) then return nil end
  local f = fs.open(path, "r"); if not f then return nil end
  local c = f.readAll(); f.close()
  return c
end

local function writeFile(path, content)
  local f = fs.open(path, "w"); assert(f, "Failed to write: " .. path)
  f.write(content); f.close()
end

local function deepDefault(dst, src)
  for k,v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      deepDefault(dst[k], v)
    else
      if dst[k] == nil then dst[k] = v end
    end
  end
end

function M.load(path)
  local defaults = {
    -- setup state
    setupComplete = false,

    -- server state
    serverId = nil,
    serverName = nil,
    number = nil,
    pinHash = nil,
    token = nil,

    profile = {
      name = "VibePhone",
    },

    ui = {
      theme = "neon",
      accent = colors.cyan,
      wallpaper = "border",
    },

    lock = {
      requirePinForStore = false,
    },

    sms = {
      lastSeenTs = 0,
    },
  }

  local raw = readFile(path)
  if not raw or raw == "" then
    return defaults
  end

  local ok, data = pcall(textutils.unserializeJSON, raw)
  if not ok or type(data) ~= "table" then
    return defaults
  end

  deepDefault(data, defaults)
  return data
end

function M.save(path, data)
  writeFile(path, textutils.serializeJSON(data, true))
end

function M.reset(data)
  data.setupComplete = false
  data.serverId = nil
  data.serverName = nil
  data.number = nil
  data.pinHash = nil
  data.token = nil
  if data.sms then data.sms.lastSeenTs = 0 end
end

return M
