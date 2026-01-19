// public/js/chat.js

function safeNum(n, d = 0) {
  const x = Number(n);
  return Number.isFinite(x) ? x : d;
}

function escapeHtml(s) {
  return String(s ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function ensureChatState(state) {
  state.chat = state.chat || {};
  if (!state.chat.room) state.chat.room = "#lobby";
  if (!Array.isArray(state.chat.rooms)) state.chat.rooms = [state.chat.room];
  if (!state.chat.rooms.includes(state.chat.room)) state.chat.rooms.unshift(state.chat.room);
  if (!Array.isArray(state.chat.messages)) state.chat.messages = [];
  if (!Array.isArray(state.chat.directory)) state.chat.directory = [];
  state.chat.dmTarget = safeNum(state.chat.dmTarget, 0);
}

function el(tag, attrs = {}, children = []) {
  const n = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === "class") n.className = v;
    else if (k === "style") n.setAttribute("style", v);
    else if (k.startsWith("on") && typeof v === "function") n.addEventListener(k.slice(2), v);
    else n.setAttribute(k, v);
  }
  for (const c of children) n.appendChild(typeof c === "string" ? document.createTextNode(c) : c);
  return n;
}

function paintRooms(state, roomsEl, ws, render) {
  roomsEl.innerHTML = "";
  state.chat.rooms.forEach((r) => {
    const b = el("button", { class: "listBtn" + (!state.chat.dmTarget && state.chat.room === r ? " active" : "") }, [r]);
    b.onclick = () => {
      state.chat.dmTarget = 0;
      state.chat.room = r;
      ws.send({ t: "join", room: r });
      ws.send({ t: "history", room: r, limit: 100 });
      render();
    };
    roomsEl.appendChild(b);
  });
}

function paintDirectory(state, dirEl, render) {
  dirEl.innerHTML = "";
  const me = safeNum(state.session.call, 0);
  const users = (state.chat.directory || [])
    .filter((u) => safeNum(u.call, 0) && safeNum(u.call, 0) !== me)
    .slice()
    .sort((a, b) => safeNum(a.call, 0) - safeNum(b.call, 0));

  users.forEach((u) => {
    const call = safeNum(u.call, 0);
    const name = u.name ? String(u.name) : `User-${call}`;
    const b = el("button", { class: "listBtn" + (state.chat.dmTarget === call ? " active" : "") }, [`${name} (${call})`]);
    b.onclick = () => {
      state.chat.dmTarget = call;
      render();
    };
    dirEl.appendChild(b);
  });
}

function paintMessages(state, msgsEl) {
  msgsEl.innerHTML = "";

  const me = safeNum(state.session.call, 0);
  const room = state.chat.room;
  const dm = safeNum(state.chat.dmTarget, 0);

  const filtered = (state.chat.messages || []).filter((m) => {
    if (!m) return false;
    if (m.t === "system") return true;
    if (dm) {
      if (m.t !== "dm") return false;
      const from = safeNum(m.from, 0);
      const to = safeNum(m.to, 0);
      const other = from === me ? to : from;
      return other === dm;
    }
    if (m.t !== "chat") return false;
    return String(m.room || "") === String(room || "");
  });

  filtered.slice(-200).forEach((m) => {
    const who = m.t === "system" ? "system" : (m.name || `#${m.from}`);
    const ts = m.ts ? new Date(m.ts).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }) : "";
    const bubble = el("div", { class: "msg" + (safeNum(m.from, 0) === me ? " me" : "") }, []);
    bubble.innerHTML = `
      <div class="meta">
        <div class="who">${escapeHtml(who)}</div>
        <div class="when">${escapeHtml(ts)}</div>
      </div>
      <div class="body">${escapeHtml(String(m.text || ""))}</div>
    `;
    msgsEl.appendChild(bubble);
  });

  msgsEl.scrollTop = msgsEl.scrollHeight;
}

function pushLocal(state, m) {
  state.chat.messages = state.chat.messages || [];
  state.chat.messages.push({
    t: m.t,
    ts: m.ts || Date.now(),
    room: m.room,
    from: m.from,
    to: m.to,
    name: m.name,
    text: m.text || "",
  });
  if (state.chat.messages.length > 1000) {
    state.chat.messages.splice(0, state.chat.messages.length - 1000);
  }
}

function ensureReady(ws, state) {
  // IMPORTANT:
  // This view can be re-rendered often (e.g., on incoming WS messages).
  // Do NOT spam "join"/"history" on every render.
  // App-level WSClient already identifies on open and auto-joins once on server "hello".

  if (!ws.connected) return;

  const room = state.chat.room || "#lobby";
  if (ws.__chatReadyRoom === room && ws.__chatReadyConnected === true) return;

  ws.__chatReadyRoom = room;
  ws.__chatReadyConnected = true;

  ws.send({ t: "directory" });
  ws.send({ t: "history", room, limit: 100 });
}

export function viewChat({ shell, state, ws, render }) {
  ensureChatState(state);

  shell.setHeader({
    title: "VibeChat",
    sub: state.chat.dmTarget ? `DM #${state.chat.dmTarget}` : state.chat.room,
    pillText: ws.connected ? "connected" : "disconnected",
    pillOk: ws.connected,
  });

  const root = el("div", { class: "chatWrap" }, [
    el("div", { class: "chatTopRow" }, [
      el("div", { class: "card chatRooms" }, [
        el("div", { class: "cardTitle" }, ["Rooms"]),
        el("div", { class: "list", id: "rooms" }, []),
        el("div", { class: "joinRow" }, [
          el("input", { id: "roomIn", placeholder: "#room" }, []),
          el("button", { id: "joinBtn", class: "primary" }, ["Join"]),
        ]),
      ]),
      el("div", { class: "card chatDirectory" }, [
        el("div", { class: "cardTitle" }, ["Contacts"]),
        el("div", { class: "list", id: "dir" }, []),
        el("div", { class: "hint" }, ["Click a user to DM."]),
      ]),
    ]),
    el("div", { class: "messages card scroll", id: "msgs" }, []),
    el("div", { class: "composer" }, [
      el("input", { id: "msgIn", placeholder: "Message…" }, []),
      el("button", { id: "sendBtn", class: "primary" }, ["Send"]),
    ]),
  ]);

  shell.mount(root);

  const roomsEl = root.querySelector("#rooms");
  const dirEl = root.querySelector("#dir");
  const msgsEl = root.querySelector("#msgs");
  const roomIn = root.querySelector("#roomIn");
  const joinBtn = root.querySelector("#joinBtn");
  const msgIn = root.querySelector("#msgIn");
  const sendBtn = root.querySelector("#sendBtn");

  const doPaint = () => {
    paintRooms(state, roomsEl, ws, render);
    paintDirectory(state, dirEl, render);
    paintMessages(state, msgsEl);
  };

  // Ensure WS is active
  ensureReady(ws, state);

  // Join button
  joinBtn.onclick = () => {
    let r = String(roomIn.value || "").trim();
    if (!r) return;
    if (!r.startsWith("#")) r = "#" + r;
    if (!state.chat.rooms.includes(r)) state.chat.rooms.unshift(r);
    state.chat.dmTarget = 0;
    state.chat.room = r;
    ws.send({ t: "join", room: r });
    ws.send({ t: "history", room: r, limit: 100 });
    render();
  };

  // Send
  const send = () => {
    const text = String(msgIn.value || "");
    if (!text.trim()) return;
    msgIn.value = "";

    const me = safeNum(state.session.call, 0);
    const meName = state.session.name || "User";

    if (safeNum(state.chat.dmTarget, 0)) {
      const to = safeNum(state.chat.dmTarget, 0);
      ws.send({ t: "dm", to, text });
      // optimistic UI
      pushLocal(state, { t: "dm", from: me, to, name: meName, text, ts: Date.now() });
      render();
      return;
    }

    ws.send({ t: "chat", room: state.chat.room, text });
    // optimistic UI
    pushLocal(state, { t: "chat", room: state.chat.room, from: me, name: meName, text, ts: Date.now() });
    render();
  };

  sendBtn.onclick = send;
  msgIn.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      send();
    }
  });

  // Initial paint
  doPaint();
}
