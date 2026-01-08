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

local function defaults()
  return {
    setupComplete = false,

    serverId = nil,
    serverName = nil,
    number = nil,
    pinHash = nil,
    token = nil,

    profile = { name = "VibePhone" },

    ui = { theme = "neon", accent = colors.cyan, wallpaper = "border" },

    lock = { requirePinForStore = false },

    sms = { lastSeenTs = 0, unread = 0, inbox = {} },
  }
end

local function ensureShapes(data)
  if type(data.profile) ~= "table" then data.profile = { name = "VibePhone" } end
  if type(data.ui) ~= "table" then data.ui = { theme="neon", accent=colors.cyan, wallpaper="border" } end
  if type(data.lock) ~= "table" then data.lock = { requirePinForStore=false } end

  if type(data.sms) ~= "table" then data.sms = {} end
  if type(data.sms.inbox) ~= "table" then data.sms.inbox = {} end
  if type(data.sms.unread) ~= "number" then data.sms.unread = 0 end
  if type(data.sms.lastSeenTs) ~= "number" then data.sms.lastSeenTs = 0 end
end

local function parseData(raw)
  -- 1) Try JSON
  local okJ, dataJ = pcall(textutils.unserializeJSON, raw)
  if okJ and type(dataJ) == "table" then return dataJ end

  -- 2) Try Lua table serialization (what your file currently looks like)
  local okL, dataL = pcall(textutils.unserialize, raw)
  if okL and type(dataL) == "table" then return dataL end

  return nil
end

function M.load(path)
  local def = defaults()
  local raw = readFile(path)

  if not raw or raw == "" then
    ensureShapes(def)
    return def
  end

  local data = parseData(raw)
  if type(data) ~= "table" then
    ensureShapes(def)
    return def
  end

  deepDefault(data, def)
  ensureShapes(data)
  return data
end

function M.save(path, data)
  ensureShapes(data)
  -- IMPORTANT: save using Lua serialization so it matches your current file style
  writeFile(path, textutils.serialize(data))
end

function M.reset(data)
  data.setupComplete = false
  data.serverId = nil
  data.serverName = nil
  data.number = nil
  data.pinHash = nil
  data.token = nil
  if data.sms then
    data.sms.lastSeenTs = 0
    data.sms.unread = 0
    data.sms.inbox = {}
  end
end

return M
