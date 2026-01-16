const { rooms, getClient } = require("./state");

function joinRoom(ws, room) {
  if (!room || !room.startsWith("#")) return false;
  const info = getClient(ws);
  if (!info) return false;

  let set = rooms.get(room);
  if (!set) { set = new Set(); rooms.set(room, set); }

  set.add(ws);
  info.rooms.add(room);
  return true;
}

function leaveRoom(ws, room) {
  const info = getClient(ws);
  if (!info || !info.rooms.has(room)) return false;

  const set = rooms.get(room);
  if (set) {
    set.delete(ws);
    if (set.size === 0) rooms.delete(room);
  }
  info.rooms.delete(room);
  return true;
}

function broadcastRoom(room, payload, WebSocket, send) {
  const set = rooms.get(room);
  if (!set) return;
  for (const w of set) send(w, payload, WebSocket);
}

module.exports = { joinRoom, leaveRoom, broadcastRoom };
