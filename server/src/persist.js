// src/persist.js
// Simple JSON persistence for call-number assignments by deviceId.

const fs = require("fs");
const path = require("path");

const DATA_DIR = path.join(__dirname, "..", "data");
const CALLS_PATH = path.join(DATA_DIR, "calls.json");

function ensureDir() {
  if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
}

function loadCalls() {
  ensureDir();
  if (!fs.existsSync(CALLS_PATH)) return { nextCall: 1000, byDevice: {} };
  try {
    const raw = fs.readFileSync(CALLS_PATH, "utf8");
    const obj = JSON.parse(raw);
    if (!obj || typeof obj !== "object") throw new Error("bad json");
    obj.nextCall = Number(obj.nextCall) || 1000;
    obj.byDevice = obj.byDevice && typeof obj.byDevice === "object" ? obj.byDevice : {};
    return obj;
  } catch {
    return { nextCall: 1000, byDevice: {} };
  }
}

function saveCalls(state) {
  ensureDir();
  const out = { nextCall: state.nextCall, byDevice: state.byDevice };
  fs.writeFileSync(CALLS_PATH, JSON.stringify(out, null, 2), "utf8");
}

module.exports = { loadCalls, saveCalls };
