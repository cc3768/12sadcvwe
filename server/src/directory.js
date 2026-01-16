const { clients } = require("./state");

function directorySnapshot() {
  const list = [];
  for (const [, info] of clients.entries()) {
    list.push({
      call: info.call,
      name: info.name || ("User-" + info.call),
      rooms: Array.from(info.rooms),
      online: true
    });
  }
  list.sort((a, b) => a.call - b.call);
  return list;
}

function broadcastDirectory(WebSocket, send) {
  const snap = directorySnapshot();
  for (const ws of clients.keys()) send(ws, { t: "directory", users: snap }, WebSocket);
}

module.exports = { directorySnapshot, broadcastDirectory };
