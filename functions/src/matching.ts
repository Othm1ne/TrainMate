import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db, region, todayKey, FREE_DAILY_LIKES } from "./bootstrap";
import { sendToUser } from "./notify";

const chatIdFor = (a: string, b: string) => [a, b].sort().join("_");

/**
 * Records a like/pass. Runs on the server so the daily like limit can't be
 * bypassed and chats are only ever created for real mutual likes.
 *
 * data: { toUid: string, liked: boolean }
 * returns: { matched: boolean, likesLeft: number | null }
 */
export const swipe = onCall({ region }, async (req) => {
  const me = req.auth?.uid;
  if (!me) throw new HttpsError("unauthenticated", "Sign in first.");
  const to = String(req.data?.toUid ?? "");
  const liked = req.data?.liked === true;
  if (!to || to === me) throw new HttpsError("invalid-argument", "Bad toUid.");

  const meRef = db.doc(`users/${me}`);
  const otherRef = db.doc(`users/${to}`);
  const swipeRef = db.doc(`users/${me}/swipes/${to}`);
  const backRef = db.doc(`users/${to}/swipes/${me}`);
  const chatRef = db.doc(`chats/${chatIdFor(me, to)}`);
  const today = todayKey();

  const result = await db.runTransaction(async (tx) => {
    const [meSnap, otherSnap, backSnap] = await Promise.all([
      tx.get(meRef), tx.get(otherRef), tx.get(backRef),
    ]);
    if (!meSnap.exists || !otherSnap.exists) {
      throw new HttpsError("not-found", "Profile not found.");
    }
    const m = meSnap.data()!;
    const o = otherSnap.data()!;
    const blocked = (m.blocked ?? []).includes(to) || (o.blocked ?? []).includes(me);
    const premium = m.isPremium === true;
    const used = m.likesDate === today ? (m.likesCount ?? 0) : 0;

    if (liked && !premium && used >= FREE_DAILY_LIKES) {
      throw new HttpsError("resource-exhausted", "Daily like limit reached.");
    }

    tx.set(swipeRef, { from: me, to, liked, at: FieldValue.serverTimestamp() });
    if (!liked) return { matched: false, likesLeft: premium ? null : FREE_DAILY_LIKES - used };

    tx.update(meRef, { likesDate: today, likesCount: used + 1 });
    const likesLeft = premium ? null : FREE_DAILY_LIKES - used - 1;

    const matched = !blocked && backSnap.exists && backSnap.data()?.liked === true;
    if (matched) {
      tx.set(chatRef, {
        members: [me, to],
        memberInfo: {
          [me]: { name: m.name ?? "", photoUrl: m.photoUrl ?? "" },
          [to]: { name: o.name ?? "", photoUrl: o.photoUrl ?? "" },
        },
        lastMessage: "You matched! Say hi 👋",
        lastTime: FieldValue.serverTimestamp(),
        mutedBy: [],
        blockedBy: [],
      }, { merge: true });
    }
    return { matched, likesLeft, myName: m.name as string };
  });

  if (result.matched) {
    await sendToUser(to, "It's a match! 🎉",
      `You and ${result.myName ?? "someone"} want to train together.`,
      { type: "match", chatId: chatIdFor(me, to) }).catch(() => undefined);
  }
  return { matched: result.matched, likesLeft: result.likesLeft };
});

/**
 * Turns Premium on for the caller.
 * TODO before release: verify an App Store / Play / Stripe receipt here
 * (req.data.receipt) instead of granting Premium unconditionally.
 */
export const activatePremium = onCall({ region }, async (req) => {
  const me = req.auth?.uid;
  if (!me) throw new HttpsError("unauthenticated", "Sign in first.");
  await db.doc(`users/${me}`).update({ isPremium: true });
  return { ok: true };
});
