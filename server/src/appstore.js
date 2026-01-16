const { send } = require("./util");

function toAppMeta(app) {
  return {
    id: app.id,
    name: app.name,
    version: app.version,
    description: app.description,
    installBase: app.installBase
  };
}

function makeBundle(app) {
  const files = [];
  for (const [path, content] of Object.entries(app.files)) {
    const b64 = Buffer.from(String(content), "utf8").toString("base64");
    files.push({ path, b64 });
  }
  files.sort((a,b) => a.path.localeCompare(b.path));
  return {
    t: "app_bundle",
    id: app.id,
    version: app.version,
    installBase: app.installBase,
    files
  };
}

class AppStore {
  constructor(catalog) {
    this.catalog = Array.isArray(catalog) ? catalog : [];
    this.byId = new Map();
    for (const a of this.catalog) this.byId.set(a.id, a);
  }

  handle(ws, msg, WebSocket) {
    if (msg.t === "apps_list") {
      send(ws, { t: "apps_list", apps: this.catalog.map(toAppMeta) }, WebSocket);
      return true;
    }

    if (msg.t === "app_fetch") {
      const id = String(msg.id || "");
      const app = this.byId.get(id);
      if (!app) {
        send(ws, { t: "app_error", id, error: "Unknown app" }, WebSocket);
        return true;
      }
      send(ws, makeBundle(app), WebSocket);
      return true;
    }

    return false;
  }
}

module.exports = { AppStore };
