// src/auth/google.js
import passport from "passport";
import { Strategy as GoogleStrategy } from "passport-google-oauth20";

import {
  findUserByGoogleSub,
  findUserByEmail,
  createUser,
  linkGoogleSubToUser,
  updateUser,
  getUserById,
  ensurePhoneIdentity,
} from "../userStore.js";

console.log("[auth] google strategy file loaded");

passport.serializeUser((user, done) => {
  // store Airtable record id
  done(null, user.id);
});

passport.deserializeUser(async (id, done) => {
  try {
    const user = await getUserById(id);
    done(null, user);
  } catch (e) {
    done(e);
  }
});

passport.use(
  new GoogleStrategy(
    {
      clientID: process.env.GOOGLE_CLIENT_ID,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET,
      callbackURL: process.env.GOOGLE_CALLBACK_URL,
    },
    async (_accessToken, _refreshToken, profile, done) => {
      try {
        const googleSub = profile?.id;
        if (!googleSub) return done(new Error("Google profile missing id"));

        const email = profile?.emails?.[0]?.value ?? null;
        const name = profile?.displayName ?? null;

        // 1) Prefer match by googleSub
        let user = await findUserByGoogleSub(googleSub);

        if (user) {
          await updateUser(user.id, { email, name });
          user = await ensurePhoneIdentity(user.id);
          return done(null, user);
        }

        // 2) Optional: link by email
        if (email) {
          const byEmail = await findUserByEmail(email);
          if (byEmail) {
            user = await linkGoogleSubToUser(byEmail.id, googleSub, name);
            user = await ensurePhoneIdentity(user.id);
            return done(null, user);
          }
        }

        // 3) Create new user (includes generated phone identity)
        user = await createUser({ googleSub, email, name });
        user = await ensurePhoneIdentity(user.id);
        return done(null, user);
      } catch (e) {
        return done(e);
      }
    }
  )
);

console.log("[auth] google strategy registered");
