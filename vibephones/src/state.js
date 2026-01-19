// Tracks currently connected clients (in-memory only).

const byWs = new Map();

function addClient(ws, call, deviceId, name) {
  const info = {
    ws,
    call,
    deviceId: deviceId || null,
    name: name || null,
    rooms: new Set(),
    kind: "unknown" // 'computer' | 'web'
  };
  byWs.set(ws, info);
  return info;
}

function removeClient(ws) {
  const info = byWs.get(ws);
  byWs.delete(ws);
  return info || null;
}

function getClient(ws) { return byWs.get(ws) || null; }
function allClients() { return Array.from(byWs.values()); }

module.exports = { addClient, removeClient, getClient, allClients };
