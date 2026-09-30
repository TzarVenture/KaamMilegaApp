# KaamMilega Flutter — Feature Status

> **Last updated:** **30 September 2026** · app branch `feat/map-location-integration` @ `0fa522f` + uncommitted work (chat fix, upcoming-call banner, My Sessions redesign, Home strips, Jobs filter reset, People You May Know grid) · backend `KaamMilega` monorepo `main` @ `5e57311` (read-only).
> Previous audit: 25 September 2026 · `feat/ui-ux-polish` @ `eaf5dc8` · backend `b5a2956`.
> **Quick answer for another AI — what is done / pending:** see [§ Summary](#summary) at the bottom and the "Pending Work" column. Rows changed since 25 Sep are marked **(26–30 Sep)**.
> Feature IDs reuse `flutter_app_feature_tracker.md` where one exists; `MF-xx` IDs are mobile features that tracker does not have (not to be confused with KNOWN_ISSUES `M-xx`).
> **Test state:** 29 Sep run — `flutter analyze` no issues, `flutter test` +309 −1 (the one failure was test setup in `chat_live_socket_test.dart`, fixed in the test; re-run pending). 30 Sep People You May Know grid: format/analyze/test **not run yet**. Phone testing of most 26–30 Sep work is **pending**. Fix batches 1–7 (25 Sep): [KNOWN_ISSUES.md § Fix batches](KNOWN_ISSUES.md#fix-batches-25-sep-2026).
> Scope: candidates/users, guests, gig workers. Employer/Admin features are excluded.
> "Implemented" means the full user flow works end-to-end against the verified backend contract — not just that a screen exists. Runtime behaviour was **not** tested on a device in this audit (no Flutter SDK available); statuses come from code + backend inspection.

**Status:** IMPLEMENTED · PARTIAL · UI ONLY · API INTEGRATED (calls exist, flow incomplete) · PENDING · BACKEND DEPENDENCY · BLOCKED · NOT VERIFIED
**Data:** REAL · LOCAL · CACHED · HC (hard-coded content) · MOCK · FALLBACK
**Pending work owner:** **Flutter** (app work only) · **Backend** (backend must build/fix first) · **Nowhere** (not implemented anywhere yet)

Issue references (C-/H-/M-/L-/B-) → [KNOWN_ISSUES.md](KNOWN_ISSUES.md). Endpoints → [API_CONTRACT.md](API_CONTRACT.md).

---

## Auth & Account

| ID | Feature | User | Flutter Status | API Status | Data | Main Files | Pending Work |
|---|---|---|---|---|---|---|---|
| F01/F04 | Phone OTP login | User | IMPLEMENTED (existing users) | Active | REAL | `auth/presentation/login_screen.dart`, `otp_screen.dart`, `auth/providers/auth_provider.dart` | — |
| F01/F02 | New-user registration after OTP | User | IMPLEMENTED (Batch 1) | Active `POST /user/register` | REAL | `auth/presentation/complete_profile_screen.dart`, `otp_screen.dart`, `auth_guard.dart` | — (C-01 fixed) |
| F05 | Email + password login | User | IMPLEMENTED | Active | REAL | `login_screen.dart` | — |
| F02 | Email + password sign-up | User | IMPLEMENTED | Active | REAL | `register_screen.dart` | — |
| F06 | Forgot / reset password | User | IMPLEMENTED | Active | REAL | `forgot_password_screen.dart` | — |
| MF-01 | Email verification (profile) | User | IMPLEMENTED | Active | REAL | `profile_screen.dart` `_showEmailOtpDialog` | Errors swallowed to `false` (Flutter, minor) |
| F07 | Session restore / 401 handling | User | IMPLEMENTED | Active | REAL + CACHED user | `api_client.dart` (`onUnauthenticated`), `auth_provider.dart` `checkAuthStatus` / `sessionExpired`, `auth_guard.dart` | — (H-05 fixed). Backend moved the website to HttpOnly cookie auth (`e53899e`); the app keeps the Bearer token, which the backend still accepts |
| MF-02 | Logout | User | IMPLEMENTED (Batch 4) | local only (no backend logout route) | LOCAL | `auth_provider.dart` `logout`, `sessionUserIdProvider` | — (H-03 fixed); two logout paths navigate differently (L-05) |
| F99 | Guest mode & route guard | Guest | IMPLEMENTED (Batch 4) | — | — | `auth_guard.dart`, `router.dart`, `shared/widgets/login_required_view.dart` | — (H-04 fixed) |
| F93 | Settings (notifications, visibility, language, password) | User | IMPLEMENTED | Active (`PUT /user/settings`, `PUT /user/password`) | REAL | `profile/presentation/settings_screen.dart` | — |

## Jobs & Applications

| ID | Feature | User | Flutter Status | API Status | Data | Main Files | Pending Work |
|---|---|---|---|---|---|---|---|
| F21 | Job list, search, pagination, blue hero card | Guest, User | IMPLEMENTED **(26–30 Sep: hero card, filters reset when returning from Home)** | Active `GET /jobs` | REAL + CACHED | `jobs/presentation/jobs_screen.dart`, `widgets/jobs_hero_card.dart`, `jobs/providers/jobs_provider.dart` (`resetFilters`), `navigation/presentation/main_navigation_shell.dart` (`_selectTab`) | Cache not per filter — M-09 |
| F22 | Filters (city, type, salary, experience, gender, education) | Guest, User | IMPLEMENTED | Active | REAL; cities FALLBACK on error | `widgets/filter_modal.dart`, `models/job_filter.dart`, `cities/…` | Fallback cities — M-03 |
| F23 | Job detail | Guest, User | IMPLEMENTED | Active `GET /jobs/:id`, `/applications/check/:jobId` | REAL | `job_detail_screen.dart` | `hasApplied` errors → false (H-02) |
| F23 | Apply (cover letter + device resume URL) | User | IMPLEMENTED | Active `POST /applications` | REAL | `applications/presentation/apply_modal.dart` | — |
| F24 | Save / bookmark jobs | Guest (device), User (server) | IMPLEMENTED (Batch 6) | Active `POST /user/bookmark/:jobId`, `GET /jobs/:id` per saved ID | REAL / LOCAL | `jobs_provider.dart` (`savedJobsProvider`, `savedJobDetailProvider`), `saved_jobs_screen.dart` | Chat button route `/chat` missing (L-07); **Backend:** `GET /user/bookmarks` 500 — B-01 |
| F25 | My applications + detail | User | IMPLEMENTED (Batches 3, 5) | Active `GET /applications/my` | REAL + CACHED (offline only) | `my_applications_screen.dart`, `application_detail_screen.dart` | — |
| F29 | Interviews list | User | IMPLEMENTED | Active `GET /interviews/my` | REAL | `interviews/presentation/interviews_screen.dart` | — (error state added, Batch 5) |
| MF-03 | Call recruiter | User | UI ONLY ("coming soon") | none | — | `jobs_screen.dart`, `job_detail_screen.dart`, `application_detail_screen.dart` | **Backend:** recruiter phone not shared |
| MF-04 | Home feed (quick actions, Popular Categories, featured companies, jobs, banners) | Guest, User | PARTIAL **(26–30 Sep: quick actions + Popular Categories scroll horizontally; category photos; featured companies from `GET /companies/top`; voice search)** | Active `GET /jobs`, `GET /companies/top` | REAL jobs/companies + HC sections | `home/presentation/home_screen.dart` (`_HorizontalStrip`), `widgets/featured_companies_section.dart`, `widgets/job_categories_section.dart` | "Recommended" not personalised (L-02); ₹99 Access banner still coming soon (L-01) |
| MF-05 | Jobs based on your profile | User | IMPLEMENTED | Active | REAL | `profile/providers/profile_jobs_provider.dart` | — |

## Profile

| ID | Feature | User | Flutter Status | API Status | Data | Main Files | Pending Work |
|---|---|---|---|---|---|---|---|
| F10 | Intro / about / contact / portfolio link | User | IMPLEMENTED | Active `PATCH /user/profile` | REAL | `profile/presentation/profile_screen.dart` | — |
| F11 | Education | User | IMPLEMENTED (7a) | Active POST, `PUT/DELETE /user/education/:id` | REAL | `profile_screen.dart` `_openAddEducationDialog`, row ⋮ actions | — |
| F12 | Experience | User | IMPLEMENTED (7a) | Active POST, `PUT/DELETE /user/experience/:id` | REAL | `_openAddExperienceDialog`, row ⋮ actions | — |
| F13 | Skills | User | IMPLEMENTED (7b); multi-word remove fails on backend | Active POST, `DELETE /user/skill/:skillName` | REAL | `_openAddSkillDialog`, chip ✕ | **Backend:** decode the skill name (B-07) |
| F14 | Profile & cover photo | User | IMPLEMENTED | Active `POST /files/upload` + PATCH | REAL | `profile_screen.dart` | — |
| F15 | Resume upload | User | PARTIAL | upload active; no profile field | LOCAL URL | `auth_provider.dart` `uploadResumePdf` | **Backend:** resume field on user |
| F16 | Profile strength bar | User | IMPLEMENTED | — (computed) | derived from REAL profile | `_buildProfileCompletenessCard` | — |
| F17 | Projects | User | IMPLEMENTED | Active POST/PUT/DELETE | REAL | `_openAddProjectDialog`, `_buildProjectsCard` | — |
| MF-06 | Open To Work / Providing Services | User, Gig | IMPLEMENTED (7d) — **awaiting test/phone verification** | Active `PATCH /user/open-to-work`, `PATCH /user/providing-services` | REAL; old phone-only text shown, not sent (M-11) | `profile/presentation/widgets/open_to_sheets.dart`, `auth/models/user_profile.dart` | Verify; **Backend:** visibility not enforced (B-09) |
| MF-07 | Gig availability (Online / Offline for spot gigs) | Gig | IMPLEMENTED **(26–30 Sep, see MF-14)** | Active `POST /instant-work/availability` | REAL | `instant_work/presentation/widgets/instant_availability_card.dart` | Phone test |
| MF-08 | Profile analytics (views, impressions, search appearances) | User | IMPLEMENTED **(26–30 Sep: analytics card, impression tracking)** | Active `/user/profile`, `POST /user/impressions` | REAL | `profile/presentation/widgets/profile_analytics_card.dart`, `network/services/impression_tracker.dart` (`ImpressionTracker`, `ImpressionBeacon`) | **Backend:** view debounce not 24 h, update races (B-13) |
| MF-09 | Profile viewers | User | IMPLEMENTED **(26–30 Sep)** — shows public fields only | Active `GET /user/viewers` | REAL | `profile/presentation/profile_viewers_screen.dart` (route `/profile-viewers`, protected) | **Backend:** response still contains viewers' mobile/email (B-08) |
| MF-10 | Companies to follow | User | REMOVED (Batch 3) | — | — | — | — |
| MF-11 | Share / copy public profile link | User | PARTIAL | — | derived | `profile_screen.dart` `_copyProfileLink`, `_buildPublicProfileAndLanguageCard` | **Flutter:** `/in/` vs `/profile/` URL (M-05) |
| MF-12 | Company page | — | "Coming Soon" (Batch 3), unreachable | none | — | `company/presentation/company_screen.dart` | **Backend:** public company profile endpoint |

## Networking & Chat

| ID | Feature | User | Flutter Status | API Status | Data | Main Files | Pending Work |
|---|---|---|---|---|---|---|---|
| F54 | Connections (invite, accept, ignore, remove, pending) | User | IMPLEMENTED | Active `/network/*` | REAL | `network/presentation/network_screen.dart`, `network/repositories/network_repository.dart` | Profile connections count shows 0 on error (H-02 remainder) |
| MF-13 | Peer-to-peer people search | User | IMPLEMENTED (protected route) | Active `GET /user/search`, `GET /community/users` | REAL | `peer_to_peer/presentation/peer_to_peer_screen.dart` | Move calls into a repository (L-04) |
| F55 | People You May Know | User | IMPLEMENTED **(26–30 Sep: tap → member profile, Connect, Message; 30 Sep LinkedIn-style 2-column card grid)** | Active `GET /community/users`, `/network/*`, `/network/status/:id` | REAL (not personalised — public member list) | `peer_to_peer/presentation/widgets/people_suggestion_grid.dart`, `network/presentation/member_profile_screen.dart`, `network/presentation/widgets/connect_button.dart` | Run format/analyze/test for the grid; dismiss (✕) not possible (no backend); **Backend:** endpoint returns full user records (B-04) |
| F56 | Conversation list & unread badges | User | PARTIAL | Active `GET /chats` | REAL; unread = HC 0 | `chat/presentation/chat_list_screen.dart`, `main_navigation_shell.dart` | **Backend:** unread counts not in response |
| F57/F92 | Real-time chat (REST send + WebSocket receive) | User | IMPLEMENTED **(29 Sep: reconnect fixed, avatars, full history)** | Active `/chats/*`, WS `/ws/chats?token=` | REAL | `chat/services/chat_websocket_service.dart`, `chat/providers/chat_provider.dart`, `chat/presentation/chat_detail_screen.dart` | Phone test of live chat; **Backend:** one socket per user, unregister race, oldest-first history (B-11) |
| F58/F59 | Chat attachments, block/report | — | PENDING | none | — | — | **Nowhere** |

## Gig Work, Skills, Experts, Services

| ID | Feature | User | Flutter Status | API Status | Data | Main Files | Pending Work |
|---|---|---|---|---|---|---|---|
| MF-14 | Instant Milega (gig worker page) | Gig | IMPLEMENTED **(26–30 Sep)**: location bar, availability toggle with InstantPass, Spot Gigs feed + claim, active gig + complete, earnings card; **map removed** | Active `/instant-work/candidate/status`, `/availability`, `/location`, `/candidate/feed`, `/claim`, `/candidate/active-job`, `/jobs/:id/complete`, `/pass/pay-wallet` | REAL | `instant_work/presentation/instant_work_screen.dart`, `widgets/instant_availability_card.dart`, `widgets/spot_gigs_widgets.dart`, `widgets/instant_location_bar.dart`, `providers/instant_candidate_provider.dart`, `providers/spot_gigs_provider.dart`, `repositories/instant_candidate_repository.dart` | Phone test; InstantPass via Razorpay (`/pass/order`, `/pass/verify`) **built 30 Sep but switched off** (`InstantPassTerms.onlinePaymentLive = false`) until the backend double charge B-12 is fixed; benefits block (point 31) shown in the pass sheet; nearby professionals "coming soon" (no API); old Instant Work filter chips M-01; **Backend:** B-12 |
| F30/F31/F35/F36 | Free-Now toggle, location updates, gig quota (InstantPass) | Gig | IMPLEMENTED in MF-14 **(26–30 Sep)**; continuous GPS tracking / live dispatch map: not built | see MF-14 | REAL | see MF-14 | Background location not built (Nowhere) |
| F39 | Skills marketplace | Guest, User | IMPLEMENTED | Active `/skills`, `/skills/categories` | REAL | `skills_marketplace/…` | — |
| F41 | Skill certifications | — | PENDING | none | — | — | **Nowhere** |
| F42 | Become an expert → Pro Expert plans | User | IMPLEMENTED **(26–30 Sep: redesigned Pro Expert plans screen, drawer card)** | Active `POST /user/apply-expert`, `/subscriptions/expert/*` | REAL | `experts/presentation/apply_expert_screen.dart`, `experts/models/expert_plan.dart`, `experts/providers/expert_plan_provider.dart`, `widgets/expert_plan_widgets.dart`, `profile/presentation/widgets/profile_drawer.dart` | Razorpay TEST-mode run |
| F43 | Expert directory | Guest, User | IMPLEMENTED | Active `GET /mentorships` | REAL + FALLBACK labels/rating | `experts/presentation/experts_screen.dart`, `experts/models/expert_profile.dart` | Fallback values (M-02) |
| F44 | Book free session | User | IMPLEMENTED | Active `POST /mentorships/book` | REAL | `expert_detail_screen.dart` | — |
| F76 | Paid session (wallet or Razorpay) | User | IMPLEMENTED (not tested in Razorpay TEST mode) | Active book-wallet / create-order / verify-payment | REAL | `expert_detail_screen.dart`, `core/payments/razorpay_checkout.dart` | Test-mode verification |
| MF-15 | My Booked Sessions + upcoming call + rate a session | User | IMPLEMENTED **(26–30 Sep: redesigned page with filter chips, escrow card, status badges, payment labels; "Upcoming call" banner on Experts page)** | Active `GET /mentorships/bookings/my`, `POST /mentorships/bookings/:id/review` | REAL | `experts/presentation/my_sessions_screen.dart`, `experts/presentation/widgets/upcoming_session_banner.dart`, `experts_screen.dart` | Phone check; backend does not update the expert's overall rating |
| F75 | Pro Expert subscription (monthly / yearly) | User / Expert | IMPLEMENTED **(26–30 Sep)** | Active `/subscriptions/expert/plans`, `/my`, `/create-order`, `/verify`, `/wallet-checkout` | REAL | see F42 | Razorpay TEST-mode run |
| F45/F46 | Expert reviews, earnings dashboard | Expert | PENDING | partial backend (not verified) | — | — | Not verified |
| F47 | Services directory | Guest, User | UI ONLY ("coming soon" + static categories) | none | HC | `services/presentation/services_marketplace_screen.dart` | **Backend** (`/services` not built) |
| F48–F50 | Book services, quotes, tracking | — | PENDING | none | — | — | **Backend** first |

## Events, Feed, Notifications, Explore

| ID | Feature | User | Flutter Status | API Status | Data | Main Files | Pending Work |
|---|---|---|---|---|---|---|---|
| F61 | Events list | Guest, User | IMPLEMENTED | Active `GET /events` | REAL + FALLBACK labels | `events/presentation/events_screen.dart`, `events/providers/event_provider.dart` | — |
| F62 | Event registration | User | IMPLEMENTED | Active `POST /events/:id/register` | REAL | `event_detail_screen.dart` | — |
| F63 | Paid event tickets + QR ticket + My Tickets | User | IMPLEMENTED **(26–30 Sep)** | Active `POST /events/:id/create-order`, `/verify-payment`, `/wallet-checkout`, `GET /events/my/tickets` | REAL | `events/presentation/event_detail_screen.dart`, `widgets/ticket_checkout_sheets.dart`, `widgets/event_ticket_view.dart`, `my_tickets_screen.dart` (route `/my-tickets`, protected), `providers/event_ticket_provider.dart` | Razorpay TEST-mode run; `GET /events/:id/ticket` not used |
| F64 | Attendee list | User | PENDING | Available `GET /events/:id/attendees` (public, backend `119c629`), not integrated | — | — | **Flutter** (verify response fields first) |
| F51–F53 | Feed / resources | Guest, User | UI ONLY ("coming soon") | none (`/posts`, `/feed` absent) | HC | `feed/presentation/feed_screen.dart` | **Backend** |
| MF-16 | In-app notifications | User | BACKEND DEPENDENCY | 404 `GET /notifications` (backend only sends e-mails via Brevo, F66) | — | `notifications/…` | **Backend** |
| F65 | Push notifications (FCM) | User | PENDING | none; no Firebase in app | — | — | **Backend + Flutter** |
| MF-17 | Explore hub | Guest, User | IMPLEMENTED | — | HC navigation | `explore/presentation/explore_screen.dart` | — |
| F67 | AI assistant | — | PENDING | none | — | — | **Nowhere** |

## Wallet & Payments

| ID | Feature | User | Flutter Status | API Status | Data | Main Files | Pending Work |
|---|---|---|---|---|---|---|---|
| F68 | Balances (main/earnings/locked/bonus) | User | IMPLEMENTED | Active `GET /wallet/balance` | REAL + CACHED | `wallet/presentation/wallet_screen.dart`, `wallet/providers/wallet_provider.dart` | — |
| F72 | Transaction history | User | IMPLEMENTED **(26–30 Sep: website-style tile — category badge, Main/Locked balance, balance after, reference, purpose)** | Active `GET /wallet/transactions` (+ `category` filter) | REAL + CACHED | `wallet/presentation/widgets/wallet_transaction_tile.dart`, `wallet_transactions_screen.dart`, `wallet/models/wallet_transaction.dart` | — |
| F70 | Add money (Razorpay) | User | IMPLEMENTED (not tested in TEST mode) | Active create-order / verify | REAL | `wallet_add_money_screen.dart`, `razorpay_checkout.dart` | Test-mode run; **Backend:** B-02 |
| F71 | Withdraw earnings | User, Expert | IMPLEMENTED (Batch 2) — no real payout tested | Active `POST /wallet/withdraw` | REAL | `wallet_withdraw_screen.dart`, `wallet/models/withdrawal.dart`, `wallet_repository.dart` | **Backend:** no bank verification / RazorpayX payouts (withdrawals are manual requests), no idempotency key (B-06). Offered: rename "Instant UPI" → "UPI" (not confirmed) |
| MF-18 | Wallet transfer (P2P) | User | BACKEND DEPENDENCY | 404 → coming soon | — | `wallet_transfer_screen.dart` | **Backend** |
| F74/F36 | ₹99 access pass (Home banner) / InstantPass | User, Gig | Home ₹99 banner: UI ONLY ("coming soon", nothing charged). InstantPass: IMPLEMENTED on Instant Milega via wallet **(26–30 Sep)** | `POST /instant-work/pass/pay-wallet` | HC banner / REAL pass | `home/presentation/home_screen.dart`, `instant_work/…` | Decide whether the Home ₹99 banner means InstantPass; **Backend:** B-12 |
| F73 | Refunds & disputes | User | IMPLEMENTED **(26–30 Sep)**: "Dispute / Refund" on debit rows, reasons with hints, 10–1000 characters, request status shown | Active `POST /wallet/disputes`, `GET /wallet/my/disputes` | REAL | `wallet/presentation/refund_request_sheet.dart`, `wallet/models/wallet_dispute.dart`, `wallet/providers/wallet_dispute_provider.dart` | Phone test (no real refund made) |
| F69/F94/F95 | KYC, referrals, offers | — | PENDING | none | — | — | **Nowhere** |

## Platform

| ID | Feature | Flutter Status | Data | Main Files | Pending Work |
|---|---|---|---|---|---|
| MF-19 | Offline banner + read-only caches + auto-refresh | IMPLEMENTED | LOCAL / CACHED | `core/network/*`, `local_storage.dart` | Override bug M-07 |
| MF-21 | Voice search (speech to text) | IMPLEMENTED **(26 Sep)** | — | `shared/widgets/voice_search_button.dart` (Home search) | Phone test (mic permission) |
| MF-22 | Brand fonts & typography (Inter, Poppins, Noto Sans Devanagari) | IMPLEMENTED **(26 Sep)** | — | `app/theme/app_text_styles.dart`, `assets/fonts/` | — |
| MF-20 | Shimmer skeletons | IMPLEMENTED | — | `shared/widgets/shimmer_loading.dart` | — |
| F97 | Android app | PARTIAL | — | `android/app/build.gradle.kts` | **Flutter:** release signing (uses debug key) |
| F98 | iOS app | PARTIAL / NOT VERIFIED | — | `ios/` | Signing team, device test |
| F37/F38 | In-app audio/video calls | PENDING | — | — | **Nowhere** |

---

### Summary

**Done (implemented end-to-end, some with notes):** auth incl. new OTP users and mid-session 401, jobs (hero card, filter reset), apply, saved jobs, applications, interviews, profile (edit/delete entries, skills, projects, analytics, profile viewers), network + People You May Know (card grid), peer-to-peer search, real-time chat (reconnect fix, avatars), skills, experts + Pro Expert plans + bookings + My Booked Sessions + upcoming-call banner, events + paid tickets + My Tickets, Instant Milega (availability, InstantPass via wallet, Spot Gigs, active gig), wallet balance / history (new tile) / top-up / withdraw / disputes & refunds, settings, voice search, offline, shimmer.

**Done, waiting for format/analyze/test or phone check:** People You May Know grid (30 Sep), live chat on a real phone, Open To Work / Providing Services (7d), Razorpay TEST-mode runs (top-up, sessions, Pro Expert, event tickets).

**Pending — Flutter work:** event attendee list (F64), InstantPass via Razorpay, Home ₹99 banner decision, Instant Work filter chips (M-01), fallback labels/cities (M-02, M-03), jobs cache per filter (M-09), secure token storage (M-10), profile URL `/in/` vs `/profile/` (M-05), release signing, iOS signing.

**Pending — Backend first:** notifications API, wallet transfer, feed/posts, services marketplace, resume field, push/FCM, unread chat counts, bank verification / RazorpayX payouts, nearby professionals API, bookmarks route fix (B-01), plus the backend bugs B-02…B-13 in [KNOWN_ISSUES.md](KNOWN_ISSUES.md#apibackend-issues).

**Not started anywhere:** KYC, referrals, offers, AI assistant, audio/video calls, skill certifications, chat attachments / block / report.
