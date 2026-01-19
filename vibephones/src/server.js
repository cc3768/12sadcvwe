// src/server.js
import "dotenv/config";
import express from "express";
import session from "express-session";
import passport from "passport";

import "./auth/google.js";
import { authRouter } from "./routes/auth.js";
import { ensurePhoneIdentity } from "./userStore.js";
import { registerAppStoreHttp, handleAppStoreWS } from "./appstore.js";
import http from "http";
import WebSocket, { WebSocketServer } from "ws";
const app = express();

app.set("trust proxy", 1);
app.use(express.json());

const FOURTEEN_DAYS_MS = 14 * 24 * 60 * 60 * 1000;

app.use(
  session({
    name: "vibephone.sid",
    secret: process.env.SESSION_SECRET || "change_me",
    resave: false,
    saveUninitialized: false,
    rolling: true,
    cookie: {
      maxAge: FOURTEEN_DAYS_MS,
      httpOnly: true,
      sameSite: "lax",
      secure: process.env.NODE_ENV === "production",
    },
  })
);

app.use(passport.initialize());
app.use(passport.session());

// Auth routes first
app.use("/auth", authRouter);

function requireAuth(req, res, next) {
  if (req.user) return next();
  return res.redirect("/auth/google");
}

// Website entry point
app.get("/", (req, res) => {
  if (req.user) return res.redirect("/phone.html");
  return res.redirect("/auth/google");
});

// API that phone.html can call to get identity (optional but recommended)
app.get("/api/phone", requireAuth, async (req, res) => {
  try {
    const u = await ensurePhoneIdentity(req.user.id);
    res.json({
      ok: true,
      phone: {
        call: u.callNumber ?? 0,
        key: u.phoneKey,
        deviceId: u.deviceId,
        name: u.name ?? "",
        email: u.email ?? "",
      },
    });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e?.message || e) });
  }
});

// ✅ Protect phone.html (served from /public)
app.get("/phone.html", requireAuth, (req, res) => {
  res.sendFile("phone.html", { root: "public" });
});

// Static assets last
app.use(express.static("public"));

// AppStore HTTP (optional but useful for debugging / wget installs)
registerAppStoreHttp(app);

// ---- WS on /ws ----
const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: "/ws" });

function send(socket, obj) {
  if (socket.readyState === WebSocket.OPEN) {
    socket.send(JSON.stringify(obj));
  }
}

wss.on("connection", (socket) => {
  socket.send(JSON.stringify({ t: "hello", ok: true }));

  socket.on("message", (buf) => {
    let msg;
    try { msg = JSON.parse(buf.toString()); }
    catch { return socket.send(JSON.stringify({ t: "error", error: "bad_json" })); }

    // ✅ AppStore protocol (apps_list, app_fetch, ping)
    const handled = handleAppStoreWS(socket, msg, WebSocket, send);
    if (handled) return;

    // TEMP echo (keep for debugging)
    socket.send(JSON.stringify({ t: "echo", ok: true, msg }));
  });
});

const port = Number(process.env.PORT || 8080);
server.listen(port, "0.0.0.0", () => console.log(`http://localhost:${port}`));
