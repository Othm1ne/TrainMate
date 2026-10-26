// Rental dates are calendar days ("yyyy-mm-dd", inclusive), not instants.

const DAY_MS = 24 * 60 * 60 * 1000;
const DAY_RE = /^\d{4}-\d{2}-\d{2}$/;

export function isDay(s: unknown): s is string {
  if (typeof s !== "string" || !DAY_RE.test(s)) return false;
  return toDay(parseDay(s)) === s; // rejects 2026-02-30
}

/** Midnight UTC of the given day. */
export function parseDay(s: string): Date {
  const [y, m, d] = s.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d));
}

export function toDay(d: Date): string {
  return d.toISOString().slice(0, 10);
}

export function addDays(day: string, n: number): string {
  return toDay(new Date(parseDay(day).getTime() + n * DAY_MS));
}

/** Number of days from start to end, both included. */
export function dayCount(start: string, end: string): number {
  return Math.round((parseDay(end).getTime() - parseDay(start).getTime()) / DAY_MS) + 1;
}

export function dayList(start: string, end: string): string[] {
  const n = dayCount(start, end);
  return Array.from({ length: Math.max(0, n) }, (_, i) => addDays(start, i));
}

/** 0 = Sunday … 6 = Saturday. */
export function weekday(day: string): number {
  return parseDay(day).getUTCDay();
}

/** Today's date in Paris (the launch market). */
export function todayParis(now = new Date()): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Paris", year: "numeric", month: "2-digit", day: "2-digit",
  }).format(now);
}

export function overlaps(aStart: string, aEnd: string, bStart: string, bEnd: string): boolean {
  return aStart <= bEnd && bStart <= aEnd;
}
