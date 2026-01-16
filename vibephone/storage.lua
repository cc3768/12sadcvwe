dofile("/vibephone/require_shim.lua")
local config = require("config")

local M = {}

local function readFile(path)
  if not fs.exists(path) then return nil end
  local f = fs.open(path, "r"); if not f then return nil end
  local s = f.readAll(); f.close(); return s
end

local function writeFile(path, s)
  fs.makeDir(fs.getDir(path))
  local f = fs.open(path, "w"); assert(f, "Failed to write: "..path)
  f.write(s); f.close()
end

local function defaultState()
  return {
    version = 1,
    pin = nil,
    settings = {
      deviceName = "VibePhone",
    },
    apps = {
      order = { "vibechat", "appstore", "calculator", "controller" }
    },
    status = "Ready."
  }
end

function M.load()
  local raw = readFile(config.STATE_PATH)
  if not raw then return defaultState() end
  local ok, obj = pcall(function() return textutils.unserializeJSON(raw) end)
  if ok and type(obj) == "table" then
    local d = defaultState()
    obj.version = obj.version or d.version
    obj.settings = obj.settings or d.settings
    obj.apps = obj.apps or d.apps
    obj.apps.order = obj.apps.order or d.apps.order
    obj.status = obj.status or d.status
    return obj
  end
  return defaultState()
end

function M.save(state)
  writeFile(config.STATE_PATH, textutils.serializeJSON(state))
end

return M
