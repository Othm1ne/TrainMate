import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { db, region } from "./bootstrap";

export const onAttendeeWrite = onDocumentWritten(
  { region, document: "events/{eventId}/attendees/{uid}" },
  async (event) => {
    const { eventId } = event.params as { eventId: string; uid: string };
    const ref = db.doc(`events/${eventId}`);

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const curr = snap.exists ? (snap.data()!.attendeeCount || 0) : 0;

      const before = event.data?.before.exists ?? false;
      const after = event.data?.after.exists ?? false;

      let next = curr;
      if (!before && after) next = curr + 1;            // joined
      else if (before && !after) next = Math.max(0, curr - 1); // left

      tx.set(ref, { attendeeCount: next, updatedAt: new Date() }, { merge: true });
    });
  }
);
