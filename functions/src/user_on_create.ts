import * as functions from "firebase-functions/v1";
import { db, now, region } from "./bootstrap";

export const onAuthCreate = functions
  .region(region)
  .auth.user()
  .onCreate(async (user) => {
    await db.doc(`users/${user.uid}`).set(
      {
        displayName: user.displayName ?? "",
        photoURL: user.photoURL ?? "",
        level: "Beginner",
        sports: [],
        bio: "",
        joinedYear: new Date().getFullYear(),
        badges: [],
        mutedThreads: [],
        blockedUsers: [],
        premium: { active: false, tier: null, expiresAt: null },
        createdAt: now(),
        updatedAt: now(),
      },
      { merge: true }
    );
  });
