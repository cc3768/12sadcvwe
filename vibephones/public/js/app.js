// public/js/app.js
import { readIdentityCookie, writeIdentity, applyIdentityToState, storageKey, deleteIdentityCookie } from "./lib/identity.js";
import { createShell } from "./ui/phoneShell.js";

// Views (must exist at these paths)
import { viewHome } from "./home.js";
import { viewChat } from "./chat.js";
import { viewContacts } from "./contacts.js";
import { viewNotes } from "./notes.js";
import { viewCalc } from "./calc.js";
import { viewPhoneKey } from "./phoneKey.js";
import { viewStatus } from "./status.js";
import { viewSettings } from "./setting.js";
import { viewAbout } from "./about.js";

// ---------- state ----------
const state = {
  nav: "home",
  session: {
    call: 0,
    key: null,
    webSecret: null,
    name: "User",
    deviceId: null,
    email: null,
  },
  chat: {
    room: "#lobby",
    dmTarget: 0,
    messages: [],
    directory: [],
    rooms: ["#lobby"],
  },
  setSession(patch) {
    this.session = { ...this.session, ...patch };
    persistSession();
  },
};

// ---------- render scheduler (prevents rapid full re-renders) ----------
let _renderPending = false;
function requestRender() {
  if (_renderPending) return;
  _renderPending = true;
  requestAnimationFrame(() => {
    _renderPending = false;
    doRender();
  });
}

// ---------- shell (persistent; prevents full-page remount flicker) ----------
const rootEl = document.getElementById("root");
const shell = createShell({
  root: rootEl,
  state,
  onNavigate: (to) => {
    state.nav = to;
    requestRender();
  },
  onBack: () => {
    state.nav = "home";
    requestRender();
  },
});



// ---------- persistence ----------
function persistSession() {
  if (!state.session.call) return;
  try {
    localStorage.setItem(storageKey(state.session.call, "session"), JSON.stringify({
      name: state.session.name,
      room: state.chat.room,
      dmTarget: state.chat.dmTarget,
    }));
  } catch {}
}

function loadPersistedForCall(call) {
  try {
    const raw = localStorage.getItem(storageKey(call, "session"));
    if (raw) {
      const obj = JSON.parse(raw);
      if (obj && typeof obj === "object") {
        if (obj.name) state.session.name = String(obj.name);
        if (obj.room) state.chat.room = String(obj.room);
        if (obj.dmTarget) state.chat.dmTarget = Number(obj.dmTarget) || 0;
      }
    }
  } catch {}
}

function persistMessages() {
  const call = state.session.call;
  if (!call) return;
  try {
    // keep last 200
    const msgs = (state.chat.messages || []).slice(-200);
    localStorage.setItem(storageKey(call, "messages"), JSON.stringify(msgs));
  } catch {}
}

function loadMessages(call) {
  try {
    const raw = localStorage.getItem(storageKey(call, "messages"));
    if (!raw) return [];
    const arr = JSON.parse(raw);
    return Array.isArray(arr) ? arr : [];
  } catch {
    return [];
  }
}

function persistDirectory() {
  const call = state.session.call;
  if (!call) return;
  try {
    localStorage.setItem(storageKey(call, "directory"), JSON.stringify(state.chat.directory || []));
  } catch {}
}

function loadDirectory(call) {
  try {
    const raw = localStorage.getItem(storageKey(call, "directory"));
    if (!raw) return [];
    const arr = JSON.parse(raw);
    return Array.isArray(arr) ? arr : [];
  } catch {
    return [];
  }
}

// ---------- websocket client ----------
class WSClient {
  constructor() {
    this.ws = null;
    this.connected = false;
    this._url = null;
    this._lastCreds = null;

    // Prevent repeated "join" spam if the server sends multiple hello frames.
    // We only auto-join a room once per assigned call number.
    this._helloCall = 0;
    this._joinedRooms = new Set();
  }

  url() { return this._url || ""; }

  _applyHello(msg) {
    // Server assigns call number here. If we were at call=0, switch persistence namespace.
    const newCall = Number(msg.call || 0) || 0;
    if (!newCall) return;

    // If we've already processed a hello for this call and already joined the current room,
    // do not re-join (prevents "Joined #lobby" spam).
    if (this._helloCall === newCall && this._joinedRooms.has(state.chat.room || "#lobby")) {
      return;
    }

    const oldCall = Number(state.session.call || 0) || 0;

    state.session.call = newCall;

    // Server may provide defaultRoom
    if (msg.defaultRoom && typeof msg.defaultRoom === "string") {
      state.chat.room = msg.defaultRoom;
    }

    // If we just transitioned from 0 -> assigned, load persisted history for that call
    if (!oldCall || oldCall !== newCall) {
      loadPersistedForCall(newCall);
      state.chat.messages = loadMessages(newCall);
      state.chat.directory = loadDirectory(newCall);
    }

    // Ensure room string is normalized (always starts with '#')
    if (state.chat.room && typeof state.chat.room === "string" && !state.chat.room.startsWith("#")) {
      state.chat.room = "#" + state.chat.room;
    }

    // Track visited rooms
    state.chat.rooms = state.chat.rooms || ["#lobby"];
    if (state.chat.room && !state.chat.rooms.includes(state.chat.room)) {
      state.chat.rooms.push(state.chat.room);
    }

    // Mark call as processed.
    this._helloCall = newCall;

    // Now that we have a real call number, join the room + request directory/history.
    // Only auto-join a room once per call number.
    const room = state.chat.room || "#lobby";
    if (!this._joinedRooms.has(room)) {
      this.send({ t: "join", room });
      this._joinedRooms.add(room);
    }
    this.send({ t: "directory" });
    this.send({ t: "history", room, limit: 200 });

    persistSession();
    requestRender();
  }

  connect(creds) {
    this._lastCreds = creds;

    const proto = location.protocol === "https:" ? "wss:" : "ws:";
    const host = location.host;

    // WS is mounted on /ws
    const url = `${proto}//${host}/ws`;
    this._url = url;

    try { if (this.ws) this.ws.close(); } catch {}
    this.ws = new WebSocket(url);

    this.ws.addEventListener("open", () => {
      this.connected = true;

      // IMPORTANT: identify by deviceId (call can be 0 until server assigns one)
      this.send({
        t: "identify",
        deviceId: creds.deviceId,
        name: creds.name || "User",
      });

      requestRender();
    });

    this.ws.addEventListener("close", () => {
      this.connected = false;
      requestRender();
    });

    this.ws.addEventListener("error", () => {
      this.connected = false;
      requestRender();
    });

    this.ws.addEventListener("message", (ev) => {
      let msg = null;
      try { msg = JSON.parse(String(ev.data)); } catch { return; }

      // Server hello assigns call + default room
      if (msg.t === "hello") {
        this._applyHello(msg);
        return;
      }

      // Directory payload is msg.users (not msg.items)
      if (msg.t === "directory" && Array.isArray(msg.users)) {
        state.chat.directory = msg.users;
        persistDirectory();
        requestRender();
        return;
      }

      if (msg.t === "system") {
        const item = {
          t: "system",
          at: msg.ts || Date.now(),
          room: msg.room || state.chat.room,
          text: msg.text || "",
        };
        state.chat.messages = state.chat.messages || [];
        state.chat.messages.push(item);
        persistMessages();
        requestRender();
        return;
      }

      if (msg.t === "chat" || msg.t === "dm" || msg.t === "message") {
        const item = {
          t: msg.t,
          at: msg.ts || msg.at || Date.now(),
          from: msg.from ?? msg.call ?? 0,
          to: msg.to ?? msg.dmTarget ?? 0,
          room: msg.room || state.chat.room,
          text: msg.text || msg.msg || "",
          name: msg.name || "",
        };
        state.chat.messages = state.chat.messages || [];
        state.chat.messages.push(item);
        persistMessages();
        requestRender();
        return;
      }

      // Optional: surface identify failures
      if (msg.t === "identify_fail") {
        state.chat.messages = state.chat.messages || [];
        state.chat.messages.push({
          t: "system",
          at: Date.now(),
          room: state.chat.room,
          text: `Identify failed: ${msg.error || "unknown"}`,
        });
        persistMessages();
        requestRender();
        return;
      }
    });
  }

  send(obj) {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) return false;
    this.ws.send(JSON.stringify(obj));
    return true;
  }

  setName(name) {
    if (!this._lastCreds) return;
    this._lastCreds.name = name;
    if (this.connected) this.send({ t: "set_name", name });
  }
}

const ws = new WSClient();

// ---------- router ----------
const views = {
  home: viewHome,
  chat: viewChat,
  contacts: viewContacts,
  notes: viewNotes,
  calc: viewCalc,
  phoneKey: viewPhoneKey,
  status: viewStatus,
  settings: viewSettings,
  about: viewAbout,
};

function doRender() {
  const view = views[state.nav] || views.home;
  view({ shell, state, ws, render: requestRender });
}

// ---------- identity hydration + auto-connect ----------
async function ensureIdentity() {
  let ident = readIdentityCookie();

  // If missing, try to provision from server session (no redirect loop).
  if (!ident) {
    try {
      const r = await fetch("/api/phone", { credentials: "include" });
      if (r.ok) {
        const j = await r.json();
        if (j && j.ok && j.phone) {
          ident = j.phone;
          writeIdentity(ident);
        }
      }
    } catch {}
  }

  if (!ident) {
    // Stay on the page and show PhoneKey view instead of hard-refreshing.
    state.nav = "phoneKey";
    return false;
  }

  applyIdentityToState(state, ident);

  // NOTE: call may be 0 until WS hello assigns it.
  if (state.session.call) {
    loadPersistedForCall(state.session.call);
    state.chat.messages = loadMessages(state.session.call);
    state.chat.directory = loadDirectory(state.session.call);
  }

  if (!ws.connected) {
    ws.connect({
      deviceId: state.session.deviceId,
      name: state.session.name,
    });
  }

  return true;
}

// ---------- global logout helper ----------
window.vibephoneLogout = async function vibephoneLogout() {
  try {
    await fetch("/auth/logout", { method: "POST", credentials: "include" });
  } catch {}
  try { deleteIdentityCookie(); } catch {}
  try {
    localStorage.removeItem(storageKey(state.session.call, "session"));
    localStorage.removeItem(storageKey(state.session.call, "messages"));
    localStorage.removeItem(storageKey(state.session.call, "directory"));
  } catch {}
  location.href = "/";
};

// ---------- boot ----------
(async function boot() {
  await ensureIdentity();
  requestRender();
})();
