const http = require("http");
const https = require("https");
const fs = require("fs");

function makeServer() {
  const DIRECT_WSS = process.env.DIRECT_WSS === "1";
  const PORT = process.env.PORT ? Number(process.env.PORT) : 8080;

  if (!DIRECT_WSS) {
    const s = http.createServer((req, res) => {
      res.writeHead(200, { "content-type": "text/plain" });
      res.end("VC WS server OK\n");
    });
    return { server: s, port: PORT, directWss: false };
  }

  const keyPath = process.env.TLS_KEY;
  const certPath = process.env.TLS_CERT;
  if (!keyPath || !certPath) {
    throw new Error("DIRECT_WSS=1 requires TLS_KEY and TLS_CERT env vars.");
  }

  const opts = { key: fs.readFileSync(keyPath), cert: fs.readFileSync(certPath) };
  if (process.env.TLS_CA) opts.ca = fs.readFileSync(process.env.TLS_CA);

  const s = https.createServer(opts, (req, res) => {
    res.writeHead(200, { "content-type": "text/plain" });
    res.end("VC WSS server OK\n");
  });

  return { server: s, port: PORT, directWss: true };
}

module.exports = { makeServer };
