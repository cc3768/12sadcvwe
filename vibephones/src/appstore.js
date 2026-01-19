import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// AppStore reads from: <appsDir>/<appId>/manifest.json and <appsDir>/<appId>/files/**
// Repo layouts differ (some place appstore.js in /src, some in /src/routes, etc.).
// Resolve the apps directory robustly.
function resolveAppsDir() {
  const candidates = [];

  // 1) Explicit override
  if (process.env.APPS_DIR) candidates.push(process.env.APPS_DIR);

  // 2) Project root (where node was started)
  candidates.push(path.join(process.cwd(), "apps"));

  // 3) Relative to this file
  candidates.push(path.join(__dirname, "..", "apps"));
  candidates.push(path.join(__dirname, "..", "..", "apps"));

  for (const c of candidates) {
    try {
      const full = path.resolve(c);
      if (fs.existsSync(full) && fs.statSync(full).isDirectory()) return full;
    } catch {
      // ignore
    }
  }
  // Default (will yield empty list if it doesn't exist)
  return path.resolve(path.join(process.cwd(), "apps"));
}

const APPS_DIR = resolveAppsDir();

function safeJoin(base, rel) {
  const baseResolved = path.resolve(base) + path.sep;
  const full = path.resolve(base, rel);
  if (!full.startsWith(baseResolved)) return null;
  return full;
}

function toB64(data) {
  // data is UTF-8 text (lua/js/json). If you later add binary, switch to readFileSync(full) without utf8.
  return Buffer.from(String(data ?? ""), "utf8").toString("base64");
}

function loadManifest(id) {
  try {
    const p = path.join(APPS_DIR, id, "manifest.json");
    if (!fs.existsSync(p)) return null;
    const raw = fs.readFileSync(p, "utf8");
    const m = JSON.parse(raw);
    return m && typeof m === "object" ? m : null;
  } catch {
    return null;
  }
}

function listApps() {
  if (!fs.existsSync(APPS_DIR)) return [];
  const ids = fs
    .readdirSync(APPS_DIR, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name);

  const out = [];
  for (const id of ids) {
    const m = loadManifest(id);
    if (!m) continue;
    out.push({
      id: m.id || id,
      name: m.name || id,
      version: m.version || "0.0.0",
      description: m.description || "",
      entry: m.entry || "app.lua",
      installBase: m.installBase || `/vibephone/apps/${id}`,
    });
  }
  return out;
}

function buildBundle(appId) {
  const m = loadManifest(appId);
  if (!m) return { ok: false, error: "not_found" };

  const fileList = Array.isArray(m.files) ? m.files : [];
  const filesDir = path.join(APPS_DIR, appId, "files");
  // Support both layouts:
  //  - apps/<id>/files/<rel>
  //  - apps/<id>/<rel>
  const base = fs.existsSync(filesDir) ? filesDir : path.join(APPS_DIR, appId);

  const files = {};
  for (const rel of fileList) {
    const relNorm = String(rel || "").replace(/\\/g, "/");
    const full = safeJoin(base, relNorm);
    if (!full) return { ok: false, error: "bad_path", file: relNorm };
    if (!fs.existsSync(full) || fs.statSync(full).isDirectory()) {
      return { ok: false, error: "missing_file", file: relNorm };
    }
    files[relNorm] = toB64(fs.readFileSync(full, "utf8"));
  }

  return {
    ok: true,
    bundle: {
      t: "app_bundle",
      id: m.id || appId,
      name: m.name || appId,
      version: m.version || "0.0.0",
      description: m.description || "",
      entry: m.entry || "app.lua",
      installBase: m.installBase || `/vibephone/apps/${appId}`,
      // WS bundle format: MAP rel->base64
      files,
      filesAreRaw: false,
    },
  };
}

// HTTP AppStore (for debugging + wget)
function registerAppStoreHttp(app) {
  // List apps
  app.get("/api/apps", (req, res) => {
    res.json({ ok: true, apps: listApps() });
  });

  // Manifest
  app.get("/api/apps/:id/manifest", (req, res) => {
    const id = String(req.params.id || "");
    const m = loadManifest(id);
    if (!m) return res.status(404).json({ ok: false, error: "not_found" });
    res.json({ ok: true, manifest: m });
  });

  // File fetch (named wildcard)
  app.get("/api/apps/:id/file/:path(*)", (req, res) => {
    const id = String(req.params.id || "");
    const rel = String(req.params.path || "").replace(/\\/g, "/");

    const filesDir = path.join(APPS_DIR, id, "files");
    const base = fs.existsSync(filesDir) ? filesDir : path.join(APPS_DIR, id);
    const full = safeJoin(base, rel);
    if (!full) return res.status(400).send("bad_path");
    if (!fs.existsSync(full) || fs.statSync(full).isDirectory()) return res.status(404).send("not_found");

    res.setHeader("Content-Type", "text/plain; charset=utf-8");
    res.send(fs.readFileSync(full, "utf8"));
  });
}

// WS AppStore handler. Call this from your main ws.on('message').
// Supports:
//   {t:'apps_list'} -> {t:'apps_list', apps:[...]}
//   {t:'app_fetch', id:'ipod'} -> {t:'app_bundle', ...} OR {t:'app_error', error:'...'}
function handleAppStoreWS(ws, msg, WebSocket, send) {
  if (!msg || typeof msg.t !== "string") return false;

  if (msg.t === "apps_list") {
    send(ws, { t: "apps_list", apps: listApps() }, WebSocket);
    return true;
  }

  if (msg.t === "app_fetch") {
    const id = String(msg.id || "").trim();
    if (!id) {
      send(ws, { t: "app_error", error: "missing_id" }, WebSocket);
      return true;
    }
    const built = buildBundle(id);
    if (!built.ok) {
      send(ws, { t: "app_error", id, error: built.error, file: built.file }, WebSocket);
      return true;
    }
    send(ws, built.bundle, WebSocket);
    return true;
  }

  // Optional keepalive (client may send ping)
  if (msg.t === "ping") {
    send(ws, { t: "pong", ts: Date.now() }, WebSocket);
    return true;
  }

  return false;
}

export {
  registerAppStoreHttp,
  handleAppStoreWS,
};
