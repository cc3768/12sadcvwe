export function viewNotes({ shell }) {
  shell.setBackVisible(true);
  shell.setHeader({ title:"Notes", sub:"Local notes (browser)", pillText:"local", pillOk:true });

  const key = "vc_notes";
  const root = document.createElement("div");
  root.className = "notesArea";

  root.innerHTML = `
    <div style="font-weight:900;">Notes</div>
    <textarea id="t" placeholder="Type here…"></textarea>
    <div style="color:var(--muted); font-size:12px;">Saved automatically in this browser.</div>
  `;

  const t = root.querySelector("#t");
  t.value = localStorage.getItem(key) || "";
  t.addEventListener("input", () => localStorage.setItem(key, t.value));

  shell.mount(root);
}
