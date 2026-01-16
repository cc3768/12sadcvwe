const fs = require("fs");
const path = require("path");

const APPS_DIR = path.join(__dirname, "apps");

function safeJoin(base, rel) {
  const p = path.normalize(path.join(base, rel));
  if (!p.startsWith(base)) return null;
  return p;
}

function listApps() {
  if (!fs.existsSync(APPS_DIR)) return [];
  const dirs = fs.readdirSync(APPS_DIR, { withFileTypes: true })
    .filter(d => d.isDirectory())
    .map(d => d.name);

  const out = [];
  for (const id of dirs) {
    const mpath = path.join(APPS_DIR, id, "manifest.json");
    if (!fs.existsSync(mpath)) continue;
    try {
      const m = JSON.parse(fs.readFileSync(mpath, "utf8"));
      out.push({
        id: m.id || id,
        name: m.name || id,
        version: m.version || "0.0.0",
        entry: m.entry || "app.lua",
        installBase: m.installBase || `/vibephone/apps/${id}`
      });
    } catch {}
  }
  return out;
}

function readManifest(appId) {
  const mpath = path.join(APPS_DIR, appId, "manifest.json");
  if (!fs.existsSync(mpath)) return null;
  try { return JSON.parse(fs.readFileSync(mpath, "utf8")); }
  catch { return null; }
}

function registerAppStore(app, wss) {
  // HTTP: list apps
  app.get("/api/apps", (req, res) => {
    res.json({ ok: true, apps: listApps() });
  });

  // HTTP: manifest
  app.get("/api/apps/:id/manifest", (req, res) => {
    const m = readManifest(req.params.id);
    if (!m) return res.status(404).json({ ok: false, error: "not_found" });
    res.json({ ok: true, manifest: m });
  });

  // HTTP: file fetch
  app.get("/api/apps/:id/file/*", (req, res) => {
    const id = req.params.id;
    const rel = req.params[0]; // wildcard
    const base = path.join(APPS_DIR, id, "files");
    const full = safeJoin(base, rel);
    if (!full) return res.status(400).send("bad_path");
    if (!fs.existsSync(full) || fs.statSync(full).isDirectory()) {
      return res.status(404).send("not_found");
    }
    res.setHeader("Content-Type", "text/plain; charset=utf-8");
    res.send(fs.readFileSync(full, "utf8"));
  });

  // WebSocket: app store messages
  wss.on("connection", (ws) => {
    ws.on("message", (buf) => {
      let msg;
      try { msg = JSON.parse(buf.toString("utf8")); } catch { return; }
      if (!msg || typeof msg !== "object") return;

      if (msg.t === "apps_list") {
        ws.send(JSON.stringify({ t: "apps_list", apps: listApps() }));
        return;
      }

      if (msg.t === "app_manifest" && typeof msg.id === "string") {
        const m = readManifest(msg.id);
        if (!m) {
          ws.send(JSON.stringify({ t: "app_manifest", id: msg.id, ok: false, error: "not_found" }));
        } else {
          ws.send(JSON.stringify({ t: "app_manifest", id: msg.id, ok: true, manifest: m }));
        }
        return;
      }
    });
  });
}

module.exports = { registerAppStore };
