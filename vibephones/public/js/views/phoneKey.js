// Uses the JS-readable cookie set by phone.html: "vibephone.identity"
// Expected cookie JSON shape: { call, key, deviceId, name, email }

function getCookie(name) {
  const parts = document.cookie.split(";").map(s => s.trim());
  for (const p of parts) {
    if (p.startsWith(name + "=")) return decodeURIComponent(p.slice(name.length + 1));
  }
  return null;
}

function readIdentityFromCookie() {
  const raw = getCookie("vibephone.identity");
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

export function viewPhoneKey({ shell, state }) {
  shell.setBackVisible(true);
  shell.setHeader({ title: "Phone Key", sub: "Link code", pillText: "secure", pillOk: true });

  const ident = readIdentityFromCookie();

  // Keep state in sync (optional, but useful across views)
  state.session = state.session || {};
  if (ident && typeof ident === "object") {
    state.session.call = ident.call ?? state.session.call ?? 0;
    state.session.key = ident.key ?? state.session.key ?? null;
    state.session.deviceId = ident.deviceId ?? state.session.deviceId ?? null;
    state.session.name = ident.name ?? state.session.name ?? null;
    state.session.email = ident.email ?? state.session.email ?? null;
  }

  const call = state.session.call || 0;
  const key = state.session.key || null;
  const deviceId = state.session.deviceId || "YOUR_DEVICE_ID";
  const name = state.session.name || "Optional";

  const root = document.createElement("div");
  root.innerHTML = `
    <div style="font-weight:900;">Your key</div>
    <div style="margin-top:10px; font-size:18px; font-weight:900; letter-spacing:1px;">
      ${key ? key : "Not set (connect on Home)"}
    </div>
    <div style="color:var(--muted); font-size:12px; margin-top:10px;">
      Use this key on the CC computer identify payload.
    </div>
    <pre class="card" style="margin-top:10px; white-space:pre-wrap;">{
  "t": "identify",
  "call": ${call},
  "key": "${key || "PHONE_KEY"}",
  "deviceId": "${deviceId}",
  "name": "${name}"
}</pre>
  `;
  shell.mount(root);
}
