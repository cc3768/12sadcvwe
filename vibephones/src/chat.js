// public/chat.js
// Chat UI that locks identity to the website-issued cookie and talks to WS.
// Cookie name: "vibephone.identity"
// cookie JSON: { call, key, deviceId, name, email }
//
// IMPORTANT CHANGE:
// - Identify by deviceId (NOT call/key).
// - call may be 0 until server sends hello with assigned call.

function getCookie(name) {
  const parts = document.cookie.split(";").map((s) => s.trim());
  for (const p of parts) {
    if (p.startsWith(name + "=")) return decodeURIComponent(p.slice(name.length + 1));
  }
  return null;
}

function readIdentityCookie() {
  const raw = getCookie("vibephone.identity");
  if (!raw) return null;
  try {
    const obj = JSON.parse(raw);
    if (!obj || typeof obj !== "object") return null;
    return obj;
  } catch {
    return null;
  }
}

function ensureLockedSessionFromCookie(state) {
  const ident = readIdentityCookie();
  state.session = state.session || {};

  // REQUIRE deviceId (source of truth)
  if (!ident || !ident.deviceId) {
    return { ok: false, reason: "missing_cookie" };
  }

  state.session.deviceId = String(ident.deviceId || "");
  state.session.name = String(ident.name || state.session.name || "User");
  state.session.email = ident.email ? String(ident.email) : null;

  // call can be 0 until server assigns it (hello)
  state.session.call = Number(ident.call || state.session.call || 0) || 0;

  return { ok: true, ident };
}

// ---- WS helpers (robust across different ws wrapper implementations) ----

function getUnderlyingSocket(ws) {
  return ws?.socket || ws?.ws || ws?._ws || ws?._socket || null;
}

function wsSend(ws, obj) {
  if (ws?.sendRaw) return ws.sendRaw(obj);
  if (ws?.send && typeof obj === "object") {
    // some wrappers accept objects directly
    try { return ws.send(obj); } catch {}
  }
  const sock = getUnderlyingSocket(ws);
  if (sock?.readyState === 1) return sock.send(JSON.stringify(obj));
  return false;
}

function safeNum(n, d = 0) {
  const x = Number(n);
  return Number.isFinite(x) ? x : d;
}

function nowTs(ms) {
  return typeof ms === "number" ? ms : Date.now();
}

function ensureChatState(state) {
  state.chat = state.chat || {};
  state.chat.room = state.chat.room || "#lobby";
  state.chat.rooms = state.chat.rooms || ["#lobby"];
  state.chat.directory = state.chat.directory || [];
  state.chat.messages = state.chat.messages || [];
  state.chat.dmTarget = state.chat.dmTarget || null;
}

function upsertDirectory(state, entry) {
  if (!entry) return;
  ensureChatState(state);
  const call = safeNum(entry.call, 0);
  if (!call) return;

  const name = entry.name ? String(entry.name) : `User-${call}`;

  const idx = state.chat.directory.findIndex((u) => safeNum(u.call, 0) === call);
  if (idx >= 0) {
    state.chat.directory[idx] = { ...state.chat.directory[idx], call, name };
  } else {
    state.chat.directory.push({ call, name });
  }
}

// ---- Local chat log persistence (browser-side) ----

function logKey(state) {
  const dev = state?.session?.deviceId || "nodev";
  // once call is assigned, include it to avoid collisions if deviceId reused
  const call = Number(state?.session?.call || 0) || 0;
  return `vibeweb:chatlog:${dev}:${call || "pending"}`;
}

function loadLog(state) {
  try {
    const raw = localStorage.getItem(logKey(state));
    if (!raw) return;
    const arr = JSON.parse(raw);
    if (Array.isArray(arr)) {
      state.chat.messages = arr;
      // cap
      if (state.chat.messages.length > 1000) {
        state.chat.messages.splice(0, state.chat.messages.length - 1000);
      }
    }
  } catch {}
}

function saveLog(state) {
  try {
    localStorage.setItem(logKey(state), JSON.stringify(state.chat.messages || []));
  } catch {}
}

function pushMessage(state, msg) {
  ensureChatState(state);

  const m = {
    kind: msg.kind || "system", // "room" | "dm" | "system"
    ts: msg.ts || Date.now(),
    room: msg.room || null,
    from: msg.from ?? null,
    to: msg.to ?? null,
    name: msg.name || null,
    text: msg.text || "",
  };

  state.chat.messages.push(m);

  if (state.chat.messages.length > 1000) {
    state.chat.messages.splice(0, state.chat.messages.length - 1000);
  }

  saveLog(state);
}

function bindWsMessageHandlers({ ws, state, render, shell }) {
  if (ws.__chatBound) return;
  ws.__chatBound = true;

  const sock = getUnderlyingSocket(ws);

  const handle = (raw) => {
    let m = raw;
    try {
      if (typeof raw === "string") m = JSON.parse(raw);
      else if (raw && raw.data && typeof raw.data === "string") m = JSON.parse(raw.data);
      else if (raw && raw.data && typeof raw.data === "object") m = raw.data;
    } catch {
      return;
    }

    if (!m || typeof m !== "object") return;

    // Server hello: may come twice. The one with call assigns identity.
    if (m.t === "hello") {
      const call = safeNum(m.call, 0);
      if (call > 0 && safeNum(state.session.call, 0) !== call) {
        state.session.call = call;
        if (shell?.setCall) shell.setCall(call);

        // If defaultRoom is provided, adopt it
        if (m.defaultRoom) {
          state.chat.room = String(m.defaultRoom);
          if (!state.chat.rooms.includes(state.chat.room)) state.chat.rooms.push(state.chat.room);
        }

        // After assignment, join room and ask for directory/history
        wsSend(ws, { t: "join", room: state.chat.room });
        wsSend(ws, { t: "directory" });
        wsSend(ws, { t: "history", room: state.chat.room, limit: 200 });

        // Reload log key now that call is known (optional)
        loadLog(state);
      }
      render();
      return;
    }

    if (m.t === "identify_fail") {
      pushMessage(state, { kind: "system", ts: Date.now(), text: `Identify failed: ${m.error || "unknown"}` });
      render();
      return;
    }

    // Directory responses
    if (m.t === "directory" || m.t === "dir") {
      const list = Array.isArray(m.users)
        ? m.users
        : Array.isArray(m.directory)
        ? m.directory
        : Array.isArray(m.list)
        ? m.list
        : [];
      list.forEach((u) => upsertDirectory(state, u));
      render();
      return;
    }

    // History responses (optional; many servers ignore)
    if (m.t === "history") {
      const list = Array.isArray(m.items) ? m.items : Array.isArray(m.messages) ? m.messages : [];
      list.forEach((x) => {
        if (x.kind) {
          pushMessage(state, x);
          upsertDirectory(state, { call: x.from, name: x.name });
          if (x.kind === "dm") upsertDirectory(state, { call: x.to, name: x.toName });
        } else if (x.t === "chat" || x.t === "room") {
          pushMessage(state, {
            kind: "room",
            ts: nowTs(x.at || x.ts),
            room: x.room || x.channel || state.chat.room,
            from: safeNum(x.from, 0),
            name: x.name || null,
            text: x.text || x.msg || "",
          });
          upsertDirectory(state, { call: x.from, name: x.name });
        } else if (x.t === "dm") {
          pushMessage(state, {
            kind: "dm",
            ts: nowTs(x.at || x.ts),
            from: safeNum(x.from, 0),
            to: safeNum(x.to, 0),
            name: x.name || null,
            text: x.text || x.msg || "",
          });
          upsertDirectory(state, { call: x.from, name: x.name });
          upsertDirectory(state, { call: x.to, name: x.toName });
        } else if (x.t === "system") {
          pushMessage(state, { kind: "system", ts: nowTs(x.at || x.ts), room: x.room || state.chat.room, text: x.text || "" });
        }
      });
      render();
      return;
    }

    // Live room chat
    if (m.t === "chat" || m.t === "room") {
      pushMessage(state, {
        kind: "room",
        ts: nowTs(m.at || m.ts),
        room: m.room || m.channel || state.chat.room,
        from: safeNum(m.from, 0),
        name: m.name || null,
        text: m.text || m.msg || "",
      });
      upsertDirectory(state, { call: m.from, name: m.name });
      render();
      return;
    }

    // Live DM
    if (m.t === "dm") {
      pushMessage(state, {
        kind: "dm",
        ts: nowTs(m.at || m.ts),
        from: safeNum(m.from, 0),
        to: safeNum(m.to, 0),
        name: m.name || null,
        text: m.text || m.msg || "",
      });
      upsertDirectory(state, { call: m.from, name: m.name });
      upsertDirectory(state, { call: m.to, name: m.toName });
      render();
      return;
    }

    if (m.t === "system") {
      pushMessage(state, { kind: "system", ts: nowTs(m.ts), room: m.room || state.chat.room, text: String(m.text || "") });
      render();
      return;
    }

    if (m.t === "error") {
      pushMessage(state, { kind: "system", ts: Date.now(), text: `Server error: ${m.error || "unknown"}` });
      render();
      return;
    }
  };

  if (typeof ws?.onMessage === "function") {
    ws.onMessage(handle);
    return;
  }

  if (sock && typeof sock.addEventListener === "function") {
    sock.addEventListener("message", (ev) => handle(ev));
    return;
  }

  if (typeof ws?.on === "function") {
    ws.on("message", handle);
  }
}

export function viewChat({ shell, state, ws, render }) {
  shell.setBackVisible(true);
  ensureChatState(state);

  // Lock session to cookie identity (deviceId is required)
  const lock = ensureLockedSessionFromCookie(state);

  if (!lock.ok) {
    shell.setHeader({
      title: "VibeChat",
      sub: "Not linked",
      pillText: "login required",
      pillOk: false,
    });

    const root = document.createElement("div");
    root.className = "chatWrap";
    root.innerHTML = `
      <div class="card" style="padding:16px;">
        <div style="font-weight:900; margin-bottom:6px;">Chat not linked</div>
        <div style="color:var(--muted); font-size:13px;">
          Your browser is missing the VibePhone identity cookie (deviceId). Open Phone first so the website provisions it.
        </div>
        <button id="goPhone" style="margin-top:12px; border:0; background:linear-gradient(180deg,#1c6cff,#1747d9); color:white; padding:10px 12px; border-radius:12px; font-weight:800;">
          Go to Phone
        </button>
      </div>
    `;
    shell.mount(root);

    root.querySelector("#goPhone").onclick = () => {
      location.href = "/phone.html";
    };
    return;
  }

  // Load local chat log immediately (even before call is assigned)
  loadLog(state);

  if (shell?.setCall) shell.setCall(state.session.call || 0);

  shell.setHeader({
    title: "VibeChat",
    sub: state.chat.dmTarget ? `DM ${state.chat.dmTarget}` : state.chat.room,
    pillText: ws.connected ? "connected" : "disconnected",
    pillOk: ws.connected,
  });

  bindWsMessageHandlers({ ws, state, render, shell });

  // Connect using deviceId identity
  if (!ws.connected && typeof ws.connect === "function") {
    ws.connect({
      deviceId: state.session.deviceId,
      name: state.session.name,
    });
  } else {
    // If already connected, re-identify safely
    wsSend(ws, {
      t: "identify",
      deviceId: state.session.deviceId,
      name: state.session.name,
    });
  }

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

    <div class="composer">
      <input id="msgIn" placeholder="Message…" />
      <button id="send">Send</button>
    </div>
  `;

  shell.mount(root);

  const roomsEl = root.querySelector("#rooms");
  const dirEl = root.querySelector("#dir");
  const msgsEl = root.querySelector("#msgs");

  function paintRooms() {
    roomsEl.innerHTML = "";
    state.chat.rooms.forEach((r) => {
      const b = document.createElement("button");
      b.textContent = r;
      if (!state.chat.dmTarget && state.chat.room === r) b.classList.add("active");
      b.onclick = () => {
        state.chat.dmTarget = null;
        state.chat.room = r;

        if (typeof ws.join === "function") ws.join(r);
        else wsSend(ws, { t: "join", room: r });

        wsSend(ws, { t: "history", room: r, limit: 200 });
        render();
      };
      roomsEl.appendChild(b);
    });
  }

  function paintDir() {
    dirEl.innerHTML = "";
    const users = (state.chat.directory || []).slice().sort((a, b) => (safeNum(a.call, 0) - safeNum(b.call, 0)));
    users.forEach((u) => {
      const call = safeNum(u.call, 0);
      if (!call) return;
      const b = document.createElement("button");
      b.textContent = `${u.name || ("User-" + call)} (${call})`;
      if (state.chat.dmTarget === call) b.classList.add("active");
      b.onclick = () => {
        state.chat.dmTarget = call;
        render();
      };
      dirEl.appendChild(b);
    });
  }

  function paintMsgs() {
    msgsEl.innerHTML = "";
    const me = safeNum(state.session.call, 0);

    const filtered = (state.chat.messages || []).filter((m) => {
      if (m.kind === "system") return true;

      if (state.chat.dmTarget) {
        if (m.kind !== "dm") return false;
        const other = safeNum(m.from, 0) === me ? safeNum(m.to, 0) : safeNum(m.from, 0);
        return other === state.chat.dmTarget;
      }

      if (m.kind !== "room") return false;
      return (m.room || "") === state.chat.room;
    });

    filtered.slice(-200).forEach((m) => {
      const div = document.createElement("div");
      div.className = "msg" + (m.kind === "system" ? " system" : "");
      const who = m.kind === "system" ? "system" : (m.name || m.from);
      const when = m.ts ? new Date(m.ts).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }) : "";
      div.innerHTML = `
        <div class="meta">
          <div class="who">${escapeHtml(String(who))}</div>
          <div class="when">${escapeHtml(String(when))}</div>
        </div>
        <div class="body">${escapeHtml(String(m.text || ""))}</div>
      `;
      msgsEl.appendChild(div);
    });

    msgsEl.scrollTop = msgsEl.scrollHeight;
  }

  root.querySelector("#join").onclick = () => {
    let room = String(root.querySelector("#roomIn").value || "").trim();
    if (!room) return;
    if (!room.startsWith("#")) room = "#" + room;
    if (!state.chat.rooms.includes(room)) state.chat.rooms.push(room);
    state.chat.dmTarget = null;
    state.chat.room = room;

    if (typeof ws.join === "function") ws.join(room);
    else wsSend(ws, { t: "join", room });

    wsSend(ws, { t: "history", room, limit: 200 });
    render();
  };

  const send = () => {
    const text = String(root.querySelector("#msgIn").value || "");
    if (!text.trim()) return;
    root.querySelector("#msgIn").value = "";

    if (state.chat.dmTarget) {
      if (typeof ws.dm === "function") ws.dm(state.chat.dmTarget, text);
      else wsSend(ws, { t: "dm", to: state.chat.dmTarget, text });

      // Optimistic local append
      pushMessage(state, {
        kind: "dm",
        ts: Date.now(),
        from: state.session.call || 0,
        to: state.chat.dmTarget,
        name: state.session.name,
        text,
      });
      render();
      return;
    }

    if (typeof ws.chat === "function") ws.chat(state.chat.room, text);
    else wsSend(ws, { t: "chat", room: state.chat.room, text });

    pushMessage(state, {
      kind: "room",
      ts: Date.now(),
      room: state.chat.room,
      from: state.session.call || 0,
      name: state.session.name,
      text,
    });
    render();
  };

  root.querySelector("#send").onclick = send;
  root.querySelector("#msgIn").addEventListener("keydown", (e) => {
    if (e.key === "Enter") send();
  });

  // Initial paint
  paintRooms();
  paintDir();
  paintMsgs();

  // Ask for directory/history (server may ignore history)
  wsSend(ws, { t: "directory" });
  wsSend(ws, { t: "history", room: state.chat.room, limit: 200 });

  function escapeHtml(s) {
    return String(s ?? "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;");
  }
}
