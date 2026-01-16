const http = require("http");
const https = require("https");
const fs = require("fs");
const express = require("express");

function makeServer() {
  const DIRECT_WSS = process.env.DIRECT_WSS === "1";
  const PORT = process.env.PORT ? Number(process.env.PORT) : 8080;

  const app = express();

  // Basic health check
  app.get("/", (req, res) => {
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

  const opts = { key: fs.readFileSync(keyPath), cert: fs.readFileSync(certPath) };
  if (process.env.TLS_CA) opts.ca = fs.readFileSync(process.env.TLS_CA);

  const server = https.createServer(opts, app);
  return { app, server, port: PORT, directWss: true };
}

module.exports = { makeServer };
