-- /vibephone/net.lua
local cfg = require("config")
local store = require("data_store")

local M = {}

-- ---------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------
local function sides()
  return {"left","right","front","back","top","bottom"}
end

local function isModemSide(side)
  if not side or not peripheral.isPresent(side) then return false end
  local t = peripheral.getType(side)
  return t == "modem" or t == "ender_modem"
end

-- Accept either a saved-data table or anything else (then load from disk)
local function normalizeData(arg)
  if type(arg) == "table" then
    -- Heuristic: if it looks like our data structure, use it directly
    if arg.ui ~= nil or arg.profile ~= nil or arg.number ~= nil or arg.serverId ~= nil or arg.pinHash ~= nil then
      return arg
    end
  end

  local path = (cfg and cfg.dataFile) or "/vibephone/data.json"
  return store.load(path)
end

local function makeNonce()
  local a = tostring(math.random(100000, 999999))
  local b = tostring(math.random(100000, 999999))
  local t = tostring((os.epoch and os.epoch("utc")) or os.time())
  return a .. "-" .. b .. "-" .. t
end

-- ---------------------------------------------------------
-- Modem open
-- ---------------------------------------------------------
function M.openModem()
  local opened = false

  -- Prefer configured side first
  if cfg.modemSide and isModemSide(cfg.modemSide) then
    if not rednet.isOpen(cfg.modemSide) then rednet.open(cfg.modemSide) end
    opened = true
  end

  -- Open any other modem sides
  for _,s in ipairs(sides()) do
    if isModemSide(s) and not rednet.isOpen(s) then
      rednet.open(s)
      opened = true
    end
  end

  if not opened then
    return false, "No modem found. (Need modem/ender modem attached)"
  end

  return true
end

-- Backwards compatible init() used by older main.lua
function M.init(cfgArg)
  local ok, err = M.openModem()
  if not ok then return false, err end
  return true
end

-- ---------------------------------------------------------
-- Discovery (ping/pong)
-- ---------------------------------------------------------
function M.discoverServer(dataArg, timeout)
  local data = normalizeData(dataArg)
  timeout = timeout or (cfg.server and cfg.server.discover_timeout) or 2.5

  -- If config pins a server id, trust it
  if cfg.server and cfg.server.id then
    data.serverId = cfg.server.id
    data.serverName = cfg.server.label or "VibePhone Server"
    store.save(cfg.dataFile, data)
    return true
  end

  -- Already known
  if data.serverId then return true end

  local nonce = makeNonce()

  rednet.broadcast({
    type  = "vp_ping",
    nonce = nonce,
    want  = "vibephone_server",
    from  = tostring(data.number or ""),
  }, cfg.rednet.protocol)

  local timer = os.startTimer(timeout)

  while true do
    local ev, p1, p2, p3 = os.pullEvent()
    if ev == "rednet_message" then
      local sid, msg, proto = p1, p2, p3
      if proto == cfg.rednet.protocol and type(msg) == "table" and msg.type == "vp_pong" and msg.nonce == nonce then
        data.serverId = sid
        data.serverName = msg.name or msg.label or "VibePhone Server"
        store.save(cfg.dataFile, data)
        return true
      end
    elseif ev == "timer" and p1 == timer then
      return false, "No server responded"
    end
  end
end

-- ---------------------------------------------------------
-- Request/Response
-- ---------------------------------------------------------
function M.request(dataArg, payload, timeout)
  local data = normalizeData(dataArg)
  timeout = timeout or (cfg.rednet and cfg.rednet.request_timeout) or 2.5

  if not data.serverId then
    local ok, err = M.discoverServer(data, timeout)
    if not ok then return false, err or "no_server" end
  end

  local nonce = makeNonce()
  payload = payload or {}
  payload.nonce = nonce

  rednet.send(data.serverId, payload, cfg.rednet.protocol)

  local timer = os.startTimer(timeout)
  while true do
    local ev, p1, p2, p3 = os.pullEvent()
    if ev == "rednet_message" then
      local sid, msg, proto = p1, p2, p3
      if sid == data.serverId and proto == cfg.rednet.protocol and type(msg) == "table" and msg.nonce == nonce then
        return true, msg
      end
    elseif ev == "timer" and p1 == timer then
      return false, "timeout"
    end
  end
end

return M
