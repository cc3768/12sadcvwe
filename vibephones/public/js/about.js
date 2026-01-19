// placeholder
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

export function viewAbout({ shell }) {
  shell.setHeader({ title: "About", sub: "", pillText: "", pillOk: true });
  shell.mount(el("div", { class: "card", style: "padding:16px;" }, [
    el("div", { class: "cardTitle" }, ["About"]),
    el("div", { style: "color:var(--muted); font-size:13px;" }, ["Not implemented in this build."]),
  ]));
}
