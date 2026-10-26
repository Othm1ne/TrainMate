// Business rules for the Store (docs/specs/store-sell-and-rent.md).

/** Keep in sync with lib/src/shared/sports.dart. */
export const SPORTS = [
  "Running", "Cycling", "Swimming", "Gym", "CrossFit", "Bodybuilding",
  "Yoga", "Pilates", "Meditation", "Boxing", "MMA", "Karate",
  "Football", "Basketball", "Volleyball", "Tennis", "Badminton", "Padel",
  "Hiking", "Climbing", "Surfing", "Dance", "Calisthenics", "Rowing",
];

/** Keep in sync with lib/src/features/store/data/listing.dart. */
export const CATEGORIES = [
  "Racket", "Ball", "Bike", "Board", "Protection", "Clothing", "Shoes",
  "Fitness machine", "Camping/Hiking", "Other",
];
export const CONDITIONS = ["New", "Like new", "Good", "Fair"];
export const MODES = ["sale", "rent", "both"] as const;
export type Mode = typeof MODES[number];

export const FREE_ACTIVE_LISTINGS = 20;
export const LISTING_TTL_DAYS = 60;
export const MAX_PHOTOS = 8;
export const BOOST_DAYS = 7;
export const BOOST_PRICE_EUR = 1.99; // TODO(payments): charged via in-app purchase
export const FREE_BOOSTS_PER_MONTH_PREMIUM = 2;

export const REQUEST_TTL_HOURS = 48;
export const MAX_ADVANCE_DAYS = 180;
export const REVIEW_WINDOW_DAYS = 14;
export const LATE_CANCEL_HOURS = 24;
export const MAX_HANDOVER_PHOTOS = 4;
export const MAX_PRICE_EUR = 20000;

/** Listing statuses that count toward the free listing limit. */
export const LIVE_STATUSES = ["active", "pending_review", "reserved", "paused"];
