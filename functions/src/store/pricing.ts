import { dayCount, dayList, weekday } from "./dates";

// Mirror of lib/src/features/store/data/rental_pricing.dart (keep in sync).
// The server value is the one stored on the booking.

export interface RentTerms {
  rentPerDay: number;
  rentPerWeekend?: number | null; // a Fri–Sun or Sat–Sun rental
  rentPerWeek?: number | null; // 7 consecutive days
}

const round2 = (n: number) => Math.round(n * 100) / 100;

/** A "weekend" rental: 2–3 days, only Fri/Sat/Sun, including Saturday and Sunday. */
export function isWeekendRental(start: string, end: string): boolean {
  const days = dayList(start, end).map(weekday);
  return days.length >= 2 && days.length <= 3 &&
    days.includes(6) && days.includes(0) &&
    days.every((d) => d === 5 || d === 6 || d === 0);
}

/** Cheapest total for the rental, combining daily and weekly prices. */
export function rentalPrice(t: RentTerms, start: string, end: string): number {
  const days = dayCount(start, end);
  if (days < 1) throw new Error("end before start");
  const week = t.rentPerWeek ?? null;

  // cost[d] = cheapest way to cover d days with day and week units
  // (a week may cover fewer than 7 remaining days if that's cheaper).
  const cost = new Array<number>(days + 1).fill(0);
  for (let d = 1; d <= days; d++) {
    cost[d] = cost[d - 1] + t.rentPerDay;
    if (week != null) cost[d] = Math.min(cost[d], cost[Math.max(0, d - 7)] + week);
  }
  let best = cost[days];
  if (t.rentPerWeekend != null && isWeekendRental(start, end)) {
    best = Math.min(best, t.rentPerWeekend);
  }
  return round2(best);
}
