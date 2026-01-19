import passport from "passport";
import { Strategy as GoogleStrategy } from "passport-google-oauth20";
import {
  findUserByGoogleSub,
  findUserByEmail,
  createUser,
  linkGoogleSubToUser,
  updateUser,
  getUserById,
} from "./userStore.js";

passport.serializeUser((user, done) => done(null, user.id)); // Airtable record id

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
    async (accessToken, refreshToken, profile, done) => {
      try {
        const googleSub = profile.id;
        const email = profile.emails?.[0]?.value ?? null;
        const name = profile.displayName ?? null;
        const avatarUrl = profile.photos?.[0]?.value ?? null;

        // 1) Prefer google_sub match
        let user = await findUserByGoogleSub(googleSub);
        if (user) {
          await updateUser(user.id, { email, name, avatarUrl });
          return done(null, user);
        }

        // 2) Optional: email link
        if (email) {
          const byEmail = await findUserByEmail(email);
          if (byEmail) {
            user = await linkGoogleSubToUser(byEmail.id, googleSub, name, avatarUrl);
            return done(null, user);
          }
        }

        // 3) Create new
        user = await createUser({ googleSub, email, name, avatarUrl });
        return done(null, user);
      } catch (e) {
        return done(e);
      }
    }
  )
);
