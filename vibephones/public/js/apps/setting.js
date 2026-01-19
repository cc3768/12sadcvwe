export function viewSettings({ shell, state, ws }) {
  shell.setBackVisible(true);
  shell.setHeader({ title:"Settings", sub:"Profile", pillText:"local", pillOk:true });

  const root = document.createElement("div");
  root.innerHTML = `
    <div style="font-weight:900;">Profile</div>
    <div style="display:flex; gap:10px; margin-top:10px;">
      <input id="name" placeholder="Display name" style="flex:1; padding:12px; border-radius:14px; border:1px solid rgba(28,42,61,.9); background:rgba(11,18,32,.65); color:var(--text); outline:none;">
      <button id="save" style="border:0; background:linear-gradient(180deg,#1c6cff,#1747d9); color:white; padding:12px 14px; border-radius:14px; font-weight:800;">Save</button>
    </div>
  `;
  const name = root.querySelector("#name");
  name.value = state.session.name || "";
  root.querySelector("#save").onclick = () => {
    state.setSession({ name: String(name.value || "").trim() });
    if (ws.connected) ws.setName(state.session.name);
  };
  shell.mount(root);
}
