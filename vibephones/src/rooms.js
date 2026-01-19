const { getClient, allClients } = require("./state");

const rooms = new Map(); // room -> Set<ws>

function joinRoom(ws, room) {
  room = String(room || "");
  if (!room.startsWith("#")) room = "#" + room;
  if (!rooms.has(room)) rooms.set(room, new Set());
  rooms.get(room).add(ws);

  const info = getClient(ws);
  if (info) info.rooms.add(room);
}

function leaveAll(ws) {
  for (const set of rooms.values()) set.delete(ws);
}

function broadcastRoom(room, payload, WebSocket, send) {
  const set = rooms.get(room);
  if (!set) return;
  for (const ws of set) {
    send(ws, payload, WebSocket);
  }
}

module.exports = { joinRoom, leaveAll, broadcastRoom };
