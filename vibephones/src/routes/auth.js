// src/routes/auth.js
import express from "express";
import passport from "passport";

export const authRouter = express.Router();

authRouter.get(
  "/google",
  passport.authenticate("google", { scope: ["profile", "email"] })
);

authRouter.get(
  "/google/callback",
  passport.authenticate("google", {
    failureRedirect: "/login.html?error=google",
    session: true,
  }),
  (req, res) => {
    // ✅ after auth, drop them on the phone page
    res.redirect("/phone.html");
  }
);

authRouter.get("/me", (req, res) => {
  if (!req.user) return res.status(401).json({ ok: false });
  res.json({ ok: true, user: req.user });
});

authRouter.post("/logout", (req, res) => {
  const cookieName = "vibephone.sid";

  req.logout((err) => {
    if (err) return res.status(500).json({ ok: false, error: String(err) });

    const clear = () => {
      res.clearCookie(cookieName, {
        path: "/",
        httpOnly: true,
        sameSite: "lax",
        secure: process.env.NODE_ENV === "production",
      });
      res.status(204).end();
    };

    if (req.session) req.session.destroy(() => clear());
    else clear();
  });
});
