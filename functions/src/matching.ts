/* functions/src/matching.ts */
import * as admin from 'firebase-admin';
import {
  onCall,
  HttpsError,
  CallableRequest,
} from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { haversineDistanceKm } from './utils/haversine';
import { scoreMatch } from './scoring';

admin.initializeApp();
const db = admin.firestore();

const REGION = 'europe-west1';
const MAX_DISTANCE_KM = 25;
const LIMIT = 30;

/**
 * Callable: recompute recommendations for the signed-in user.
 */
export const refreshRecommendationsForUser = onCall(
  { region: REGION },
  async (request: CallableRequest<unknown>) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Login required');
    }
    const uid = request.auth.uid;

    const meSnap = await db.doc(`users/${uid}`).get();
    if (!meSnap.exists) {
      throw new HttpsError('not-found', 'User doc missing');
    }
    const me = meSnap.data()!;
    if (!me.location) {
      throw new HttpsError(
        'failed-precondition',
        'Location missing'
      );
    }

    const myLat = me.location.lat;
    const myLng = me.location.lng;
    const mySports: string[] = me.sports ?? [];

    /* ---------- fetch candidates ---------- */
    const usersSnap = await db.collection('users').where('location', '!=', null).get();
    const scored: {
      otherUid: string;
      profile: FirebaseFirestore.DocumentData;
      score: number;
      distanceKm: number;
      overlap: number;
    }[] = [];

    usersSnap.forEach((d) => {
      if (d.id === uid) return;
      const p = d.data();
      const dist = haversineDistanceKm(myLat, myLng, p.location.lat, p.location.lng);
      if (dist > MAX_DISTANCE_KM) return;

      const overlap = (p.sports ?? []).filter((s: string) => mySports.includes(s)).length;
      if (overlap === 0) return;

      scored.push({
        otherUid: d.id,
        profile: p,
        distanceKm: dist,
        overlap,
        score: scoreMatch({
          overlap,
          distanceKm: dist,
          levelDiff: Math.abs((me.level ?? 1) - (p.level ?? 1)),
        }),
      });
    });

    scored.sort((a, b) => b.score - a.score).splice(LIMIT);

    /* ---------- write subcollection ---------- */
    const itemsRef = db.collection('recommendations').doc(uid).collection('items');
    // delete previous
    (await itemsRef.listDocuments()).forEach((doc) => doc.delete());

    const batch = db.batch();
    scored.forEach((s) => {
      batch.set(itemsRef.doc(s.otherUid), {
        name: s.profile.name ?? null,
        age: s.profile.age ?? null,
        sports: s.profile.sports ?? [],
        photoUrl: s.profile.photoUrl ?? null,
        score: s.score,
        distanceKm: s.distanceKm,
        overlap: s.overlap,
        ts: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    await batch.commit();

    return { written: scored.length };
  }
);

/**
 * Nightly refresh for all users (02:00 UTC).
 * You can keep or delete this cron job.
 */
export const nightlyRecommendations = onSchedule(
  { region: REGION, schedule: '0 2 * * *' },
  async () => {
    const users = await db.collection('users').listDocuments();
    for (const u of users) {
      await refreshRecommendationsForUser.run({ context: { auth: { uid: u.id } } } as any);
    }
  }
);
