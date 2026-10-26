import { db } from "./bootstrap";
import { getMessaging } from "firebase-admin/messaging";

/**
 * Sends a push notification to every device registered under
 * users/{uid}/devices/{token}, and removes tokens that are no longer valid.
 */
export async function sendToUser(
  uid: string,
  title: string,
  body: string,
  data: Record<string, string> = {}
): Promise<void> {
  const devices = await db.collection(`users/${uid}/devices`).get();
  const tokens = devices.docs.map((d) => d.id).filter(Boolean);
  if (!tokens.length) return;

  const res = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data,
  });

  const stale = res.responses
    .map((r, i) => ({ r, token: tokens[i] }))
    .filter(({ r }) =>
      r.error?.code === "messaging/registration-token-not-registered" ||
      r.error?.code === "messaging/invalid-registration-token")
    .map(({ token }) => db.doc(`users/${uid}/devices/${token}`).delete());
  await Promise.all(stale);
}
