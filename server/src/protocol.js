const { nowMs, safeJsonParse, send } = require("./util");
const { getClient, getWsByCall } = require("./state");
const { joinRoom, leaveRoom, broadcastRoom } = require("./rooms");
const { broadcastDirectory } = require("./directory");

// NOTE: Identify is handled in app.js. This file handles post-identification messages.
function handleMessage(ws, raw, WebSocket) {
  const msg = safeJsonParse(String(raw));
  if (!msg || typeof msg.t !== "string") return;

  const info = getClient(ws);
  if (!info) return;

  if (msg.t === "set_name") {
    const name = (msg.name || "").toString().trim().slice(0, 24);
    info.name = name.length ? name : null;
    send(ws, { t: "name_ok", name: info.name || ("User-" + info.call) }, WebSocket);
    broadcastDirectory(WebSocket, send);
    return;
  }

  if (msg.t === "join") {
    const room = (msg.room || "").toString().trim();
    if (!joinRoom(ws, room)) return;
    send(ws, { t: "joined", room }, WebSocket);
    broadcastDirectory(WebSocket, send);
    broadcastRoom(room, { t: "system", room, text: `User ${info.call} joined ${room}.`, ts: nowMs() }, WebSocket, send);
    return;
  }

  if (msg.t === "leave") {
    const room = (msg.room || "").toString().trim();
    if (room === "#lobby") return;
    if (!leaveRoom(ws, room)) return;
    send(ws, { t: "left", room }, WebSocket);
    broadcastDirectory(WebSocket, send);
    broadcastRoom(room, { t: "system", room, text: `User ${info.call} left ${room}.`, ts: nowMs() }, WebSocket, send);
    return;
  }

  if (msg.t === "chat") {
    const room = (msg.room || "").toString().trim();
    const text = (msg.text || "").toString().trim().slice(0, 240);
    if (!room.startsWith("#") || !text.length) return;
    if (!info.rooms.has(room)) return;

    broadcastRoom(room, {
      t: "chat",
      room,
      from: info.call,
      name: info.name || ("User-" + info.call),
      text,
      ts: nowMs()
    }, WebSocket, send);
    return;
  }

  if (msg.t === "dm") {
    const to = Number(msg.to);
    const text = (msg.text || "").toString().trim().slice(0, 240);
    if (!Number.isFinite(to) || !text.length) return;

    const target = getWsByCall(to);
    const payload = {
      t: "dm",
      from: info.call,
      name: info.name || ("User-" + info.call),
      to,
      text,
      ts: nowMs()
    };

    send(ws, payload, WebSocket);
    if (target && target !== ws) send(target, payload, WebSocket);
    return;
  }
}

module.exports = { handleMessage };
