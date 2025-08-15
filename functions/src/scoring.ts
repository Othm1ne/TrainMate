import { GeoPoint, Timestamp } from "firebase-admin/firestore";

export type TMUser = {
  uid: string;
  sports: string[];
  level: "Beginner" | "Intermediate" | "Expert";
  location?: GeoPoint;
  lastActive?: Timestamp;
};

export function haversineKm(a: GeoPoint, b: GeoPoint): number {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const R = 6371;
  const dLat = toRad(b.latitude - a.latitude);
  const dLon = toRad(b.longitude - a.longitude);
  const lat1 = toRad(a.latitude);
  const lat2 = toRad(b.latitude);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

function jaccard(a: string[], b: string[]) {
  const A = new Set(a);
  const B = new Set(b);
  const inter = [...A].filter((x) => B.has(x)).length;
  const union = new Set([...a, ...b]).size || 1;
  return inter / union;
}

function levelScore(a: TMUser["level"], b: TMUser["level"]) {
  if (a === b) return 1;
  const order = ["Beginner", "Intermediate", "Expert"];
  return Math.abs(order.indexOf(a) - order.indexOf(b)) === 1 ? 0.5 : 0;
}

function recencyScore(ts?: Timestamp) {
  if (!ts) return 0;
  const hours = (Date.now() - ts.toDate().getTime()) / 36e5;
  if (hours <= 24) return 1;
  if (hours >= 24 * 30) return 0;
  return 1 - (hours - 24) / (24 * 29);
}

export function computeScore(me: TMUser, other: TMUser, maxKm = 25) {
  if (!me.location || !other.location) {
    return { score: 0, distanceKm: Number.POSITIVE_INFINITY, overlap: 0 };
  }
  const d = haversineKm(me.location, other.location);
  const distanceScore = Math.max(0, 1 - d / maxKm);
  const overlap = jaccard(me.sports || [], other.sports || []);
  const lvl = levelScore(me.level, other.level);
  const rec = recencyScore(other.lastActive);

  const score = 0.5 * overlap + 0.3 * distanceScore + 0.1 * lvl + 0.1 * rec;
  return { score, distanceKm: d, overlap };
}
