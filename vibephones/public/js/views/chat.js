// public/chat.js
import { WSClient } from "/js/net/wsClient.js";

function getCookie(name) {
  const parts = document.cookie.split(";").map((s) => s.trim());
  for (const p of parts) if (p.startsWith(name + "=")) return decodeURIComponent(p.slice(name.length + 1));
  return null;
}

function readIdentityCookie() {
  const raw = getCookie("vibephone.identity");
  if (!raw) return null;
  try { return JSON.parse(raw); } catch { return null; }
}

function ensureChatState(state) {
  state.chat = state.chat || {};
  state.chat.room = state.chat.room || "#lobby";
  state.chat.rooms = state.chat.rooms || ["#lobby"];
  state.chat.directory = state.chat.directory || [];
  state.chat.messages = state.chat.messages || [];
  state.chat.dmTarget = state.chat.dmTarget || null;
}

function escapeHtml(s) {
  return String(s ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function pushMessage(state, m) {
  state.chat.messages.push(m);
  if (state.chat.messages.length > 1000) state.chat.messages.splice(0, state.chat.messages.length - 1000);
}

export function viewChat({ shell, state, render }) {
  shell.setBackVisible(true);
  ensureChatState(state);

  const ident = readIdentityCookie();
  if (!ident?.deviceId) {
    shell.setHeader({ title: "VibeChat", sub: "Not linked", pillText: "login required", pillOk: false });
    const root = document.createElement("div");
    root.className = "chatWrap";
    root.innerHTML = `
      <div class="card" style="padding:16px;">
        <div style="font-weight:900; margin-bottom:6px;">Chat not linked</div>
        <div style="color:var(--muted); font-size:13px;">Open Phone first so the website provisions your deviceId.</div>
        <button id="goPhone" style="margin-top:12px; border:0; background:linear-gradient(180deg,#1c6cff,#1747d9); color:white; padding:10px 12px; border-radius:12px; font-weight:800;">Go to Phone</button>
      </div>
    `;
    shell.mount(root);
    root.querySelector("#goPhone").onclick = () => (location.href = "/phone.html");
    return;
  }

  // WS client singleton
  state._wsClient = state._wsClient || new WSClient({
    onEvent: (evt, payload) => {
      if (evt === "hello") {
        state.session = state.session || {};
        state.session.call = payload.call;
        if (shell?.setCall) shell.setCall(payload.call);

        // ensure room list includes server room
        if (payload.room && !state.chat.rooms.includes(payload.room)) state.chat.rooms.push(payload.room);
        state.chat.room = payload.room || state.chat.room;

        render();
        return;
      }

      if (evt === "directory") {
        state.chat.directory = payload.users || [];
        render();
        return;
      }

      if (evt === "system") {
        pushMessage(state, { kind: "system", ts: payload.ts || Date.now(), room: payload.room || state.chat.room, text: payload.text || "" });
        render();
        return;
      }

      if (evt === "chat") {
        pushMessage(state, {
          kind: "room",
          ts: payload.ts || Date.now(),
          room: payload.room || state.chat.room,
          from: payload.from,
          name: payload.name,
          text: payload.text || "",
        });
        render();
        return;
      }

      if (evt === "dm") {
        pushMessage(state, {
          kind: "dm",
          ts: payload.ts || Date.now(),
          from: payload.from,
          to: payload.to,
          name: payload.name,
          text: payload.text || "",
        });
        render();
        return;
      }

      if (evt === "history") {
        // optional server history
        (payload.items || []).forEach((x) => {
          if (x.t === "chat") pushMessage(state, { kind: "room", ts: x.ts || x.at || Date.now(), room: x.room, from: x.from, name: x.name, text: x.text || "" });
          else if (x.t === "dm") pushMessage(state, { kind: "dm", ts: x.ts || x.at || Date.now(), from: x.from, to: x.to, name: x.name, text: x.text || "" });
          else if (x.t === "system") pushMessage(state, { kind: "system", ts: x.ts || x.at || Date.now(), room: x.room, text: x.text || "" });
        });
        render();
        return;
      }

      if (evt === "error") {
        pushMessage(state, { kind: "system", ts: Date.now(), room: state.chat.room, text: `Server error: ${payload.detail || payload.error || "unknown"}` });
        render();
        return;
      }
    },
  });

  // connect (deviceId)
  state._wsClient.connect({ deviceId: ident.deviceId, name: ident.name || "User" });

  shell.setHeader({ title: "VibeChat", sub: state.chat.room, pillText: "connected", pillOk: true });

  const root = document.createElement("div");
  root.className = "chatWrap";
  root.innerHTML = `
    <div class="chatTopRow">
      <div class="card chatRooms">
        <div style="font-weight:900; margin-bottom:8px;">Rooms</div>
        <div class="list" id="rooms"></div>
        <div style="display:flex; gap:8px; margin-top:10px;">
          <input id="roomIn" placeholder="#room" style="flex:1; padding:10px; border-radius:12px; border:1px solid rgba(28,42,61,.9); background:rgba(11,18,32,.65); color:var(--text); outline:none;">
          <button id="join" style="border:0; background:linear-gradient(180deg,#1c6cff,#1747d9); color:white; padding:10px 12px; border-radius:12px; font-weight:800;">Join</button>
        </div>
      </div>

      <div class="card chatDirectory">
        <div style="font-weight:900; margin-bottom:8px;">Contacts</div>
        <div class="list" id="dir"></div>
        <div style="color:var(--muted); font-size:12px; margin-top:8px;">Click a user to DM.</div>
      </div>
    </div>

    <div class="messages card scroll" id="msgs"></div>

    <form class="composer" id="composer" autocomplete="off">
      <input id="msgIn" placeholder="Message…" autocomplete="off" />
      <button id="send" type="submit">Send</button>
    </form>
  `;
  shell.mount(root);

  const roomsEl = root.querySelector("#rooms");
  const dirEl = root.querySelector("#dir");
  const msgsEl = root.querySelector("#msgs");
  const msgIn = root.querySelector("#msgIn");

  function paint() {
    // rooms
    roomsEl.innerHTML = "";
    state.chat.rooms.forEach((r) => {
      const b = document.createElement("button");
      b.textContent = r;
      if (!state.chat.dmTarget && state.chat.room === r) b.classList.add("active");
      b.onclick = () => {
        state.chat.dmTarget = null;
        state.chat.room = r;
        state._wsClient.join(r);
        render();
      };
      roomsEl.appendChild(b);
    });

    // directory
    dirEl.innerHTML = "";
    (state.chat.directory || []).forEach((u) => {
      const b = document.createElement("button");
      b.textContent = `${u.name || ("User-" + u.call)} (${u.call})`;
      b.onclick = () => {
        state.chat.dmTarget = Number(u.call || 0) || null;
        render();
      };
      dirEl.appendChild(b);
    });

    // messages
    msgsEl.innerHTML = "";
    const me = Number(state.session?.call || 0) || 0;

    const filtered = (state.chat.messages || []).filter((m) => {
      if (m.kind === "system") return true;
      if (state.chat.dmTarget) {
        if (m.kind !== "dm") return false;
        const other = Number(m.from || 0) === me ? Number(m.to || 0) : Number(m.from || 0);
        return other === state.chat.dmTarget;
      }
      return m.kind === "room" && (m.room || "") === state.chat.room;
    });

    filtered.slice(-200).forEach((m) => {
      const who = m.kind === "system" ? "system" : (m.name || m.from);
      const when = new Date(m.ts || Date.now()).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
      const div = document.createElement("div");
      div.className = "msg" + (m.kind === "system" ? " system" : "");
      div.innerHTML = `
        <div class="meta"><div class="who">${escapeHtml(who)}</div><div class="when">${escapeHtml(when)}</div></div>
        <div class="body">${escapeHtml(m.text || "")}</div>
      `;
      msgsEl.appendChild(div);
    });

    msgsEl.scrollTop = msgsEl.scrollHeight;
  }

  // render hook
  const oldRender = render;
  render = () => { oldRender(); paint(); };
  paint();

  // join button
  root.querySelector("#join").onclick = () => {
    let room = String(root.querySelector("#roomIn").value || "").trim();
    if (!room) return;
    if (!room.startsWith("#")) room = "#" + room;
    if (!state.chat.rooms.includes(room)) state.chat.rooms.push(room);
    state.chat.dmTarget = null;
    state.chat.room = room;
    state._wsClient.join(room);
    paint();
  };

  // send (Enter works)
  root.querySelector("#composer").addEventListener("submit", (e) => {
    e.preventDefault();
    const text = String(msgIn.value || "");
    if (!text.trim()) return;
    msgIn.value = "";

    if (state.chat.dmTarget) {
      state._wsClient.dm(state.chat.dmTarget, text);
      pushMessage(state, { kind: "dm", ts: Date.now(), from: state.session?.call || 0, to: state.chat.dmTarget, name: ident.name, text });
      paint();
      return;
    }

    state._wsClient.chat(state.chat.room, text);
    pushMessage(state, { kind: "room", ts: Date.now(), room: state.chat.room, from: state.session?.call || 0, name: ident.name, text });
    paint();
  });

  setTimeout(() => msgIn.focus(), 0);
}
