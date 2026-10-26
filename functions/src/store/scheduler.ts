import { onSchedule } from "firebase-functions/v2/scheduler";
import { Timestamp, FieldValue } from "firebase-admin/firestore";
import { db, region } from "../bootstrap";
import { REQUEST_TTL_HOURS } from "./constants";
import { addDays, todayParis } from "./dates";
import { notify, now } from "./common";
import { applyRatingsAndReveal, syncOwnerInfo } from "./reviews";

/** Hourly housekeeping for the Store (spec §5.4, §4.3, §7). */
export const storeScheduler = onSchedule(
  { region, schedule: "every 60 minutes", timeZone: "Europe/Paris" },
  async () => {
    await Promise.all([
      expireRequests(), pickupReminders(), returnReminders(), expireListings(), revealReviews(),
    ]);
  }
);

async function expireRequests() {
  const cutoff = Timestamp.fromMillis(Date.now() - REQUEST_TTL_HOURS * 3600000);
  const snap = await db.collection("bookings")
    .where("status", "==", "requested").where("createdAt", "<=", cutoff).limit(200).get();
  for (const d of snap.docs) {
    const b = d.data();
    await d.ref.update({
      status: "expired", updatedAt: now(),
      history: FieldValue.arrayUnion({ status: "expired", by: "system", at: Timestamp.now() }),
    });
    await notify(b.customerId, "Request expired", `The owner didn't answer in time for "${b.listingSnapshot.title}".`,
      { type: "booking", bookingId: d.id });
  }
}

async function pickupReminders() {
  const tomorrow = addDays(todayParis(), 1);
  const snap = await db.collection("bookings")
    .where("status", "==", "accepted").where("start", "==", tomorrow).get();
  for (const d of snap.docs) {
    const b = d.data();
    if (b.remindedPickup) continue;
    await d.ref.update({ remindedPickup: true });
    for (const to of b.members as string[]) {
      await notify(to, "Pickup tomorrow", `"${b.listingSnapshot.title}" — confirm the time and place in the chat.`,
        { type: "booking", bookingId: d.id });
    }
  }
}

async function returnReminders() {
  const today = todayParis();
  const snap = await db.collection("bookings")
    .where("status", "==", "picked_up").where("end", "<=", addDays(today, 1)).get();
  for (const d of snap.docs) {
    const b = d.data();
    if (b.end < today && !b.remindedOverdue) {
      await d.ref.update({ remindedOverdue: true });
      for (const to of b.members as string[]) {
        await notify(to, "Return overdue ⚠️", `"${b.listingSnapshot.title}" was due back on ${b.end}.`,
          { type: "booking", bookingId: d.id });
      }
    } else if (b.end === addDays(today, 1) && !b.remindedReturn) {
      await d.ref.update({ remindedReturn: true });
      await notify(b.customerId, "Return due tomorrow", `Remember to return "${b.listingSnapshot.title}".`,
        { type: "booking", bookingId: d.id });
    }
  }
}

async function expireListings() {
  const snap = await db.collection("listings")
    .where("status", "==", "active").where("expiresAt", "<=", Timestamp.now()).limit(200).get();
  for (const d of snap.docs) {
    await d.ref.update({ status: "expired", updatedAt: now() });
    await notify(d.data().ownerId, "Listing expired", `"${d.data().title}" was hidden after 60 days. Renew it in My listings.`,
      { type: "listing", listingId: d.id });
  }
}

async function revealReviews() {
  const snap = await db.collection("reviews")
    .where("visible", "==", false).where("revealAt", "<=", Timestamp.now()).limit(200).get();
  const targets = new Set<string>();
  for (const d of snap.docs) {
    await db.runTransaction(async (tx) => {
      const fresh = await tx.get(d.ref);
      if (!fresh.exists || fresh.data()!.visible) return;
      await applyRatingsAndReveal(tx, [{ ref: d.ref, data: fresh.data()!, isNew: false }]);
    });
    targets.add(d.data().targetUid);
  }
  for (const uid of targets) await syncOwnerInfo(uid);
}
