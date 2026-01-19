// public/js/lib/identity.js

const COOKIE_NAME = "vibephone.identity";
const LS_KEY = "vibephone.identity";

function getCookie(name) {
  const parts = document.cookie.split(";").map((s) => s.trim());
  for (const p of parts) {
    if (p.startsWith(name + "=")) return decodeURIComponent(p.slice(name.length + 1));
  }
  return null;
}

function parseJson(raw) {
  if (!raw) return null;
  try {
    const obj = JSON.parse(raw);
    if (obj && typeof obj === "object") return obj;
  } catch {}
  return null;
}

export function readIdentityCookie() {
  // Prefer cookie (server-controlled), fallback to localStorage.
  return parseJson(getCookie(COOKIE_NAME)) || parseJson(localStorage.getItem(LS_KEY));
}

export function writeIdentity(ident) {
  if (!ident || typeof ident !== "object") return false;
  let raw;
  try {
    raw = JSON.stringify(ident);
  } catch {
    return false;
  }
  // Persist locally
  try { localStorage.setItem(LS_KEY, raw); } catch {}
  // Persist as cookie for back-compat readers
  // Keep it lax + path=/ so all routes can read it.
  document.cookie = `${COOKIE_NAME}=${encodeURIComponent(raw)}; Path=/; SameSite=Lax`;
  return true;
}

export function applyIdentityToState(state, ident) {
  if (!state || !ident) return;
  state.session = state.session || {};

  state.session.call = Number(ident.call || 0) || 0;
  state.session.key = ident.key ? String(ident.key) : (state.session.key || null);
  state.session.webSecret = state.session.key;
  state.session.deviceId = ident.deviceId ? String(ident.deviceId) : (state.session.deviceId || null);
  state.session.name = ident.name ? String(ident.name) : (state.session.name || "User");
  state.session.email = ident.email ? String(ident.email) : (state.session.email || null);
}

export function storageKey(call, kind) {
  return `vibephone:${Number(call || 0) || 0}:${String(kind || "")}`;
}

export function deleteIdentityCookie() {
  // Kill cookie
  document.cookie = `${COOKIE_NAME}=; Path=/; Max-Age=0; SameSite=Lax`;
  // Kill local cache
  try { localStorage.removeItem(LS_KEY); } catch {}
}
