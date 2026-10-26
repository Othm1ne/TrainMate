import { test } from "node:test";
import assert from "node:assert/strict";
import { addDays, dayCount, dayList, isDay, overlaps, weekday } from "./dates";
import { isWeekendRental, rentalPrice } from "./pricing";
import { moderationFlags } from "./moderation";
import { isValidSiret } from "./siret";

test("dates", () => {
  assert.equal(isDay("2026-11-14"), true);
  assert.equal(isDay("2026-02-30"), false);
  assert.equal(isDay("14/11/2026"), false);
  assert.equal(dayCount("2026-11-14", "2026-11-14"), 1);
  assert.equal(dayCount("2026-12-30", "2027-01-02"), 4);
  assert.deepEqual(dayList("2026-02-27", "2026-03-01"), ["2026-02-27", "2026-02-28", "2026-03-01"]);
  assert.equal(addDays("2026-12-31", 1), "2027-01-01");
  assert.equal(weekday("2026-11-14"), 6); // Saturday
  assert.equal(overlaps("2026-11-10", "2026-11-12", "2026-11-12", "2026-11-15"), true);
  assert.equal(overlaps("2026-11-10", "2026-11-11", "2026-11-12", "2026-11-15"), false);
});

test("rental price: daily", () => {
  assert.equal(rentalPrice({ rentPerDay: 8 }, "2026-11-10", "2026-11-12"), 24);
});

test("rental price: week package beats daily, and covers partial weeks when cheaper", () => {
  const t = { rentPerDay: 10, rentPerWeek: 50 };
  assert.equal(rentalPrice(t, "2026-11-02", "2026-11-08"), 50); // 7 days
  assert.equal(rentalPrice(t, "2026-11-02", "2026-11-07"), 50); // 6 days: week (50) < 60
  assert.equal(rentalPrice(t, "2026-11-02", "2026-11-04"), 30); // 3 days: daily
  assert.equal(rentalPrice(t, "2026-11-02", "2026-11-10"), 70); // 9 days: week + 2 days
});

test("rental price: weekend package", () => {
  const t = { rentPerDay: 10, rentPerWeekend: 15 };
  assert.equal(isWeekendRental("2026-11-14", "2026-11-15"), true); // Sat–Sun
  assert.equal(isWeekendRental("2026-11-13", "2026-11-15"), true); // Fri–Sun
  assert.equal(isWeekendRental("2026-11-15", "2026-11-16"), false); // Sun–Mon
  assert.equal(rentalPrice(t, "2026-11-13", "2026-11-15"), 15);
  assert.equal(rentalPrice(t, "2026-11-15", "2026-11-16"), 20);
});

test("rental price rounds to cents", () => {
  assert.equal(rentalPrice({ rentPerDay: 3.333 }, "2026-11-10", "2026-11-12"), 10);
});

test("moderation", () => {
  assert.deepEqual(moderationFlags({ title: "Raquette padel Bullpadel", description: "Très bon état, peu servie." }), []);
  assert.ok(moderationFlags({ title: "Whey protéine 2kg", description: "Pot neuf jamais ouvert" })
    .includes("keyword:whey"));
  assert.ok(moderationFlags({ title: "Couteau de chasse", description: "pour randonnée" }).length > 0);
  assert.ok(moderationFlags({ title: "Vélo route", description: "Carbone taille M", salePrice: 0 })
    .includes("salePrice:zero"));
  // whole words only: "slipper" must not match "slip"
  assert.deepEqual(moderationFlags({ title: "Slippers de piscine", description: "Taille 42 bleu" }), []);
});

test("siret", () => {
  assert.equal(isValidSiret("732 829 320 00074"), true); // public example (Luhn-valid)
  assert.equal(isValidSiret("73282932000075"), false);
  assert.equal(isValidSiret("1234"), false);
});
