// index.js (main server file) - copy/paste
const WebSocket = require("ws");
const { makeServer } = require("./serverFactory");
const { nowMs, send, safeJsonParse } = require("./util");
const { getOrAssignCall, addClient, removeClient, getClient } = require("./state");
const { joinRoom, broadcastRoom } = require("./rooms");
const { broadcastDirectory } = require("./directory");
const { handleMessage } = require("./protocol");

// IMPORTANT: appstore module must export BOTH AppStore and registerAppStore
const { AppStore, registerAppStore } = require("./appstore");

// ---- your current in-memory AppStore payload ----
const APPSTORE = new AppStore([
  {
    id: "vibechat",
    name: "VibeChat",
    version: "1.0.0",
    description: "Realtime chat + DMs (client bundle).",
    installBase: "/vcchat",
    files: {
      "config.lua": `local config = {}

config.URL = "ws://192.168.5.2:8080" -- change as needed
config.DEFAULT_ROOM = "#lobby"

config.LOG_LIMIT = 200
config.MAX_TEXT = 240

config.QUICK_ROOMS = { "#lobby", "#general", "#trade" }

config.SETTINGS_PATH = "/vcchat/settings.json"

return config
`,
      "state.lua": `local config = require("config")

local state = {
  ws = nil,
  connected = false,
  status = "Starting...",

  call = nil,
  name = nil,

  tab = "chat",          -- chat | dm | contacts | settings
  room = config.DEFAULT_ROOM,
  rooms = { config.DEFAULT_ROOM },

  directory = {},

  chatLogByRoom = {},
  dmLogByPeer = {},
  activePeer = nil,

  input = "",
  scroll = 0
}

local function ensureRoom(room)
  if not state.chatLogByRoom[room] then state.chatLogByRoom[room] = {} end
end

local function pushRoom(room, line)
  ensureRoom(room)
  local log = state.chatLogByRoom[room]
  log[#log+1] = line
  if #log > (config.LOG_LIMIT or 200) then table.remove(log, 1) end
end

local function ensurePeer(peer)
  peer = tostring(peer)
  if not state.dmLogByPeer[peer] then state.dmLogByPeer[peer] = {} end
end

local function pushPeer(peer, line)
  peer = tostring(peer)
  ensurePeer(peer)
  local log = state.dmLogByPeer[peer]
  log[#log+1] = line
  if #log > (config.LOG_LIMIT or 200) then table.remove(log, 1) end
end

return {
  state = state,
  ensureRoom = ensureRoom,
  pushRoom = pushRoom,
  ensurePeer = ensurePeer,
  pushPeer = pushPeer
}
`,
      "net.lua": `local config = require("config")
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
    state.call = msg.call
    setCall(msg.call)

    state.room = msg.defaultRoom or config.DEFAULT_ROOM
    state.status = "Assigned call #" .. tostring(state.call) .. (msg.temporary and " (TEMP)" or "")
    pushRoom(state.room, ("[%s] * assigned call #%d"):format(formatTs(msg.serverTime), state.call))

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
    local peer = (state.call == from) and to or from
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
`,
      "ui.lua": `-- unchanged (your existing ui.lua)`,
      "main.lua": `-- unchanged (your existing main.lua)`
    }
  },
  {
    id: "calculator",
    name: "Calculator",
    version: "1.0.0",
    description: "Simple calculator app (stub).",
    installBase: "/vibephone/apps/calculator",
    files: { "app.lua": 'print("Calculator from AppStore (placeholder)")\\nos.pullEvent("key")\\n' }
  },
  {
    id: "controller",
    name: "Controller",
    version: "1.0.0",
    description: "Controller app (stub).",
    installBase: "/vibephone/apps/controller",
    files: { "app.lua": 'print("Controller from AppStore (placeholder)")\\nos.pullEvent("key")\\n' }
  }
]);

// ---- server + ws ----
const { app, server, port, directWss } = makeServer();
const wss = new WebSocket.Server({ server });

// ✅ registers HTTP endpoints for AppStore (and optional WS helpers, depending on your appstore.js)
registerAppStore(app, wss, APPSTORE);

// ---- identify fallback ----
function identifyOrTemp(ws) {
  const tempCall = Math.floor(900000 + Math.random() * 90000);
  addClient(ws, tempCall, null);
  joinRoom(ws, "#lobby");
  send(ws, { t: "hello", call: tempCall, defaultRoom: "#lobby", serverTime: nowMs(), temporary: true }, WebSocket);
  broadcastRoom("#lobby", { t: "system", room: "#lobby", text: `User ${tempCall} joined.`, ts: nowMs() }, WebSocket, send);
  broadcastDirectory(WebSocket, send);
}

wss.on("connection", (ws) => {
  let identified = false;

  const timer = setTimeout(() => {
    if (!identified && !getClient(ws)) identifyOrTemp(ws);
  }, 5000);

  ws.on("message", (data) => {
    const msg = safeJsonParse(String(data));
    if (!msg || typeof msg.t !== "string") return;

    // AppStore calls are allowed even before identify
    if (msg.t === "apps_list" || msg.t === "app_fetch") {
      APPSTORE.handle(ws, msg, WebSocket);
      return;
    }

    if (!identified && msg.t === "identify") {
      identified = true;
      clearTimeout(timer);

      const deviceId = (msg.deviceId || "").toString().trim().slice(0, 80);
      const call = getOrAssignCall(deviceId || null);

      addClient(ws, call, deviceId || null);
      joinRoom(ws, "#lobby");

      const info = getClient(ws);
      const nm = (msg.name || "").toString().trim().slice(0, 24);
      if (info && nm.length) info.name = nm;

      send(ws, { t: "hello", call, defaultRoom: "#lobby", serverTime: nowMs(), temporary: false }, WebSocket);
      broadcastRoom("#lobby", { t: "system", room: "#lobby", text: `User ${call} joined.`, ts: nowMs() }, WebSocket, send);
      broadcastDirectory(WebSocket, send);
      return;
    }

    if (!getClient(ws)) return;
    handleMessage(ws, data, WebSocket);
  });

  ws.on("close", () => {
    clearTimeout(timer);
    const info = removeClient(ws);
    if (!info) return;

    broadcastRoom("#lobby", { t: "system", room: "#lobby", text: `User ${info.call} disconnected.`, ts: nowMs() }, WebSocket, send);
    broadcastDirectory(WebSocket, send);
  });
});

server.listen(port, "0.0.0.0", () => {
  console.log(`${directWss ? "WSS" : "WS"} server listening on :${port}`);
  console.log("AppStore: apps_list/app_fetch available over same socket.");
  console.log("AppStore HTTP: /api/apps , /api/apps/:id/manifest , /api/apps/:id/file/<path>");
});
