import { HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { DocumentData, Timestamp } from "firebase-admin/firestore";
import { db } from "../bootstrap";
import { sendToUser } from "../notify";

export function requireUid(req: CallableRequest): string {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");
  return uid;
}

export function check(cond: unknown, message: string,
  code: "invalid-argument" | "failed-precondition" | "permission-denied" | "not-found" = "invalid-argument"): asserts cond {
  if (!cond) throw new HttpsError(code, message);
}

export async function getUserData(uid: string): Promise<DocumentData> {
  const snap = await db.doc(`users/${uid}`).get();
  check(snap.exists, "Profile not found.", "not-found");
  return snap.data()!;
}

/** Name/photo/trust info copied onto listings and bookings for display. */
export function publicInfo(u: DocumentData) {
  return {
    name: (u.name as string) ?? "",
    photoUrl: (u.photoUrl as string) ?? "",
    rating: (u.rating as number) ?? null,
    reviewCount: (u.reviewCount as number) ?? 0,
    verified: u.verified === true,
  };
}

export function str(v: unknown, field: string, min: number, max: number): string {
  check(typeof v === "string", `${field} is required.`);
  const s = v.trim();
  check(s.length >= min && s.length <= max, `${field} must be ${min}–${max} characters.`);
  return s;
}

export function optStr(v: unknown, max: number): string | null {
  if (v == null || v === "") return null;
  check(typeof v === "string" && v.trim().length <= max, "Text too long.");
  return v.trim();
}

/** Euro amount with at most 2 decimals, or null when not given. */
export function money(v: unknown, field: string, required: boolean): number | null {
  if (v == null || v === "") {
    check(!required, `${field} is required.`);
    return null;
  }
  check(typeof v === "number" && isFinite(v) && v >= 0, `${field} must be a positive amount.`);
  return Math.round(v * 100) / 100;
}

export function oneOf<T extends string>(v: unknown, allowed: readonly T[], field: string): T {
  check(typeof v === "string" && (allowed as readonly string[]).includes(v), `Invalid ${field}.`);
  return v as T;
}

/** Only accept Storage download URLs under the caller's own folder. */
export function ownedPhotoUrls(v: unknown, folder: string, min: number, max: number): string[] {
  const list = Array.isArray(v) ? v : [];
  check(list.length >= min && list.length <= max, `Add ${min}–${max} photos.`);
  const prefix = `/o/${encodeURIComponent(folder)}`;
  for (const u of list) {
    check(typeof u === "string" &&
      u.startsWith("https://firebasestorage.googleapis.com/") && u.includes(prefix),
    "Invalid photo.");
  }
  return list as string[];
}

export const now = () => Timestamp.now();
export const inDays = (d: number) => Timestamp.fromMillis(Date.now() + d * 86400000);
export const inHours = (h: number) => Timestamp.fromMillis(Date.now() + h * 3600000);

/** Push without failing the caller if FCM errors. */
export function notify(uid: string, title: string, body: string, data: Record<string, string> = {}) {
  return sendToUser(uid, title, body, data).catch(() => undefined);
}

export const storeChatId = (listingId: string, customerUid: string) =>
  `store_${listingId}_${customerUid}`;
