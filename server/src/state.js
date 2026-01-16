const { loadCalls, saveCalls } = require("./persist");

// Live connections
const clients = new Map(); // ws -> { call, name, rooms:Set, deviceId }
const byCall = new Map();  // call -> ws
const rooms = new Map();   // room -> Set<ws>

// Persistent call assignments
const persisted = loadCalls(); // { nextCall, byDevice }

function getOrAssignCall(deviceId) {
  if (deviceId && persisted.byDevice[deviceId]) return persisted.byDevice[deviceId];

  const call = persisted.nextCall++;
  if (deviceId) persisted.byDevice[deviceId] = call;

  saveCalls(persisted);
  return call;
}

function addClient(ws, call, deviceId) {
  clients.set(ws, { call, name: null, rooms: new Set(), deviceId: deviceId || null });
  byCall.set(call, ws);
}

function removeClient(ws) {
  const info = clients.get(ws);
  if (!info) return null;

  for (const room of info.rooms) {
    const set = rooms.get(room);
    if (set) {
      set.delete(ws);
      if (set.size === 0) rooms.delete(room);
    }
  }

  clients.delete(ws);
  byCall.delete(info.call);
  return info;
}

function getClient(ws) { return clients.get(ws) || null; }
function getWsByCall(call) { return byCall.get(call) || null; }

module.exports = {
  clients, byCall, rooms,
  getOrAssignCall,
  addClient, removeClient,
  getClient, getWsByCall
};
