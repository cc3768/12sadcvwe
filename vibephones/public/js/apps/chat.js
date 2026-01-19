export function viewChat({ shell, state, ws, render }) {
  shell.setBackVisible(true);
  shell.setCall(state.session.call);
  shell.setHeader({
    title: "VibeChat",
    sub: state.chat.dmTarget ? `DM ${state.chat.dmTarget}` : state.chat.room,
    pillText: ws.connected ? "connected" : "disconnected",
    pillOk: ws.connected,
  });

  // Ensure connected if we have a call
  if (state.session.call && !ws.connected) {
    ws.connect({ call: state.session.call, name: state.session.name, webSecret: state.session.webSecret });
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
        ws.join(r);
        render();
      };
      roomsEl.appendChild(b);
    });
  }

  function paintDir() {
    dirEl.innerHTML = "";
    const users = (state.chat.directory || []).slice().sort((a,b)=>(a.call||0)-(b.call||0));
    users.forEach((u) => {
      const call = Number(u.call);
      const b = document.createElement("button");
      b.textContent = `${u.name || ("User-" + call)} (${call})`;
      if (state.chat.dmTarget === call) b.classList.add("active");
      b.onclick = () => { state.chat.dmTarget = call; render(); };
      dirEl.appendChild(b);
    });
  }

  function paintMsgs() {
    msgsEl.innerHTML = "";
    const me = state.session.call;

    const filtered = state.chat.messages.filter((m) => {
      if (m.kind === "system") return true;

      if (state.chat.dmTarget) {
        if (m.kind !== "dm") return false;
        const other = (Number(m.from) === me) ? Number(m.to) : Number(m.from);
        return other === state.chat.dmTarget;
      }

      if (m.kind !== "room") return false;
      return m.room === state.chat.room;
    });

    filtered.slice(-200).forEach((m) => {
      const div = document.createElement("div");
      div.className = "msg" + (m.kind === "system" ? " system" : "");
      const who = m.kind === "system" ? "system" : (m.name || m.from);
      const when = m.ts ? new Date(m.ts).toLocaleTimeString([], {hour:"2-digit", minute:"2-digit"}) : "";
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
    ws.join(room);
    render();
  };

  const send = () => {
    const text = String(root.querySelector("#msgIn").value || "");
    if (!text.trim()) return;
    root.querySelector("#msgIn").value = "";

    if (state.chat.dmTarget) ws.dm(state.chat.dmTarget, text);
    else ws.chat(state.chat.room, text);
  };

  root.querySelector("#send").onclick = send;
  root.querySelector("#msgIn").addEventListener("keydown", (e) => { if (e.key === "Enter") send(); });

  paintRooms();
  paintDir();
  paintMsgs();

  function escapeHtml(s){
    return s.replaceAll("&","&amp;").replaceAll("<","&lt;").replaceAll(">","&gt;").replaceAll('"',"&quot;").replaceAll("'","&#39;");
  }
}
