export function viewHome({ shell, state, ws, render }) {
  shell.setBackVisible(false);
  shell.setCall(state.session.call);
  shell.setHeader({
    title: "VibePhone",
    sub: "Web Portal",
    pillText: ws.connected ? "connected" : "disconnected",
    pillOk: ws.connected,
  });

  const root = document.createElement("div");
  root.className = "home";

  root.innerHTML = `
    <div class="card" style="margin-bottom:10px;">
      <div style="display:flex; gap:10px; align-items:flex-end; justify-content:space-between;">
        <div>
          <div style="font-weight:900; font-size:16px;">Login</div>
          <div style="color:var(--muted); font-size:12px; margin-top:2px;">
            Use your call #. The server will issue/return your phone key.
          </div>
        </div>
        <div class="pill">Key: ${state.session.key ? "set" : "none"}</div>
      </div>

      <div style="display:flex; gap:10px; margin-top:10px;">
        <input id="call" placeholder="Call #" inputmode="numeric" style="flex:1; padding:12px; border-radius:14px; border:1px solid rgba(28,42,61,.9); background:rgba(11,18,32,.65); color:var(--text); outline:none;">
        <input id="name" placeholder="Name (optional)" style="flex:1; padding:12px; border-radius:14px; border:1px solid rgba(28,42,61,.9); background:rgba(11,18,32,.65); color:var(--text); outline:none;">
      </div>

      <div style="display:flex; gap:10px; margin-top:10px;">
        <input id="secret" placeholder="WEB_SECRET (optional)" type="password" style="flex:1; padding:12px; border-radius:14px; border:1px solid rgba(28,42,61,.9); background:rgba(11,18,32,.65); color:var(--text); outline:none;">
        <button id="btn" style="border:0; background:linear-gradient(180deg,#1c6cff,#1747d9); color:white; padding:12px 14px; border-radius:14px; font-weight:800;">Connect</button>
      </div>

      <div id="err" style="color:var(--bad); font-size:12px; margin-top:8px;"></div>
    </div>

    <div class="homeGrid">
      ${icon("chat","VibeChat")}
      ${icon("calc","Calculator")}
      ${icon("notes","Notes")}
      ${icon("contacts","Contacts")}
      ${icon("phoneKey","Phone Key")}
      ${icon("status","Status")}
      ${icon("about","About")}
      ${icon("settings","Settings")}
    </div>

    <div class="dock" style="margin-top:12px;">
      <button class="dockBtn" data-go="chat">Chat</button>
      <button class="dockBtn" data-go="notes">Notes</button>
      <button class="dockBtn" data-go="settings">Settings</button>
    </div>
  `;

  shell.mount(root);

  const $ = (q) => root.querySelector(q);

  $("#call").value = state.session.call || "";
  $("#name").value = state.session.name || "";
  $("#secret").value = state.session.webSecret || "";

  $("#btn").onclick = () => {
    const call = Number(String($("#call").value || "").trim());
    const name = String($("#name").value || "").trim();
    const webSecret = String($("#secret").value || "").trim();

    if (!Number.isFinite(call) || call <= 0) {
      $("#err").textContent = "Enter a valid call #.";
      return;
    }
    $("#err").textContent = "";

    state.setSession({ call, name, webSecret });
    ws.connect({ call, name, webSecret });

    // go to chat after connect
    shell.nav("chat");
    render();
  };

  root.querySelectorAll("[data-go]").forEach((b) => {
    b.onclick = () => { shell.nav(b.getAttribute("data-go")); render(); };
  });

  root.querySelectorAll(".icon[data-go]").forEach((b) => {
    b.onclick = () => { shell.nav(b.getAttribute("data-go")); render(); };
  });

  function icon(go, label) {
    return `
      <button class="icon" data-go="${go}">
        <div class="glyph"></div>
        <div class="iconLabel">${label}</div>
      </button>
    `;
  }
}
