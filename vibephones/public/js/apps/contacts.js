export function viewContacts({ shell, state }) {
  shell.setBackVisible(true);
  shell.setHeader({ title:"Contacts", sub:"Directory", pillText:"live", pillOk:true });

  const root = document.createElement("div");
  root.innerHTML = `
    <div style="font-weight:900; margin-bottom:10px;">Directory</div>
    <div class="list" id="dir"></div>
  `;
  const dir = root.querySelector("#dir");

  (state.chat.directory || []).slice().sort((a,b)=>(a.call||0)-(b.call||0)).forEach((u) => {
    const b = document.createElement("button");
    b.textContent = `${u.name || ("User-" + u.call)} (${u.call})`;
    dir.appendChild(b);
  });

  shell.mount(root);
}
