import { onCall } from "firebase-functions/v2/https";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { getAuth } from "firebase-admin/auth";
import { db, region } from "../bootstrap";
import { check, getUserData, notify, now, optStr, requireUid, str } from "./common";
import { isValidSiret } from "./siret";
import { syncOwnerInfo } from "./reviews";

/**
 * "Verified" (spec §3): email verified + phone number verified by SMS
 * (linked in Firebase Auth) + profile photo and name. Only the server sets it.
 * Call after linking a phone number or verifying the email.
 */
export const refreshVerification = onCall({ region }, async (req) => {
  const uid = requireUid(req);
  const [authUser, profile] = await Promise.all([getAuth().getUser(uid), getUserData(uid)]);
  const missing: string[] = [];
  if (!authUser.emailVerified) missing.push("email");
  if (!authUser.phoneNumber) missing.push("phone");
  if (!profile.photoUrl) missing.push("photo");
  if (!(profile.name ?? "").trim()) missing.push("name");
  const verified = missing.length === 0;

  await db.doc(`users/${uid}`).update({ verified, phoneVerified: !!authUser.phoneNumber });
  if (verified !== (profile.verified === true)) await syncOwnerInfo(uid);
  return { verified, missing };
});

/** Pro shop application (spec §4.4). An admin approves it in the console. */
export const applyForShop = onCall({ region }, async (req) => {
  const uid = requireUid(req);
  const user = await getUserData(uid);
  check(user.verified === true, "Get verified before opening a pro shop.", "failed-precondition");
  check(!["pending", "approved"].includes(user.shopStatus), "You already have a shop.", "failed-precondition");

  const d = req.data ?? {};
  const siret = str(d.siret, "SIRET", 14, 17).replace(/\s/g, "");
  check(isValidSiret(siret), "This SIRET number is not valid.");
  const email = str(d.email, "Email", 5, 120);
  check(/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email), "Invalid email.");
  const termsUrl = optStr(d.termsUrl, 300);
  check(!termsUrl || /^https:\/\//.test(termsUrl), "Terms link must start with https://");

  const ref = db.collection("shops").doc();
  await ref.set({
    ownerUid: uid,
    companyName: str(d.companyName, "Company name", 2, 100),
    siret,
    address: str(d.address, "Address", 10, 200),
    email,
    phone: str(d.phone, "Phone", 6, 30),
    termsUrl,
    description: optStr(d.description, 500),
    status: "pending",
    createdAt: now(),
  });
  await db.doc(`users/${uid}`).update({ shopId: ref.id, shopStatus: "pending" });
  return { shopId: ref.id };
});

/**
 * Admin changes shops/{id}.status in the Firebase console
 * (pending → approved | rejected | suspended). Keep the owner and their
 * listings in sync.
 */
export const onShopUpdated = onDocumentUpdated({ region, document: "shops/{shopId}" }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after || before.status === after.status) return;
  const { shopId } = event.params;
  const approved = after.status === "approved";

  await db.doc(`users/${after.ownerUid}`).update({ shopStatus: after.status, shopId });
  const listings = await db.collection("listings").where("ownerId", "==", after.ownerUid).get();
  const batch = db.batch();
  listings.docs.forEach((l) => batch.update(l.ref, {
    sellerType: approved ? "pro" : "private", shopId: approved ? shopId : null,
  }));
  await batch.commit();

  const messages: Record<string, [string, string]> = {
    approved: ["Your pro shop is live 🏪", `${after.companyName} is approved. Your listings now show the Pro badge.`],
    rejected: ["Pro shop not approved", "We couldn't verify your business details. Check them and apply again."],
    suspended: ["Pro shop suspended", "Your shop was suspended. Contact support for details."],
  };
  const m = messages[after.status];
  if (m) await notify(after.ownerUid, m[0], m[1], { type: "shop", shopId });
});
