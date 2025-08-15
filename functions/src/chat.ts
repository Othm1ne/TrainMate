import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { admin, db, now, region } from "./bootstrap";

export const likeUser = onCall({ region }, async (req) => {
  const from = req.auth?.uid;
  const to = String(req.data?.toUid ?? "");
  if (!from) throw new HttpsError("unauthenticated", "Sign in");
  if (!to || to === from) throw new HttpsError("invalid-argument", "Bad toUid");

  const ref = db.doc(`likes/${from}_${to}`);
  await ref.set({ from, to, at: now() });

  const mutual = await db.doc(`likes/${to}_${from}`).get();
  if (mutual.exists) {
    const tid = [from, to].sort().join("_");
    const threadRef = db.doc(`threads/${tid}`);
    await db.runTransaction(async (tx) => {
      const t = await tx.get(threadRef);
      if (!t.exists) {
        tx.set(threadRef, {
          memberUids: [from, to],
          createdAt: now(),
          lastAt: now(),
          lastMessage: "You matched! Say hi 👋",
        });
      }
    });
    await sendToUser(to, {
      notification: { title: "It’s a match!", body: "You can now chat together." },
      data: { type: "match", with: from },
    });
  }
  return { ok: true };
});

export const onMessageCreate = onDocumentCreated(
  { region, document: "threads/{tid}/messages/{mid}" },
  async (event) => {
    const msg = event.data?.data();
    if (!msg) return;

    const { tid } = event.params as { tid: string; mid: string };
    const thread = await db.doc(`threads/${tid}`).get();
    if (!thread.exists) return;

    const members: string[] = thread.data()!.memberUids;
    const to = members.find((u) => u !== msg.fromUid);
    if (!to) return;

    await db.doc(`threads/${tid}`).set(
      { lastMessage: (msg.text || "").slice(0, 140), lastAt: now() },
      { merge: true }
    );

    await sendToUser(to, {
      notification: { title: "New message", body: msg.text || "" },
      data: { type: "message", threadId: tid },
    });
  }
);

async function sendToUser(uid: string, payload: admin.messaging.MessagingPayload) {
  const tokensSnap = await db.collection(`users/${uid}/devices`).get();
  const tokens = tokensSnap.docs.map((d) => d.id).filter(Boolean);
  if (!tokens.length) return;
  await admin.messaging().sendEachForMulticast({ tokens, ...payload });
}
