import { MAX_PRICE_EUR } from "./constants";

// Listings matching these go to `pending_review` until an admin approves them
// (spec §8). Matching is accent/case-insensitive on whole words.
const PROHIBITED = [
  // supplements & medication
  "protein", "proteine", "whey", "creatine", "steroid", "steroide", "anabolisant",
  "anabolic", "medicament", "medication", "pills", "pilules", "testosterone",
  // weapons
  "knife", "couteau", "poignard", "dagger", "machette", "machete", "airsoft",
  "pistolet", "gun", "fusil", "rifle", "carabine", "taser", "lacrymogene",
  "pepper spray", "gaz lacrymo", "matraque", "baton telescopique",
  // counterfeits
  "contrefacon", "counterfeit", "replica", "replique", "fake",
  // hygiene
  "underwear", "sous-vetement", "sous vetement", "culotte", "slip",
  // damaged safety gear
  "casque accidente", "crashed helmet",
];

const normalize = (s: string) =>
  s.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();

/** Returns the reasons a listing needs manual review (empty = OK). */
export function moderationFlags(input: {
  title: string; description: string; brand?: string | null;
  salePrice?: number | null; rentPerDay?: number | null;
}): string[] {
  const text = ` ${normalize(`${input.title} ${input.description} ${input.brand ?? ""}`)} `
    .replace(/[^a-z0-9-]+/g, " ");
  const flags = PROHIBITED.filter((w) => text.includes(` ${w} `)).map((w) => `keyword:${w}`);
  for (const [name, price] of [["salePrice", input.salePrice], ["rentPerDay", input.rentPerDay]] as const) {
    if (price == null) continue;
    if (price <= 0) flags.push(`${name}:zero`);
    if (price > MAX_PRICE_EUR) flags.push(`${name}:too_high`);
  }
  return flags;
}
