// public/js/net/wsClient.js
// Web WS client for VibeChat protocol (deviceId identify)

function safeJson(s) {
  try { return JSON.parse(String(s)); } catch { return null; }
}

export class WSClient {
  constructor({ onEvent }) {
    this.ws = null;
    this.connected = false;

    this.deviceId = null;
    this.name = null;

    this.call = 0;
    this.room = "#lobby";

    this.onEvent = onEvent; // (evt, payload) => void
  }

  url() {
    const proto = location.protocol === "https:" ? "wss:" : "ws:";
    return `${proto}//${location.host}/ws`;
  }

  connect({ deviceId, name }) {
    this.deviceId = String(deviceId || "");
    this.name = String(name || "");

    if (!this.deviceId) throw new Error("wsClient.connect: missing deviceId");

    if (this.ws && (this.ws.readyState === WebSocket.OPEN || this.ws.readyState === WebSocket.CONNECTING)) {
      return;
    }

    this.ws = new WebSocket(this.url());

    this.ws.onopen = () => {
      this.connected = true;
      this.onEvent?.("status", { connected: true });

      // IMPORTANT: identify by deviceId (NOT call/key)
      this.send({ t: "identify", deviceId: this.deviceId, name: this.name });
    };

    this.ws.onmessage = (ev) => {
      const msg = safeJson(ev.data);
      if (!msg || typeof msg.t !== "string") return;

      // Server sends hello twice sometimes:
      // 1) placeholder (no call)
      // 2) assigned (has call + defaultRoom)
      if (msg.t === "hello") {
        const call = Number(msg.call || 0) || 0;
        if (call > 0 && call !== this.call) {
          this.call = call;

          if (typeof msg.defaultRoom === "string" && msg.defaultRoom.trim()) {
            this.room = msg.defaultRoom.trim();
          }

          // Auto-join AFTER we have a call
          this.send({ t: "join", room: this.room });
          this.send({ t: "directory" });
          this.send({ t: "history", room: this.room, limit: 200 }); // server may ignore

          this.onEvent?.("hello", { call: this.call, room: this.room, raw: msg });
        }
        return;
      }

      if (msg.t === "directory") {
        this.onEvent?.("directory", { users: Array.isArray(msg.users) ? msg.users : [] });
        return;
      }

      if (msg.t === "system") {
        this.onEvent?.("system", msg);
        return;
      }

      if (msg.t === "chat") {
        this.onEvent?.("chat", msg);
        return;
      }

      if (msg.t === "dm") {
        this.onEvent?.("dm", msg);
        return;
      }

      if (msg.t === "history") {
        // support either {items:[...]} or {messages:[...]}
        const items = Array.isArray(msg.items) ? msg.items : Array.isArray(msg.messages) ? msg.messages : [];
        this.onEvent?.("history", { items });
        return;
      }

      if (msg.t === "identify_fail") {
        this.onEvent?.("error", { error: "identify_fail", detail: msg.error || "unknown" });
        return;
      }

      if (msg.t === "error") {
        this.onEvent?.("error", { error: msg.error || "unknown" });
        return;
      }
    };

    this.ws.onclose = () => {
      this.connected = false;
      this.onEvent?.("status", { connected: false });
    };

    this.ws.onerror = () => {
      this.connected = false;
      this.onEvent?.("status", { connected: false });
    };
  }

  send(obj) {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) return false;
    this.ws.send(JSON.stringify(obj));
    return true;
  }

  join(room) {
    const r = String(room || "").trim();
    if (!r) return false;
    this.room = r;
    return this.send({ t: "join", room: r });
  }

  chat(room, text) {
    const r = String(room || this.room || "#lobby").trim();
    const t = String(text || "");
    if (!t.trim()) return false;
    return this.send({ t: "chat", room: r, text: t });
  }

  dm(to, text) {
    const n = Number(to || 0) || 0;
    const t = String(text || "");
    if (!n || !t.trim()) return false;
    return this.send({ t: "dm", to: n, text: t });
  }
}
