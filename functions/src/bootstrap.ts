import * as admin from "firebase-admin";
admin.initializeApp();

export const db = admin.firestore();
export const region = "europe-west1"; // keep same region as Firestore/Storage
export const now = () => admin.firestore.Timestamp.now();
export { admin };
