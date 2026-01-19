const { nowMs, safeJsonParse, send } = require("./util");
const { getClient } = require("./state");
const { joinRoom, broadcastRoom } = require("./rooms");
const { broadcastDirectory } = require("./directory");

function handleMessage(ws, data, WebSocket) {
  const msg = safeJsonParse(String(data));
  if (!msg || typeof msg.t !== "string") return;

  const info = getClient(ws);
  if (!info) return;

  if (msg.t === "join") {
    const room = String(msg.room || "#lobby");
    joinRoom(ws, room);
    send(ws, { t: "system", room, text: `Joined ${room}`, ts: nowMs() }, WebSocket);
    return;
  }

  if (msg.t === "set_name") {
    const nm = String(msg.name || "").trim().slice(0, 24);
    info.name = nm || info.name;
    send(ws, { t: "name_ok" }, WebSocket);
    broadcastDirectory(WebSocket, send);
    return;
  }

  if (msg.t === "chat") {
    const room = String(msg.room || "#lobby");
    const text = String(msg.text || "");
    broadcastRoom(room, {
      t: "chat",
      room,
      from: info.call,
      name: info.name || `User-${info.call}`,
      text,
      ts: nowMs()
    }, WebSocket, send);
    return;
  }

  if (msg.t === "dm") {
    const to = Number(msg.to);
    if (!Number.isFinite(to)) return;
    const text = String(msg.text || "");

    // naive: send to all; receiver filters by call (simple)
    for (const c of require("./state").allClients()) {
      if (c.call === to || c.call === info.call) {
        send(c.ws, {
          t: "dm",
          from: info.call,
          to,
          name: info.name || `User-${info.call}`,
          text,
          ts: nowMs()
        }, WebSocket);
      }
    }
    return;
  }
}

module.exports = { handleMessage };
