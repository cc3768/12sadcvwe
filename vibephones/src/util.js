function nowMs() { return Date.now(); }

function safeJsonParse(s) {
  try { return JSON.parse(s); } catch { return null; }
}

function send(ws, obj, WebSocket) {
  if (!ws || ws.readyState !== WebSocket.OPEN) return;
  ws.send(JSON.stringify(obj));
}

module.exports = { nowMs, safeJsonParse, send };
