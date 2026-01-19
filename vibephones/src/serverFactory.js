// src/serverFactory.js (ESM)
import http from "http";
import https from "https";
import fs from "fs";
import path from "path";
import express from "express";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export function makeServer() {
  const DIRECT_WSS = process.env.DIRECT_WSS === "1";
  const PORT = process.env.PORT ? Number(process.env.PORT) : 8080;

  const app = express();

  // Serve website from <projectRoot>/public
  const publicDir = path.join(__dirname, "..", "public");
  if (fs.existsSync(publicDir)) {
    app.use(express.static(publicDir, { index: "index.html" }));
  }

  // Health endpoint
  app.get("/status", (req, res) => {
    res.setHeader("content-type", "text/plain; charset=utf-8");
    res.end(`VC ${DIRECT_WSS ? "WSS" : "WS"} server OK\n`);
  });

  if (!DIRECT_WSS) {
    const server = http.createServer(app);
    return { app, server, port: PORT, directWss: false };
  }

  const keyPath = process.env.TLS_KEY;
  const certPath = process.env.TLS_CERT;
  if (!keyPath || !certPath) {
    throw new Error("DIRECT_WSS=1 requires TLS_KEY and TLS_CERT env vars.");
  }

  const opts = {
    key: fs.readFileSync(keyPath),
    cert: fs.readFileSync(certPath),
  };
  if (process.env.TLS_CA) opts.ca = fs.readFileSync(process.env.TLS_CA);

  const server = https.createServer(opts, app);
  return { app, server, port: PORT, directWss: true };
}
