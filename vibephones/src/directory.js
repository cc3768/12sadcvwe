const { allClients } = require("./state");

function broadcastDirectory(WebSocket, send) {
  const users = allClients().map(c => ({
    call: c.call,
    name: c.name || `User-${c.call}`
  }));

  const payload = { t: "directory", users };
  for (const c of allClients()) {
    send(c.ws, payload, WebSocket);
  }
}

module.exports = { broadcastDirectory };
