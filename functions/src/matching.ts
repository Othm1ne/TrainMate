import * as geofire from "geofire-common";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { db, now, region } from "./bootstrap";
import { computeScore, TMUser } from "./scoring";

const USERS = "users";

async function getUser(uid: string): Promise<TMUser | null> {
  const snap = await db.doc(`${USERS}/${uid}`).get();
  if (!snap.exists) return null;
  const d = snap.data()!;
  return {
    uid,
    sports: Array.isArray(d.sports) ? d.sports : [],
    level: (d.level as TMUser["level"]) ?? "Beginner",
    location: d.location,
    lastActive: d.updatedAt ?? d.createdAt,
  };
}

export const refreshRecommendationsForUser = onCall(
  { region },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in");
    await rebuildFor(uid);
    return { ok: true };
  }
);

export const nightlyRecommendations = onSchedule(
  { region, schedule: "every 24 hours", timeZone: "Africa/Casablanca" },
  async () => {
    const batchSize = 200;
    const q = db.collection(USERS).orderBy("updatedAt", "desc").limit(batchSize);
    const snaps = await q.get();
    await Promise.all(snaps.docs.map((d) => rebuildFor(d.id)));
  }
);

async function rebuildFor(uid: string): Promise<void> {
  const me = await getUser(uid);
  if (!me || !me.location) return;

  const radiusInM = 25_000;
  const center: [number, number] = [
    me.location.latitude,
    me.location.longitude,
  ];
  const bounds = geofire.geohashQueryBounds(center, radiusInM);

  const seen = new Set<string>();
  const candidates: FirebaseFirestore.DocumentData[] = [];

  for (const b of bounds) {
    const snap = await db
      .collection(USERS)
      .orderBy("geohash")
      .startAt(b[0])
      .endAt(b[1])
      .limit(200)
      .get();

    for (const doc of snap.docs) {
      if (doc.id === uid) continue;
      if (!seen.has(doc.id)) {
        candidates.push({ id: doc.id, ...doc.data() });
        seen.add(doc.id);
      }
    }
  }

  const mine = new Set<string>(me.sports || []);
  const filtered = candidates.filter((c) => {
    const sports: string[] = Array.isArray(c.sports) ? c.sports : [];
    return sports.some((s) => mine.has(s));
  });

  const others: TMUser[] = filtered.map((c) => ({
    uid: c.id as string,
    sports: Array.isArray(c.sports) ? c.sports : [],
    level: (c.level as TMUser["level"]) ?? "Beginner",
    location: c.location,
    lastActive: c.updatedAt ?? c.createdAt,
  }));

  const scored = others
    .map((o) => ({ o, m: computeScore(me, o, 25) }))
    .sort((a, b) => b.m.score - a.m.score)
    .slice(0, 20);

  const col = db.collection(USERS).doc(uid).collection("recommendations");
  const batch = db.batch();
  const old = await col.get();
  old.forEach((d) => batch.delete(d.ref));

  for (const { o, m } of scored) {
    batch.set(col.doc(o.uid), {
      targetUid: o.uid,
      score: Math.round(m.score * 1000) / 1000,
      distanceKm: Math.round(m.distanceKm * 10) / 10,
      overlap: Math.round(m.overlap * 100) / 100,
      reason: `Shared sports & ${m.distanceKm.toFixed(1)} km away`,
      createdAt: now(),
    });
  }
  await batch.commit();
}
