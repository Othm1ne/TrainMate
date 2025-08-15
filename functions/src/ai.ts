import OpenAI from "openai";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { db, region } from "./bootstrap";

const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

export const aiCoachPlan = onCall(
  { region, secrets: [OPENAI_API_KEY] },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in");

    const goal = String(req.data?.goal ?? "general fitness");
    const sports: string[] = Array.isArray(req.data?.sports) ? req.data.sports : [];

    const openai = new OpenAI({ apiKey: OPENAI_API_KEY.value() });
    const prompt =
      `Create a 7-day training plan for: ${goal}.\n` +
      `User sports: ${sports.join(", ")}.\n` +
      `Each day list: workout name, duration, sets/reps (if gym), intensity.`;

    const res = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [{ role: "user", content: prompt }],
      temperature: 0.7,
    });

    const plan = res.choices[0]?.message?.content?.trim() || "No plan generated.";
    await db.collection("users").doc(uid)
      .collection("coach_plans").add({ goal, sports, plan, createdAt: new Date() });

    return { plan };
  }
);

export const aiRecoReason = onCall(
  { region, secrets: [OPENAI_API_KEY] },
  async (req) => {
    const a = String(req.data?.A ?? "");
    const b = String(req.data?.B ?? "");
    const info = (req.data?.info ?? {}) as any;

    const openai = new OpenAI({ apiKey: OPENAI_API_KEY.value() });
    const prompt =
      `Write one short sentence why ${a} and ${b} are a good sports match.\n` +
      `Shared sports: ${info.sharedSports ?? "n/a"}.\n` +
      `Distance: ${info.distanceKm ?? "?"} km.\n` +
      `Level: ${info.level ?? "n/a"}.\n` +
      `Keep it friendly and concise.`;

    const res = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [{ role: "user", content: prompt }],
      temperature: 0.7,
    });
    return { reason: res.choices[0]?.message?.content?.trim() ?? "" };
  }
);
