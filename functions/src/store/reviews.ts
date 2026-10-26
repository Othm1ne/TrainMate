import { onCall } from "firebase-functions/v2/https";
import { Timestamp, Transaction } from "firebase-admin/firestore";
import { db, region } from "../bootstrap";
import { check, now, oneOf, optStr, requireUid, str } from "./common";

/*
 * Reviews (spec §7): after a completed rental or a sale, each side may rate
 * the other within 14 days. A review stays hidden until the other side has
 * reviewed too, or the window closes (scheduler), so neither can retaliate.
 * Doc id: {context}_{refId}_{authorUid} → one review per author per deal.
 */

export const submitReview = onCall({ region }, async (req) => {
  const uid = requireUid(req);
  const context = oneOf(req.data?.context, ["rental", "sale"] as const, "context");
  const refId = str(req.data?.refId, "refId", 10, 40);
  const stars = Number(req.data?.stars);
  check(Number.isInteger(stars) && stars >= 1 && stars <= 5, "Rating must be 1–5 stars.");
  const text = optStr(req.data?.text, 500) ?? "";

  const ref = db.doc(`${context === "rental" ? "bookings" : "sales"}/${refId}`);
  const deal = (await ref.get()).data();
  check(deal, "Not found.", "not-found");
  check((deal.members as string[]).includes(uid), "You weren't part of this.", "permission-denied");
  if (context === "rental") check(deal.status === "completed", "You can review once the rental is completed.", "failed-precondition");
  const deadline = deal.reviewDeadline as Timestamp;
  check(deadline && deadline.toMillis() > Date.now(), "The review window has closed.", "failed-precondition");

  const target = (deal.members as string[]).find((m) => m !== uid)!;
  const mine = db.doc(`reviews/${context}_${refId}_${uid}`);
  const theirs = db.doc(`reviews/${context}_${refId}_${target}`);

  const revealed = await db.runTransaction(async (tx) => {
    const [m, t] = [await tx.get(mine), await tx.get(theirs)];
    check(!m.exists, "You already reviewed this.", "failed-precondition");
    const author = (await tx.get(db.doc(`users/${uid}`))).data() ?? {};
    const review = {
      context, refId, authorUid: uid, targetUid: target, stars, text,
      authorInfo: { name: author.name ?? "", photoUrl: author.photoUrl ?? "" },
      title: deal.listingSnapshot?.title ?? "",
      visible: false, revealAt: deadline, createdAt: now(),
    };
    if (t.exists && !t.data()!.visible) {
      // Both sides are in: reveal both and update both ratings.
      // (All reads happen before any write.)
      await applyRatingsAndReveal(tx, [
        { ref: mine, data: review, isNew: true },
        { ref: theirs, data: t.data()!, isNew: false },
      ]);
      return true;
    }
    tx.set(mine, review);
    return false;
  });
  if (revealed) await Promise.all([syncOwnerInfo(uid), syncOwnerInfo(target)]);
  return { ok: true, revealed };
});

type PendingReview = { ref: FirebaseFirestore.DocumentReference; data: FirebaseFirestore.DocumentData; isNew: boolean };

/** Reveals reviews and adds their stars to each target's rating. */
export async function applyRatingsAndReveal(tx: Transaction, reviews: PendingReview[]) {
  const targets = await Promise.all(reviews.map((r) => tx.get(db.doc(`users/${r.data.targetUid}`))));
  reviews.forEach((r, i) => {
    const u = targets[i].data() ?? {};
    const sum = (u.ratingSum ?? 0) + r.data.stars;
    const count = (u.reviewCount ?? 0) + 1;
    tx.update(targets[i].ref, {
      ratingSum: sum, reviewCount: count, rating: Math.round((sum / count) * 10) / 10,
    });
    if (r.isNew) tx.set(r.ref, { ...r.data, visible: true, revealedAt: now() });
    else tx.update(r.ref, { visible: true, revealedAt: now() });
  });
}

/** Refreshes the owner's rating/verified badge on their live listings. */
export async function syncOwnerInfo(uid: string) {
  const u = (await db.doc(`users/${uid}`).get()).data();
  if (!u) return;
  const live = await db.collection("listings").where("ownerId", "==", uid)
    .where("status", "in", ["active", "pending_review", "reserved", "paused", "expired"]).get();
  const batch = db.batch();
  live.docs.forEach((d) => batch.update(d.ref, {
    "ownerInfo.rating": u.rating ?? null,
    "ownerInfo.reviewCount": u.reviewCount ?? 0,
    "ownerInfo.verified": u.verified === true,
    "ownerInfo.name": u.name ?? "",
    "ownerInfo.photoUrl": u.photoUrl ?? "",
  }));
  await batch.commit();
}
