local config = require("config")
local S = require("state")
local state, pushRoom, pushPeer = S.state, S.pushRoom, S.pushPeer

local function jencode(t) return textutils.serializeJSON(t) end
local function jdecode(s) return textutils.unserializeJSON(s) end

-- ----- persistent settings -----
local settings = { deviceId = nil, call = nil, name = nil, lastPeer = nil }

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

local function randHex(nbytes)
  local chars = "0123456789abcdef"
  local out = {}
  for i=1,nbytes do
    local v = math.random(0,255)
    out[#out+1] = chars:sub((math.floor(v/16)+1),(math.floor(v/16)+1))
    out[#out+1] = chars:sub(((v%16)+1),((v%16)+1))
  end
  return table.concat(out)
end

local function loadSettings()
  local raw = readFile(config.SETTINGS_PATH)
  if not raw then return end
  local ok, obj = pcall(function() return textutils.unserializeJSON(raw) end)
  if ok and type(obj) == "table" then
    settings.deviceId = obj.deviceId or settings.deviceId
    settings.call = obj.call or settings.call
    settings.name = obj.name or settings.name
    settings.lastPeer = obj.lastPeer or settings.lastPeer
  end
end

local function saveSettings()
  local out = {
    deviceId = settings.deviceId,
    call = settings.call,
    name = settings.name,
    lastPeer = settings.lastPeer
  }
  writeFile(config.SETTINGS_PATH, textutils.serializeJSON(out))
end

local function ensureDeviceId()
  loadSettings()
  if not settings.deviceId then
    settings.deviceId = "pc-" .. randHex(12)
    saveSettings()
  end
end

local function setCall(call)
  settings.call = call
  saveSettings()
end

local function setLastPeer(peer)
  settings.lastPeer = peer
  saveSettings()
end

local function getDeviceId()
  ensureDeviceId()
  return settings.deviceId
end

local function getSavedName() return settings.name end

local function setSavedName(n)
  settings.name = n
  saveSettings()
end

-- ----- ws helpers -----
local function wsSend(obj)
  if not state.ws or not state.connected then return false end
  local ok = pcall(function() state.ws.send(jencode(obj)) end)
  return ok
end

local function formatTs(ms)
  local t = os.date("*t", math.floor((ms or 0)/1000))
  return string.format("%02d:%02d", t.hour or 0, t.min or 0)
end

local function onServerMsg(msg, redraw)
if msg.t == "hello" then
  -- accept multiple possible field names from server
  local call = msg.call or msg.id or msg.callId or msg.call_id

  state.call = call
  if call ~= nil then setCall(call) end

  state.room = msg.defaultRoom or config.DEFAULT_ROOM

  if call ~= nil then
    state.status = "Assigned call #" .. tostring(call) .. (msg.temporary and " (TEMP)" or "")
    pushRoom(state.room, ("[%s] * assigned call #%s"):format(formatTs(msg.serverTime), tostring(state.call or "?")))
  else
    state.status = "Connected (no call assigned yet)"
    pushRoom(state.room, ("[%s] * connected"):format(formatTs(msg.serverTime)))
  end

  if settings.lastPeer and not state.activePeer then
    state.activePeer = settings.lastPeer
  end

  redraw()
  return
end


  if msg.t == "directory" then
    state.directory = msg.users or {}
    redraw()
    return
  end

  if msg.t == "system" then
    pushRoom(msg.room or config.DEFAULT_ROOM, ("[%s] * %s"):format(formatTs(msg.ts), tostring(msg.text or "")))
    redraw()
    return
  end

  if msg.t == "chat" then
    local room = msg.room or config.DEFAULT_ROOM
    local from = tostring(msg.from or "?")
    local name = tostring(msg.name or ("User-"..from))
    local text = tostring(msg.text or "")
    pushRoom(room, ("[%s] %s(#%s): %s"):format(formatTs(msg.ts), name, from, text))
    redraw()
    return
  end

  if msg.t == "dm" then
    local from = msg.from
    local to = msg.to
    local name = tostring(msg.name or ("User-"..tostring(from)))
    local text = tostring(msg.text or "")
    local peer
if state.call ~= nil and state.call == from then
  peer = to
else
  peer = from
end
    pushPeer(peer, ("[%s] %s(#%s): %s"):format(formatTs(msg.ts), name, tostring(from), text))
    redraw()
    return
  end

  if msg.t == "name_ok" then
    state.status = "Name set."
    redraw()
    return
  end
end

local function connect(redraw)
  ensureDeviceId()

  state.status = "Connecting..."
  redraw()

  if state.ws then pcall(function() state.ws.close() end) end
  state.ws = nil
  state.connected = false
  state.call = nil

  local ws
  local ok, err = pcall(function() ws = http.websocket(config.URL) end)
  if not ok or not ws then
    state.status = "Connect failed: "..tostring(err)
    redraw()
    return false
  end

  state.ws = ws
  state.connected = true
  state.status = "Connected. Identifying..."
  redraw()

  local name = state.name or getSavedName()
  wsSend({ t="identify", deviceId=getDeviceId(), name=name })

  return true
end

local function netLoop(redraw)
  while true do
    if not state.connected or not state.ws then
      os.sleep(0.2)
    else
      local ok, msg = pcall(function() return state.ws.receive() end)
      if not ok then
        state.status = "Socket error. Reconnecting..."
        state.connected = false
        redraw()
        os.sleep(0.5)
        connect(redraw)
      elseif msg then
        local decoded = jdecode(msg)
        if decoded then onServerMsg(decoded, redraw) end
      else
        state.status = "Disconnected. Reconnecting..."
        state.connected = false
        redraw()
        os.sleep(0.5)
        connect(redraw)
      end
    end
  end
end

return {
  wsSend = wsSend,
  connect = connect,
  netLoop = netLoop,
  setSavedName = setSavedName,
  setLastPeer = setLastPeer
}
