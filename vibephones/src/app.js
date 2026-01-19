// src/app.js (ESM) - WS server entry
import "dotenv/config";
import { WebSocketServer } from "ws";
import { makeServer } from "./serverFactory.js";

// If you have your protocol/registry modules, import and wire them here.
// Keeping it minimal + reliable: WS comes up and responds.
const { app, server, port } = makeServer();

const wss = new WebSocketServer({ server });

wss.on("connection", (ws) => {
  ws.send(JSON.stringify({ t: "hello", ok: true }));

  ws.on("message", (buf) => {
    let msg;
    try {
      msg = JSON.parse(buf.toString());
    } catch {
      ws.send(JSON.stringify({ t: "error", error: "bad_json" }));
      return;
    }

    // TODO: plug in your real handlers (identify/identify_call/chat/etc)
    ws.send(JSON.stringify({ t: "echo", ok: true, msg }));
  });
});

server.listen(port, "0.0.0.0", () => {
  console.log(`[ws] listening on ${port}`);
});
