import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

initializeApp();

export const db = getFirestore();
export const region = "europe-west1"; // must match FirebaseFunctions.instanceFor(region:) in the app

/** Free accounts get this many likes per day (UTC); Premium is unlimited. */
export const FREE_DAILY_LIKES = 20;

/** yyyy-mm-dd in UTC — same as todayKey() in the app. */
export const todayKey = (d = new Date()) => d.toISOString().slice(0, 10);
