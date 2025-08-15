import * as geofire from "geofire-common";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { admin, db, region } from "./bootstrap";

export const setUserLocation = onCall({ region }, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in");

  const lat = Number(req.data?.lat);
  const lng = Number(req.data?.lng);
  if (!isFinite(lat) || !isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) {
    throw new HttpsError("invalid-argument", "Bad coordinates");
  }

  const geohash = geofire.geohashForLocation([lat, lng]);
  await db.doc(`users/${uid}`).set(
    {
      location: new admin.firestore.GeoPoint(lat, lng),
      geohash,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return { ok: true };
});
