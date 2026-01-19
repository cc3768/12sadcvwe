export function viewStatus({ shell, state, ws, render }) {
  shell.setBackVisible(true);
  shell.setCall(state.session.call);
  shell.setHeader({
    title: "Status",
    sub: "Connection",
    pillText: ws.connected ? "connected" : "disconnected",
    pillOk: ws.connected,
  });

  // Lazy connect if we have a call but are offline
  if (state.session.call && !ws.connected) {
    ws.connect({ call: state.session.call, name: state.session.name, webSecret: state.session.webSecret });
  }

  const root = document.createElement("div");
  root.className = "status";

  const safe = (v) => String(v ?? "");
  const url = (() => {
    try { return ws.url(); } catch { return ""; }
  })();

  root.innerHTML = `
    <div class="card" style="margin-bottom:10px;">
      <div style="display:flex; align-items:center; justify-content:space-between; gap:10px;">
        <div>
          <div style="font-weight:900; font-size:16px;">WebSocket</div>
          <div style="color:var(--muted); font-size:12px; margin-top:2px;">${escapeHtml(url)}</div>
        </div>
        <div class="pill">${ws.connected ? "online" : "offline"}</div>
      </div>

      <div style="display:grid; grid-template-columns: 1fr 1fr; gap:10px; margin-top:12px;">
        <div class="card" style="padding:12px;">
          <div style="color:var(--muted); font-size:12px;">Call #</div>
          <div style="font-weight:900; font-size:18px;">${escapeHtml(safe(state.session.call || "—"))}</div>
        </div>
        <div class="card" style="padding:12px;">
          <div style="color:var(--muted); font-size:12px;">Phone Key</div>
          <div style="font-weight:900; font-size:18px;">${state.session.key ? "set" : "none"}</div>
        </div>
      </div>

      <div style="display:grid; grid-template-columns: 1fr 1fr; gap:10px; margin-top:10px;">
        <div class="card" style="padding:12px;">
          <div style="color:var(--muted); font-size:12px;">Room</div>
          <div style="font-weight:800;">${escapeHtml(safe(state.chat.room))}</div>
        </div>
        <div class="card" style="padding:12px;">
          <div style="color:var(--muted); font-size:12px;">DM Target</div>
          <div style="font-weight:800;">${escapeHtml(safe(state.chat.dmTarget || "—"))}</div>
        </div>
      </div>

      <div style="display:grid; grid-template-columns: 1fr 1fr; gap:10px; margin-top:10px;">
        <div class="card" style="padding:12px;">
          <div style="color:var(--muted); font-size:12px;">Messages (cached)</div>
          <div style="font-weight:900; font-size:18px;">${escapeHtml(safe((state.chat.messages || []).length))}</div>
        </div>
        <div class="card" style="padding:12px;">
          <div style="color:var(--muted); font-size:12px;">Directory</div>
          <div style="font-weight:900; font-size:18px;">${escapeHtml(safe((state.chat.directory || []).length))}</div>
        </div>
      </div>

      <div style="display:flex; gap:10px; margin-top:12px;">
        <button id="reconnect" style="border:0; background:linear-gradient(180deg,#1c6cff,#1747d9); color:white; padding:10px 12px; border-radius:12px; font-weight:800;">Reconnect</button>
        <button id="clear" style="border:1px solid rgba(28,42,61,.9); background:rgba(11,18,32,.65); color:var(--text); padding:10px 12px; border-radius:12px; font-weight:800;">Clear cached messages</button>
      </div>
    </div>
  `;

  root.querySelector("#reconnect").onclick = () => {
    // Close existing socket if any, then connect again.
    try { if (ws.ws) ws.ws.close(); } catch {}
    ws.connected = false;
    ws.connect({ call: state.session.call, name: state.session.name, webSecret: state.session.webSecret });
    if (typeof render === "function") render();
  };

  root.querySelector("#clear").onclick = () => {
    state.chat.messages = [];
    if (typeof render === "function") render();
  };

  shell.mount(root);

  function escapeHtml(s){
    return String(s)
      .replaceAll("&","&amp;")
      .replaceAll("<","&lt;")
      .replaceAll(">","&gt;")
      .replaceAll('"',"&quot;")
      .replaceAll("'","&#39;");
  }
}
