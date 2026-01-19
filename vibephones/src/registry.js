const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const DATA_DIR = path.join(__dirname, "..", "data");
const REG_PATH = path.join(DATA_DIR, "registry.json");

function ensureDir() {
  if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
}

function loadDb() {
  ensureDir();
  if (!fs.existsSync(REG_PATH)) return { version: 1, calls: {} };
  try {
    const raw = fs.readFileSync(REG_PATH, "utf8");
    const obj = JSON.parse(raw);
    if (!obj || typeof obj !== "object") throw new Error("bad");
    if (!obj.calls || typeof obj.calls !== "object") obj.calls = {};
    if (!obj.version) obj.version = 1;
    return obj;
  } catch {
    return { version: 1, calls: {} };
  }
}

function saveDb(db) {
  ensureDir();
  fs.writeFileSync(REG_PATH, JSON.stringify(db, null, 2), "utf8");
}

function genKey() {
  // 16 chars base64-ish (letters/digits)
  return crypto
    .randomBytes(10)
    .toString("base64")
    .replace(/[^A-Za-z0-9]/g, "")
    .slice(0, 16);
}

let db = loadDb();

function getRecord(call) {
  const k = String(call);
  return db.calls[k] || null;
}

function setRecord(call, rec) {
  db.calls[String(call)] = rec;
  saveDb(db);
}

/**
 * Web login helper:
 * - If call doesn't exist: create it (issue new key)
 * - If call exists:
 *    - if key provided, must match
 *    - if key not provided, allow web login and return existing key
 */
function getOrCreateCall(call, keyMaybe) {
  const c = Number(call);
  if (!Number.isFinite(c) || c <= 0) return { ok: false, error: "bad_call" };

  const incomingKey = String(keyMaybe || "").trim();
  const existing = getRecord(c);

  if (!existing) {
    const key = genKey();
    const rec = {
      call: c,
      key,
      name: null,
      deviceId: null,
      createdAt: Date.now(),
      lastSeenAt: null,
    };
    setRecord(c, rec);
    return { ok: true, key: rec.key, created: true, record: rec };
  }

  // If the client provided a key, enforce it.
  if (incomingKey && incomingKey !== String(existing.key || "")) {
    return { ok: false, error: "bad_key" };
  }

  existing.lastSeenAt = Date.now();
  setRecord(c, existing);
  return { ok: true, key: existing.key, created: false, record: existing };
}

/**
 * Computer identify:
 * - call must exist
 * - key must match
 * - deviceId must be present
 * - only allow binding once (prevents spam/new users per reconnect)
 */
function bindDevice(call, key, deviceId) {
  const c = Number(call);
  if (!Number.isFinite(c) || c <= 0) return { ok: false, error: "bad_call" };

  const rec = getRecord(c);
  if (!rec) return { ok: false, error: "not_registered" };

  const k = String(key || "").trim();
  if (!k) return { ok: false, error: "missing_key" };
  if (k !== String(rec.key || "")) return { ok: false, error: "bad_key" };

  const dev = String(deviceId || "").trim().slice(0, 80);
  if (!dev) return { ok: false, error: "missing_deviceId" };

  // Only allow binding once
  if (rec.deviceId && rec.deviceId !== dev) {
    return { ok: false, error: "device_already_bound", boundTo: rec.deviceId };
  }

  rec.deviceId = dev;
  rec.lastSeenAt = Date.now();
  setRecord(c, rec);
  return { ok: true, record: rec };
}

function touch(call) {
  const c = Number(call);
  if (!Number.isFinite(c) || c <= 0) return;
  const rec = getRecord(c);
  if (!rec) return;
  rec.lastSeenAt = Date.now();
  setRecord(c, rec);
}

module.exports = {
  getOrCreateCall,
  bindDevice,
  touch,
};
