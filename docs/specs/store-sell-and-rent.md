# Spec: TrainMate Store (sell & rent sports equipment)

Status: **Decisions approved (§16), waiting for go-ahead**
Owner: Othmane · Last update: 2026-10-26

## 1. Goal

Let TrainMate users **sell** and **rent out** sports equipment to people nearby,
and **buy** or **rent** from them, reusing the community, chat and trust features
the app already has.

Why it matters for the business:
- More reasons to open the app every week, even without a training partner.
- Renting fits the target well: people want to try padel, climbing or
  surfing without buying €200+ of gear first.
- New revenue (boosts now, commission later) and partners (shops, clubs).

Launch: **Paris**, with **running, padel and cycling** first (same as partner matching).

## 2. Scope by version

| Version | Contents |
|---|---|
| **V1 – Listings + requests** (this spec) | Sale and rental listings, search and filters, contact owner via chat, rental requests with dates and accept/decline, availability calendar, handover/return check with photos, reviews, moderation, boosts, **verified rental owners**, **pro shop accounts**, **hand delivery + seller-arranged shipping** |
| **V2 – Trust & retention** | Saved searches + alerts, favorites, ID-document verification, stats for owners and shops |
| **V3 – Payments** | In-app payment (Stripe Connect), **in-app deposit hold**, commission, payouts, **integrated shipping labels + tracking** (Boxtal / Mondial Relay), dispute flow, optional rental insurance partner |

**V1 has no in-app payments and no deposits.** Buyers and renters pay the
owner directly (cash, Lydia, PayPal, …). The app records the agreed price and
the item's condition, but does not hold money. Deposits **belong in the app**:
they arrive with payments in V3, and every place that will need them is
marked `TODO(deposit)` in this spec and in the code.

## 3. Users & roles

- **Customer** (any signed-in user): buys or rents.
- **Seller** (any signed-in user): posts *sale* listings.
- **Rental owner** (**verified users only**): posts *rent* or *both* listings
  and accepts or declines rental requests. "Verified" in V1 means all of:
  1. email address verified,
  2. phone number verified by SMS (Firebase Phone Auth, linked to the account),
  3. profile photo and full name set.

  The server sets `verified: true`, never the client. An unverified user who
  picks "Rent" is taken to a short **Get verified** flow. ID-document
  verification comes in V2.
- **Pro shop** (business account, **from V1**): a verified user who adds trader
  details (§4.4). Gets a **Pro** badge, unlimited listings and a shop page, and
  must follow consumer law (§10).

## 4. Listings

### 4.1 Listing types
A listing is **for sale**, **for rent**, or **both** (e.g. "rent €8/day or buy €120").

### 4.2 Fields

| Field | Required | Notes |
|---|---|---|
| Title | ✅ | 5–80 chars |
| Description | ✅ | 20–2000 chars |
| Sport | ✅ | from `allSports` |
| Category | ✅ | Racket, Ball, Bike, Board, Protection, Clothing, Shoes, Fitness machine, Camping/Hiking, Other |
| Photos | ✅ | 1–8 images, first one is the cover, ≤ 5 MB each |
| Condition | ✅ | New · Like new · Good · Fair |
| Brand, size | – | Free text; size shown for shoes/clothing/bikes |
| Mode | ✅ | sale / rent / both (rent and both: verified users only) |
| Sale price | if sale | € |
| Rent price | if rent | per day, plus optional weekend and week prices |
| Min / max rental days | if rent | default 1 / 14 |
| Deposit | – | **Not in V1.** `TODO(deposit)`: field reserved in the data model, collected and held in-app in V3 |
| Pickup area | ✅ | City / neighbourhood. Location stored rounded to ~1 km like profiles; exact address shared in chat only |
| Delivery (sale) | ✅ | **Hand delivery** always available; optional **Can ship** with a shipping price set by the seller. V1: the seller ships and shares tracking in chat. V3: integrated labels |
| Status | auto | `pending_review`, `active`, `reserved`, `sold`, `paused`, `removed` |

### 4.3 Rules
- Max **20 active listings** per free user; unlimited for Premium and pro shops.
- Rent/both listings can only be created by verified users (enforced by the UI, the rules and the functions).
- Listings expire after **60 days** without an edit; the owner gets a reminder to renew.
- Editing the price or photos of an active listing sends it back to automatic moderation (§8).

### 4.4 Pro shop accounts (V1)
Required trader details (EU Digital Services Act "traceability"), shown on the
shop page: company name, **SIRET**, business address, contact email and phone,
and a link to the shop's terms (returns/withdrawal).
- Created from Profile → **Open a pro shop** → form → `pending` until an
  admin checks the SIRET (manually in V1, with the public INSEE/SIRENE lookup)
  → `approved`.
- Pro listings show a **Pro** badge and "14-day withdrawal right applies".
- Customers can filter *Private sellers · Pro shops*.
- Partner shops are the cold-start plan for the catalogue: sign 5–10 Paris
  running/padel/cycling shops before opening the store to everyone.

## 5. User flows

### 5.1 Browse & search
- Store tab: search bar plus filters for **Sport, Category, Buy/Rent, price range,
  condition, distance** (5/10/25/50 km), **Can ship**, **Private / Pro**.
  Sort by **Nearest / Newest / Price**.
- The rent filter can take **dates**, hiding items already booked on those dates.
- Default feed: the user's sports first, nearest first, boosted listings on top
  (marked "Sponsored").
- Listing card: cover photo, title, price ("€120" or "€8/day"), distance,
  rent/sale badge, Pro badge, owner rating.

### 5.2 Listing detail
- Photo carousel, all fields, map area (a circle, not the exact point), owner card
  (name, photo, Verified/Pro badges, rating, number of rentals/sales,
  "member since") or shop card.
- Rental: availability calendar (booked days greyed out) and price summary
  for the chosen dates.
- Buttons: **Contact owner** · **Request rental** (if rent) · ♥ Save (V2) ·
  Share · Report.

### 5.3 Buying (V1 = no in-app payment)
1. Customer taps **Contact owner** → chat opens, linked to the listing (listing preview at the top).
2. They agree on price and on **hand delivery** or **shipping** (if the listing
   allows it; the seller ships and shares the tracking number in chat).
3. Seller taps **Mark as reserved** (optional), then **Mark as sold** and
   picks the buyer from the people who chatted about the listing.
4. Both are asked to leave a review (§7).

### 5.4 Renting
```
requested ──► accepted ──► picked_up ──► returned ──► completed
    │             │             │
    ├► declined   ├► cancelled  └► disputed ──► resolved
    └► expired (no answer in 48 h)
```
1. **Request**: the customer picks dates (respecting min/max days and availability),
   sees the total = days × price (weekend/week prices applied when cheaper), adds a
   message, and sends. The dates are only *held* for the owner to decide, not yet
   blocked for others. `TODO(deposit)`: show and authorise the deposit here.
2. **Owner answers** within 48 h: Accept (dates become blocked) or Decline
   (optional reason). No answer means `expired`.
3. **Pickup**: at handover, both open the booking. The owner takes 1–4 photos of the
   item's condition and taps **Handed over**; the customer confirms → `picked_up`.
   The rental price is paid directly to the owner. `TODO(deposit)`: capture
   the deposit hold at this step in V3.
4. **Return**: the owner takes return photos and either taps **Returned OK** →
   `returned` → `completed`, or **Report a problem** → `disputed` (description
   + photos; sent to moderation). `TODO(deposit)`: release the hold on
   *Returned OK*; on a dispute, keep it until resolved.
5. Reviews for both sides (§7).
6. **Cancellation**: either side can cancel before pickup; cancelling less than 24 h
   before the start is counted on the profile ("cancelled late ×2").
7. **Reminders** (push): new request (owner), accepted/declined (customer),
   pickup tomorrow (both), return due tomorrow (customer), return overdue
   (both), please review (both).

### 5.5 Owner tools
- **My listings**: status, views, number of messages, pause/edit/delete, boost.
- **My rentals**: tabs *Requests · Upcoming · Active · Past*, as owner and as customer.
- **Get verified**: phone number → SMS code → badge (shown when needed).
- **My shop** (pro): trader details, approval status, shop page preview.

## 6. Chat integration
- Store chats are **separate from match chats**: one chat per *(listing,
  customer)*, id `store_{listingId}_{customerUid}`, with a `listingId` field.
- Shown in the existing Chat tab with a small listing thumbnail and a "Store" label;
  a filter chip switches between *All · Partners · Store*.
- The listing preview and the rental status card are pinned at the top of the chat.
- Mute, block and report work as they do today.

## 7. Reviews
- After a completed sale or rental, both sides can rate 1–5 ⭐ and write an
  optional comment (≤ 500 chars) within 14 days.
- Reviews appear once **both** sides have written theirs or the 14 days are over
  (so neither side can retaliate after reading the other's).
- The profile and shop page show the average rating and number of reviews.
  Ratings also feed into partner matching (trust), which addresses the safety concern
  from the user interviews.

## 8. Moderation & safety
- **Prohibited items**: supplements and medication, weapons (incl. knives, air guns,
  pepper spray), counterfeits, used underwear/swimwear, helmets or child seats
  that have had a crash, anything illegal. Linked from the "post listing" screen.
- **Automatic check** on create/edit (Cloud Function): a keyword list and price
  sanity check (e.g. €0 or > €20 000). A hit puts the listing in
  `pending_review`; otherwise it goes straight to `active`.
- **Reports** on listings, users, shops and bookings go to the `reports` collection.
  An admin screen is needed to review them and to approve shops (see the admin
  dashboard item in the business roadmap).
- 3 confirmed reports, or 2 unresolved disputes, suspend the user from the store.
- Safety tips are shown before the first meeting: meet in a public place, check the
  item, don't pay in advance to strangers.

## 9. Money (V1)
- **Free to post** (up to 20 active listings).
- **Boost**: listing pinned to the top of searches in its area for 7 days, **€1.99**.
  Premium users get 2 free boosts per month. *In V1 boosts are granted by the
  server without payment (like Premium today), marked `TODO(payments)` for
  RevenueCat / in-app purchase.*
- Pro shops: free during launch; a monthly shop subscription is an option later.
- V3: **commission** of 8–10% on in-app payments (customer pays a service fee).

## 10. Legal notes (France / EU), to confirm with a lawyer or accountant
> Pro shops are in V1, so the DSA trader-traceability and consumer-law points
> apply **from launch**.

- **Digital Services Act**: marketplaces must offer a notice-and-action
  (report) system, clear terms, the reasons when content is removed, and
  traceability of **pro** sellers (name, address, SIRET), covered by §4.4.
- **Consumer law**: between private individuals there is no legal right of withdrawal.
  Pro shops are subject to the 14-day withdrawal right and warranties, so pro
  listings are clearly labelled.
- **DAC7** (EU tax reporting by platforms) applies once the platform handles
  **payments** for sales of goods or rentals of transport (bikes!). V1
  without payments avoids collecting tax data; V3 must collect it.
- **Rental agreement**: the in-app booking (dates, price, condition photos,
  acceptance timestamps) acts as the record of agreement. Terms must state that
  TrainMate is a matching platform and not a party to the rental.
- **Shipping in V1** is arranged between the users; the terms must say TrainMate
  is not responsible for parcels until integrated shipping (V3).
- **GDPR**: phone numbers are only used for verification and are never shown. Chat
  and handover photos are kept 12 months after the booking ends, then deleted.

## 11. Data model (Firestore)

```
listings/{listingId}
  ownerId, title, description, sport, category, condition, brand, size,
  mode: 'sale'|'rent'|'both',
  salePrice?, rentPerDay?, rentPerWeekend?, rentPerWeek?,
  deposit?                                            // TODO(deposit): unused in V1
  minDays, maxDays,
  canShip, shippingPrice?,
  sellerType: 'private'|'pro', shopId?,
  photos: [url], area: 'Paris 11e', lat, lng (rounded), geohash,
  status, boostedUntil?, views, createdAt, updatedAt, expiresAt,
  ownerInfo: {name, photoUrl, rating, reviewCount, verified}   // denormalised for cards

listings/{listingId}/blocked/{yyyy-mm-dd}            // one doc per booked day
  bookingId                                           // makes overlap checks atomic

bookings/{bookingId}
  listingId, ownerId, customerId, members: [ownerId, customerId],
  start, end (dates), days, price,
  deposit?, depositStatus?                            // TODO(deposit): V3 hold/capture/release
  status: requested|accepted|declined|expired|cancelled|picked_up|returned|completed|disputed|resolved,
  message, declineReason?, cancelledBy?, lateCancel?,
  handoverPhotos: [url], returnPhotos: [url], disputeNote?,
  listingSnapshot: {title, cover, rentPerDay},        // what the customer agreed to
  createdAt, updatedAt, history: [{status, by, at}]

sales/{saleId}            // created by "Mark as sold"
  listingId, sellerId, buyerId, price, delivery: 'hand'|'ship', createdAt

reviews/{reviewId}
  targetUid, authorUid, context: 'rental'|'sale', refId, stars, text,
  visible: bool, createdAt

shops/{shopId}            // pro shop accounts
  ownerUid, companyName, siret, address, email, phone, termsUrl,
  status: pending|approved|rejected|suspended, createdAt

users/{uid}               // new fields, server-managed
  rating, reviewCount, storeSuspended, freeBoostsLeft,
  verified, phoneVerified, shopId?

chats/{store_{listingId}_{customerUid}}
  + kind: 'store', listingId, listingInfo: {title, cover}
```

Storage: `listings/{ownerUid}/{listingId}/{n}.jpg`,
`bookings/{bookingId}/{handover|return}/{n}.jpg` (members only).

Indexes: listings by `status + sport + createdAt`, `status + geohash`,
`ownerId + status`, `status + sellerType`; bookings by `members (array) + status + start`.

## 12. Backend (Cloud Functions)

| Function | Type | Does |
|---|---|---|
| `onListingWrite` | Firestore trigger | Moderation keyword/price check → status; maintains geohash and `ownerInfo` |
| `contactOwner(listingId)` | callable | Creates or returns the store chat (clients can't create chats) |
| `requestRental(listingId, start, end, message)` | callable | Validates dates, min/max days and availability; computes the price **server-side**; creates the booking; notifies the owner |
| `respondRental(bookingId, accept, reason?)` | callable | In a transaction: re-checks overlap, writes `blocked/` days, updates status, notifies |
| `updateRental(bookingId, action, photos?)` | callable | pickup / return / dispute / cancel transitions with role checks. `TODO(deposit)` hooks |
| `markSold(listingId, buyerUid, delivery)` | callable | Status sold, creates the `sales/` doc, asks for reviews |
| `submitReview(...)` | callable | Checks a completed booking or sale exists; reveals reviews when both are in; updates the rating |
| `boostListing(listingId)` | callable | Uses a free boost or (later) a verified purchase. `TODO(payments)` |
| `refreshVerification()` | callable | After phone linking: checks email verified + phone + photo/name → sets `verified` |
| `applyForShop(details)` | callable | Validates the SIRET format, creates `shops/{id}` as `pending` |
| `storeScheduler` | scheduled, hourly | Expires unanswered requests (48 h), sends reminders, expires old listings, closes review windows |

All status changes happen **only** in functions; security rules make
`bookings`, `sales`, `reviews`, `shops` and `blocked` read-only for clients.

## 13. Security rules (summary)
- `listings`: everyone signed in can read `active` ones; the owner can read all of theirs.
  The owner can create and update content fields only. Creating a `rent`/`both` listing
  requires `users/{uid}.verified == true`, and pro listings require an approved shop.
  `status` (except `paused`), `ownerInfo`, `boostedUntil`, `views` and `sellerType`
  are server-only.
- `bookings`: readable by `members`; no client writes.
- `reviews`: readable when `visible == true` or by the author; no client writes.
- `shops`: readable by all signed-in users when `approved` (and by the owner); no client writes.
- `users`: `verified`, `phoneVerified`, `rating`, `reviewCount`, `storeSuspended`,
  `freeBoostsLeft` and `shopId` are added to the server-only fields.
- Storage: listing photos are writable through the owner's path only; booking photos by
  booking members only (checked through a Firestore lookup).

## 14. App changes
- **Navigation**: the bottom bar keeps 5 items. **Store replaces the Premium tab**;
  Premium moves to the ⭐ button on Home (already there) and to a Profile entry.
- New screens: Store feed · Filters · Listing detail · Post/Edit listing
  (multi-step: photos → details → price, rental terms & delivery → preview) ·
  Request rental (calendar) · Booking detail (status timeline + actions) ·
  My listings · My rentals · Write review · Get verified (phone SMS) ·
  Open a pro shop · Shop page.
- Profile: rating ⭐, Verified/Pro badges, "Listings" section, reviews list.
- Chat: Store label/filter, listing header, booking status card.

## 15. Acceptance criteria (V1)
- [ ] A user can post a sale listing with photos, and it shows in the feed within 5 s.
- [ ] An unverified user cannot create a rent listing (UI, rules and function all refuse); after phone verification they can.
- [ ] A listing with a prohibited keyword is not public until approved.
- [ ] Search filters (sport, category, buy/rent, price, condition, distance, dates, can ship, private/pro) return correct results.
- [ ] Two customers requesting the same dates: only one can be accepted; the other request becomes unavailable.
- [ ] The price shown to the customer equals what the server stores.
- [ ] Full rental lifecycle works with push notifications at each step, including expiry after 48 h.
- [ ] Handover and return photos are visible only to the two members.
- [ ] Reviews stay hidden until both sides submit or 14 days pass; the rating updates.
- [ ] A client cannot change booking status, prices, ratings, verification, boosts or shop status directly (rules tests).
- [ ] Mark as sold removes the listing from search and records hand delivery or shipping.
- [ ] A pro shop shows its trader details and the Pro badge only after approval.
- [ ] "Can ship" listings show the shipping price.
- [ ] Store chats are separate from partner chats; block/report work.
- [ ] Every deposit hook is marked `TODO(deposit)` (grep check).
- [ ] Unit tests for price calculation and date overlap; rules tests in the emulator.

## 16. Decisions (2026-10-26)
| # | Question | Decision |
|---|---|---|
| 1 | Deposit | Should live **in the app**. Skipped in V1; reserved fields + `TODO(deposit)` markers; built with V3 payments |
| 2 | Who can rent out | **Verified users only** (email + phone SMS + photo/name in V1) |
| 3 | Pro shops at launch | **Yes**, with DSA trader details and manual SIRET approval |
| 4 | Boost price / listing limit | **€1.99 per 7 days**, **20** free active listings |
| 5 | Delivery | **Both**: hand delivery + seller-arranged shipping in V1; integrated labels in V3 |
| 6 | Launch | **Paris; running, padel, cycling** first |

## 17. Rough effort
| Part | Estimate |
|---|---|
| Listings + feed + filters + post/edit | 4–5 days |
| Rental flow (functions, calendar, booking screens) | 4–5 days |
| Chat integration, reviews, profile changes | 2–3 days |
| Moderation, scheduler, notifications | 2 days |
| Phone verification + pro shop accounts | 3–4 days |
| Rules, tests, polish | 2–3 days |
| **Total V1** | **≈ 3.5–4 weeks** |

Setup needed from Othmane before building: enable **Phone** sign-in in Firebase
Authentication (SMS costs apply beyond the free tier) and add test phone numbers
for development.
