// public/js/lib/identity.js
// JS-readable cookie identity used by the web phone app.
// Cookie name: vibephone.identity
// Expected JSON: { call, key, deviceId, name, email }

export const ID_COOKIE = "vibephone.identity";

export function getCookie(name) {
  const parts = document.cookie.split(";").map((s) => s.trim());
  for (const p of parts) {
    if (p.startsWith(name + "=")) return decodeURIComponent(p.slice(name.length + 1));
  }
  return null;
}

export function readIdentityCookie() {
  const raw = getCookie(ID_COOKIE);
  if (!raw) return null;
  try {
    const obj = JSON.parse(raw);
    if (!obj || typeof obj !== "object") return null;

    const call = Number(obj.call || 0) || 0;
    const key = obj.key ? String(obj.key) : "";
    const name = obj.name ? String(obj.name) : "";
    const deviceId = obj.deviceId ? String(obj.deviceId) : "";
    const email = obj.email ? String(obj.email) : "";

    if (!call || call <= 0 || !key) return null;

    return { call, key, name, deviceId, email };
  } catch {
    return null;
  }
}

export function setCookie(name, value, days) {
  const expires = new Date(Date.now() + days * 24 * 60 * 60 * 1000).toUTCString();
  const secure = location.protocol === "https:" ? "; Secure" : "";
  document.cookie = `${name}=${encodeURIComponent(value)}; Expires=${expires}; Path=/; SameSite=Lax${secure}`;
}

export function writeIdentityCookie(next, days = 14) {
  setCookie(ID_COOKIE, JSON.stringify(next), days);
}

export function deleteIdentityCookie() {
  const secure = location.protocol === "https:" ? "; Secure" : "";
  document.cookie = `${ID_COOKIE}=; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Path=/; SameSite=Lax${secure}`;
}

export function applyIdentityToState(state, ident) {
  state.session = state.session || {};
  state.session.call = ident.call;
  state.session.key = ident.key;
  state.session.webSecret = ident.key; // WS secret = key
  state.session.name = ident.name || state.session.name || "User";
  state.session.deviceId = ident.deviceId || null;
  state.session.email = ident.email || null;
}

export function storageKey(call, suffix) {
  return `vibephone:${call}:${suffix}`;
}
