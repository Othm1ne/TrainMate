import { onCall, HttpsError } from "firebase-functions/v2/https";
import { DocumentData, FieldValue, Timestamp } from "firebase-admin/firestore";
import { db, region } from "../bootstrap";
import { LATE_CANCEL_HOURS, MAX_ADVANCE_DAYS, MAX_HANDOVER_PHOTOS, REVIEW_WINDOW_DAYS } from "./constants";
import { addDays, dayCount, dayList, isDay, overlaps, parseDay, todayParis } from "./dates";
import { rentalPrice } from "./pricing";
import { ensureStoreChat } from "./listings";
import {
  check, getUserData, inDays, notify, now, oneOf, optStr, ownedPhotoUrls, publicInfo,
  requireUid, storeChatId, str,
} from "./common";

/*
 * Booking lifecycle (spec §5.4):
 *   requested → accepted → picked_up → completed
 *   requested → declined | expired | cancelled
 *   accepted  → cancelled
 *   picked_up → disputed → resolved (admin)
 * Accepting writes one listings/{id}/blocked/{day} doc per day inside a
 * transaction, so two bookings can never hold the same day.
 */

const fmt = (day: string) =>
  parseDay(day).toLocaleDateString("en-GB", { day: "numeric", month: "short", timeZone: "UTC" });
const range = (b: DocumentData) => b.start === b.end ? fmt(b.start) : `${fmt(b.start)}–${fmt(b.end)}`;

function historyEntry(status: string, by: string) {
  return FieldValue.arrayUnion({ status, by, at: Timestamp.now() });
}

async function blockedDays(listingId: string, start: string, end: string): Promise<string[]> {
  const snap = await db.collection(`listings/${listingId}/blocked`)
    .where("__name__", ">=", db.doc(`listings/${listingId}/blocked/${start}`))
    .where("__name__", "<=", db.doc(`listings/${listingId}/blocked/${end}`))
    .get();
  return snap.docs.map((d) => d.id);
}

export const requestRental = onCall({ region }, async (req) => {
  const uid = requireUid(req);
  const listingId = str(req.data?.listingId, "listingId", 10, 40);
  const start = req.data?.start;
  const end = req.data?.end;
  check(isDay(start) && isDay(end) && start <= end, "Invalid dates.");
  const message = optStr(req.data?.message, 500) ?? "";

  const today = todayParis();
  check(start >= today, "Start date is in the past.");
  check(start <= addDays(today, MAX_ADVANCE_DAYS), `You can book up to ${MAX_ADVANCE_DAYS} days ahead.`);

  const l = (await db.doc(`listings/${listingId}`).get()).data();
  check(l && l.status === "active" && l.mode !== "sale", "This item is not available for rent.", "failed-precondition");
  check(l.ownerId !== uid, "This is your own listing.");
  const days = dayCount(start, end);
  check(days >= l.minDays && days <= l.maxDays, `Rentals last ${l.minDays}–${l.maxDays} days.`);

  const customer = await getUserData(uid);
  check(customer.storeSuspended !== true, "Your store access is suspended.", "permission-denied");
  check((await blockedDays(listingId, start, end)).length === 0,
    "Some of these days are already booked.", "failed-precondition");

  const pending = await db.collection("bookings")
    .where("listingId", "==", listingId).where("customerId", "==", uid)
    .where("status", "==", "requested").get();
  check(pending.empty, "You already have a pending request for this item.", "failed-precondition");

  const owner = await getUserData(l.ownerId);
  const price = rentalPrice(l as { rentPerDay: number }, start, end);
  const ref = db.collection("bookings").doc();
  const booking = {
    listingId,
    ownerId: l.ownerId,
    customerId: uid,
    members: [l.ownerId, uid],
    ownerInfo: publicInfo(owner),
    customerInfo: publicInfo(customer),
    start, end, days, price,
    // TODO(deposit): authorise the deposit hold here (Stripe) and store its id.
    deposit: null,
    depositStatus: null,
    status: "requested",
    message,
    listingSnapshot: {
      title: l.title, cover: l.photos?.[0] ?? "",
      rentPerDay: l.rentPerDay, rentPerWeekend: l.rentPerWeekend ?? null, rentPerWeek: l.rentPerWeek ?? null,
    },
    handoverPhotos: [],
    returnPhotos: [],
    createdAt: now(),
    updatedAt: now(),
    history: [{ status: "requested", by: uid, at: Timestamp.now() }],
  };
  await ref.set(booking);

  const chatId = await ensureStoreChat(listingId, l, uid, `Rental request: ${range(booking)}`);
  await db.doc(`chats/${chatId}`).update({
    lastMessage: `📅 Rental request: ${range(booking)}`, lastTime: FieldValue.serverTimestamp(),
  });
  await notify(l.ownerId, "New rental request 📅",
    `${customer.name ?? "Someone"} wants "${l.title}" for ${range(booking)} (€${price}).`,
    { type: "booking", bookingId: ref.id });
  return { bookingId: ref.id, price, chatId };
});

export const respondRental = onCall({ region }, async (req) => {
  const uid = requireUid(req);
  const bookingId = str(req.data?.bookingId, "bookingId", 10, 40);
  const accept = req.data?.accept === true;
  const reason = optStr(req.data?.reason, 300);
  const ref = db.doc(`bookings/${bookingId}`);

  const result = await db.runTransaction(async (tx) => {
    const b = (await tx.get(ref)).data();
    check(b, "Booking not found.", "not-found");
    check(b.ownerId === uid, "Only the owner can answer.", "permission-denied");
    check(b.status === "requested", "This request was already answered.", "failed-precondition");

    if (!accept) {
      tx.update(ref, { status: "declined", declineReason: reason, updatedAt: now(), history: historyEntry("declined", uid) });
      return { b, status: "declined" };
    }
    const dayRefs = dayList(b.start, b.end).map((d) => db.doc(`listings/${b.listingId}/blocked/${d}`));
    const taken = (await tx.getAll(...dayRefs)).some((s) => s.exists);
    if (taken) {
      tx.update(ref, {
        status: "declined", declineReason: "Dates no longer available", updatedAt: now(),
        history: historyEntry("declined", uid),
      });
      return { b, status: "unavailable" };
    }
    dayRefs.forEach((r) => tx.set(r, { bookingId }));
    tx.update(ref, { status: "accepted", acceptedAt: now(), updatedAt: now(), history: historyEntry("accepted", uid) });
    return { b, status: "accepted" };
  });

  const { b, status } = result;
  if (status === "unavailable") {
    throw new HttpsError("failed-precondition", "These dates were just booked by someone else. The request was declined.");
  }
  await notify(b.customerId,
    status === "accepted" ? "Rental accepted ✅" : "Rental declined",
    status === "accepted" ?
      `"${b.listingSnapshot.title}" is yours for ${range(b)}. Arrange the pickup in the chat.` :
      `"${b.listingSnapshot.title}" isn't available for ${range(b)}.${reason ? ` ${reason}` : ""}`,
    { type: "booking", bookingId });

  if (status === "accepted") await declineOverlapping(b.listingId, bookingId, b.start, b.end);
  return { status };
});

/** Other pending requests for days that are now taken are declined. */
async function declineOverlapping(listingId: string, keepId: string, start: string, end: string) {
  const pending = await db.collection("bookings")
    .where("listingId", "==", listingId).where("status", "==", "requested").get();
  for (const doc of pending.docs) {
    const o = doc.data();
    if (doc.id === keepId || !overlaps(start, end, o.start, o.end)) continue;
    await doc.ref.update({
      status: "declined", declineReason: "Dates taken by another rental", updatedAt: now(),
      history: historyEntry("declined", "system"),
    });
    await notify(o.customerId, "Rental declined",
      `"${o.listingSnapshot.title}" was booked by someone else for those dates.`,
      { type: "booking", bookingId: doc.id });
  }
}

async function releaseDays(listingId: string, bookingId: string, fromDay?: string) {
  const snap = await db.collection(`listings/${listingId}/blocked`).where("bookingId", "==", bookingId).get();
  const batch = db.batch();
  snap.docs.filter((d) => !fromDay || d.id >= fromDay).forEach((d) => batch.delete(d.ref));
  await batch.commit();
}

/**
 * Lifecycle actions after acceptance:
 *  handover      (owner, accepted)       condition photos → waits for customer
 *  confirmPickup (customer, accepted)    → picked_up
 *  returnOk      (owner, picked_up)      return photos → completed
 *  dispute       (owner, picked_up)      note + photos → disputed (moderation)
 *  cancel        (either, requested/accepted, before pickup) → cancelled
 */
export const updateRental = onCall({ region }, async (req) => {
  const uid = requireUid(req);
  const bookingId = str(req.data?.bookingId, "bookingId", 10, 40);
  const action = oneOf(req.data?.action,
    ["handover", "confirmPickup", "returnOk", "dispute", "cancel"] as const, "action");
  const ref = db.doc(`bookings/${bookingId}`);
  const b = (await ref.get()).data();
  check(b, "Booking not found.", "not-found");
  const isOwner = b.ownerId === uid;
  const isCustomer = b.customerId === uid;
  check(isOwner || isCustomer, "Not your booking.", "permission-denied");
  const other = isOwner ? b.customerId : b.ownerId;
  const title = b.listingSnapshot.title as string;
  const photosFolder = `bookings/${uid}/${bookingId}/`;
  const expect = (role: boolean, status: string) => {
    check(role, "You can't do this.", "permission-denied");
    check(b.status === status, "Not possible in the current state.", "failed-precondition");
  };

  switch (action) {
  case "handover": {
    expect(isOwner, "accepted");
    const photos = ownedPhotoUrls(req.data?.photos, photosFolder, 1, MAX_HANDOVER_PHOTOS);
    await ref.update({ handoverPhotos: photos, handedOverAt: now(), updatedAt: now() });
    await notify(other, "Confirm pickup", `Did you receive "${title}"? Confirm it in the booking.`,
      { type: "booking", bookingId });
    break;
  }
  case "confirmPickup": {
    expect(isCustomer, "accepted");
    check(b.handedOverAt, "The owner hasn't handed it over yet.", "failed-precondition");
    // TODO(deposit): capture the deposit hold here.
    await ref.update({ status: "picked_up", pickedUpAt: now(), updatedAt: now(), history: historyEntry("picked_up", uid) });
    await notify(other, "Pickup confirmed", `"${title}" is with the renter until ${fmt(b.end)}.`,
      { type: "booking", bookingId });
    break;
  }
  case "returnOk": {
    expect(isOwner, "picked_up");
    const photos = ownedPhotoUrls(req.data?.photos, photosFolder, 1, MAX_HANDOVER_PHOTOS);
    // TODO(deposit): release the deposit hold here.
    await ref.update({
      status: "completed", returnPhotos: photos, completedAt: now(), reviewDeadline: inDays(REVIEW_WINDOW_DAYS),
      updatedAt: now(), history: historyEntry("completed", uid),
    });
    await releaseDays(b.listingId, bookingId, addDays(todayParis(), 1)); // early return frees future days
    for (const to of [b.ownerId, b.customerId]) {
      await notify(to, "Rental completed ✅", `How did it go with "${title}"? Leave a review.`,
        { type: "review", context: "rental", refId: bookingId });
    }
    break;
  }
  case "dispute": {
    expect(isOwner, "picked_up");
    const note = str(req.data?.note, "Description of the problem", 10, 1000);
    const photos = ownedPhotoUrls(req.data?.photos, photosFolder, 0, MAX_HANDOVER_PHOTOS);
    // TODO(deposit): keep the deposit held until the dispute is resolved.
    await ref.update({
      status: "disputed", disputeNote: note, returnPhotos: photos, disputedAt: now(), updatedAt: now(),
      history: historyEntry("disputed", uid),
    });
    await db.collection("reports").add({
      type: "booking", bookingId, reporterId: uid, reportedId: other, reason: note, createdAt: now(),
    });
    await notify(other, "Problem reported", `The owner reported a problem with "${title}". Our team will contact you.`,
      { type: "booking", bookingId });
    break;
  }
  case "cancel": {
    check(["requested", "accepted"].includes(b.status), "It's too late to cancel.", "failed-precondition");
    const hoursToStart = (parseDay(b.start).getTime() - Date.now()) / 3600000;
    const late = b.status === "accepted" && hoursToStart < LATE_CANCEL_HOURS;
    await ref.update({
      status: "cancelled", cancelledBy: uid, lateCancel: late, updatedAt: now(),
      history: historyEntry("cancelled", uid),
    });
    if (b.status === "accepted") await releaseDays(b.listingId, bookingId);
    if (late) await db.doc(`users/${uid}`).update({ lateCancels: FieldValue.increment(1) });
    await notify(other, "Rental cancelled", `The rental of "${title}" for ${range(b)} was cancelled.`,
      { type: "booking", bookingId });
    break;
  }
  }
  return { ok: true };
});

/** Days already booked for a listing (for the availability calendar). */
export const listingAvailability = onCall({ region }, async (req) => {
  requireUid(req);
  const listingId = str(req.data?.listingId, "listingId", 10, 40);
  const today = todayParis();
  return { blocked: await blockedDays(listingId, today, addDays(today, MAX_ADVANCE_DAYS)) };
});

export { storeChatId };
