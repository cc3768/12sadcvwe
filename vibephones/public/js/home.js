// public/js/home.js

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

export function viewHome({ shell, state, ws }) {
  shell.setHeader({
    title: "VibePhone",
    sub: state.session.call ? `#${state.session.call} • ${state.session.name}` : state.session.name,
    pillText: ws.connected ? "connected" : "disconnected",
    pillOk: ws.connected,
  });

  const root = el("div", { class: "homeWrap" }, [
    el("div", { class: "cardTitle" }, ["Apps"]),
    el("div", { class: "grid" }, [
      el("button", { class: "appBtn", onclick: () => shell.nav("chat") }, ["VibeChat"]),
      el("button", { class: "appBtn", onclick: () => shell.nav("contacts") }, ["Contacts"]),
      el("button", { class: "appBtn", onclick: () => shell.nav("notes") }, ["Notes"]),
      el("button", { class: "appBtn", onclick: () => shell.nav("calc") }, ["Calculator"]),
      el("button", { class: "appBtn", onclick: () => shell.nav("settings") }, ["Settings"]),
      el("button", { class: "appBtn", onclick: () => window.vibephoneLogout?.() }, ["Logout"]),
    ]),
  ]);

  shell.mount(root);
}
