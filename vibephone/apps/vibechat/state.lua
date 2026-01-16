local config = require("config")

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
