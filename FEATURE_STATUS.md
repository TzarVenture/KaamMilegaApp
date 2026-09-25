# KaamMilega Flutter — Feature Status

> **Last Audited:** 25 September 2026 · app `feat/ui-ux-polish` @ `eaf5dc8` + uncommitted changes · backend `km-backend` `main` @ `b5a2956`.
> Feature IDs reuse `flutter_app_feature_tracker.md` where one exists; `MF-xx` IDs are mobile features that tracker does not have (not to be confused with KNOWN_ISSUES `M-xx`).
> **Updated:** 25 September 2026 after fix Batches 1–7 (details in [KNOWN_ISSUES.md § Fix batches](KNOWN_ISSUES.md#fix-batches-25-sep-2026)). Statuses below reflect code + tests (format/analyze clean, 172 tests pass, 25 Sep 16:04); **phone testing of the fixes is still pending**.
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
| F07 | Session restore / 401 handling | User | PARTIAL | Active | REAL + CACHED user | `api_client.dart`, `auth_provider.dart` `checkAuthStatus`, `auth_guard.dart` | **Flutter:** mid-session 401 does not update state — H-05 |
| MF-02 | Logout | User | IMPLEMENTED (Batch 4) | local only (no backend logout route) | LOCAL | `auth_provider.dart` `logout`, `sessionUserIdProvider` | — (H-03 fixed); two logout paths navigate differently (L-05) |
| F99 | Guest mode & route guard | Guest | IMPLEMENTED (Batch 4) | — | — | `auth_guard.dart`, `router.dart`, `shared/widgets/login_required_view.dart` | — (H-04 fixed) |
| F93 | Settings (notifications, visibility, language, password) | User | IMPLEMENTED | Active (`PUT /user/settings`, `PUT /user/password`) | REAL | `profile/presentation/settings_screen.dart` | — |

## Jobs & Applications

| ID | Feature | User | Flutter Status | API Status | Data | Main Files | Pending Work |
|---|---|---|---|---|---|---|---|
| F21 | Job list, search, pagination | Guest, User | IMPLEMENTED | Active `GET /jobs` | REAL + CACHED | `jobs/presentation/jobs_screen.dart`, `jobs/providers/jobs_provider.dart` | Cache not per filter — M-09 |
| F22 | Filters (city, type, salary, experience, gender, education) | Guest, User | IMPLEMENTED | Active | REAL; cities FALLBACK on error | `widgets/filter_modal.dart`, `models/job_filter.dart`, `cities/…` | Fallback cities — M-03 |
| F23 | Job detail | Guest, User | IMPLEMENTED | Active `GET /jobs/:id`, `/applications/check/:jobId` | REAL | `job_detail_screen.dart` | `hasApplied` errors → false (H-02) |
| F23 | Apply (cover letter + device resume URL) | User | IMPLEMENTED | Active `POST /applications` | REAL | `applications/presentation/apply_modal.dart` | — |
| F24 | Save / bookmark jobs | Guest (device), User (server) | IMPLEMENTED (Batch 6) | Active `POST /user/bookmark/:jobId`, `GET /jobs/:id` per saved ID | REAL / LOCAL | `jobs_provider.dart` (`savedJobsProvider`, `savedJobDetailProvider`), `saved_jobs_screen.dart` | Chat button route `/chat` missing (L-07); **Backend:** `GET /user/bookmarks` 500 — B-01 |
| F25 | My applications + detail | User | IMPLEMENTED (Batches 3, 5) | Active `GET /applications/my` | REAL + CACHED (offline only) | `my_applications_screen.dart`, `application_detail_screen.dart` | — |
| F29 | Interviews list | User | IMPLEMENTED | Active `GET /interviews/my` | REAL | `interviews/presentation/interviews_screen.dart` | — (error state added, Batch 5) |
| MF-03 | Call recruiter | User | UI ONLY ("coming soon") | none | — | `jobs_screen.dart`, `job_detail_screen.dart`, `application_detail_screen.dart` | **Backend:** recruiter phone not shared |
| MF-04 | Home feed (banners, categories, recommended, top picks) | Guest, User | PARTIAL | Active `GET /jobs` | REAL jobs + HC sections | `home/presentation/home_screen.dart` | "Recommended" is not personalised (L-02) — Nowhere |
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
| MF-07 | Gig availability toggle (`is_available_for_gigs`) | Gig | PARTIAL | none | LOCAL | `auth_provider.dart` `deviceOnlyProfileKeys` | **Backend** (F30 "Free Now") |
| MF-08 | Profile analytics (views, impressions, appearances) | User | IMPLEMENTED | Active via `/user/profile` | REAL | `_buildAnalyticsCard` | — |
| MF-09 | Profile viewers / people suggestions | User | **BLOCKED** (7e) — "coming soon" | `GET /user/viewers` returns private fields — not used | — | `_buildPeopleWhoViewedCard` | **Backend:** public-safe viewer fields (B-08); suggestions — **Nowhere** (F55) |
| MF-10 | Companies to follow | User | REMOVED (Batch 3) | — | — | — | — |
| MF-11 | Share / copy public profile link | User | PARTIAL | — | derived | `profile_screen.dart` `_copyProfileLink`, `_buildPublicProfileAndLanguageCard` | **Flutter:** `/in/` vs `/profile/` URL (M-05) |
| MF-12 | Company page | — | "Coming Soon" (Batch 3), unreachable | none | — | `company/presentation/company_screen.dart` | **Backend:** public company profile endpoint |

## Networking & Chat

| ID | Feature | User | Flutter Status | API Status | Data | Main Files | Pending Work |
|---|---|---|---|---|---|---|---|
| F54 | Connections (invite, accept, ignore, remove, pending) | User | IMPLEMENTED | Active `/network/*` | REAL | `network/presentation/network_screen.dart`, `network/repositories/network_repository.dart` | Profile connections count shows 0 on error (H-02 remainder) |
| MF-13 | Peer-to-peer people search | User | IMPLEMENTED (protected route, Batch 4) | Active `GET /user/search` | REAL | `peer_to_peer/presentation/peer_to_peer_screen.dart` | Move call into a repository (L-04) |
| F55 | People you may know | — | PENDING | none | — | — | **Nowhere** |
| F56 | Conversation list & unread badges | User | PARTIAL | Active `GET /chats` | REAL; unread = HC 0 | `chat/presentation/chat_list_screen.dart`, `main_navigation_shell.dart` | **Backend:** unread counts not in response |
| F57/F92 | Real-time chat (REST send + WebSocket receive) | User | IMPLEMENTED | Active `/chats/*`, WS | REAL | `chat/services/chat_websocket_service.dart`, `chat/providers/chat_provider.dart`, `chat_detail_screen.dart` | Reconnect robustness (M-08) |
| F58/F59 | Chat attachments, block/report | — | PENDING | none | — | — | **Nowhere** |

## Gig Work, Skills, Experts, Services

| ID | Feature | User | Flutter Status | API Status | Data | Main Files | Pending Work |
|---|---|---|---|---|---|---|---|
| MF-14 | Instant Work list | Guest, Gig | PARTIAL | Active `GET /jobs` | REAL; filter chips do nothing | `instant_work/…` | **Flutter:** filters + verify job types (M-01) |
| F30/F31/F35/F36 | Free-Now toggle, GPS tracking, dispatch, gig quota | Gig | PENDING | none | — | centre "+" sheet says coming soon (`main_navigation_shell.dart`) | **Backend** first |
| F39 | Skills marketplace | Guest, User | IMPLEMENTED | Active `/skills`, `/skills/categories` | REAL | `skills_marketplace/…` | — |
| F41 | Skill certifications | — | PENDING | none | — | — | **Nowhere** |
| F42 | Become an expert | User | IMPLEMENTED | Active `POST /user/apply-expert` | REAL | `experts/presentation/apply_expert_screen.dart` | — |
| F43 | Expert directory | Guest, User | IMPLEMENTED | Active `GET /mentorships` | REAL + FALLBACK labels/rating | `experts/presentation/experts_screen.dart`, `experts/models/expert_profile.dart` | Fallback values (M-02) |
| F44 | Book free session | User | IMPLEMENTED | Active `POST /mentorships/book` | REAL | `expert_detail_screen.dart` | — |
| F76 | Paid session (wallet or Razorpay) | User | IMPLEMENTED (not tested in Razorpay TEST mode) | Active book-wallet / create-order / verify-payment | REAL | `expert_detail_screen.dart`, `core/payments/razorpay_checkout.dart` | Test-mode verification |
| MF-15 | My booked sessions | User | IMPLEMENTED (7c) | Active `GET /mentorships/bookings/my` | REAL | `experts/presentation/my_sessions_screen.dart`, route `/my-sessions` (protected, drawer "My Sessions") | — |
| F45/F46 | Expert reviews, earnings dashboard | Expert | PENDING | partial backend (not verified) | — | — | Not verified |
| F47 | Services directory | Guest, User | UI ONLY ("coming soon" + static categories) | none | HC | `services/presentation/services_marketplace_screen.dart` | **Backend** (`/services` not built) |
| F48–F50 | Book services, quotes, tracking | — | PENDING | none | — | — | **Backend** first |

## Events, Feed, Notifications, Explore

| ID | Feature | User | Flutter Status | API Status | Data | Main Files | Pending Work |
|---|---|---|---|---|---|---|---|
| F61 | Events list | Guest, User | IMPLEMENTED | Active `GET /events` | REAL + FALLBACK labels | `events/presentation/events_screen.dart`, `events/providers/event_provider.dart` | — |
| F62 | Event registration | User | IMPLEMENTED | Active `POST /events/:id/register` | REAL | `event_detail_screen.dart` | — |
| F63 | Paid event tickets | — | PENDING | none | — | — | **Backend** |
| F64 | Attendee list | — | PENDING | none | — | — | **Nowhere** |
| F51–F53 | Feed / resources | Guest, User | UI ONLY ("coming soon") | none (`/posts`, `/feed` absent) | HC | `feed/presentation/feed_screen.dart` | **Backend** |
| MF-16 | In-app notifications | User | BACKEND DEPENDENCY | 404 `GET /notifications` | — | `notifications/…` | **Backend** |
| F65 | Push notifications (FCM) | User | PENDING | none; no Firebase in app | — | — | **Backend + Flutter** |
| MF-17 | Explore hub | Guest, User | IMPLEMENTED | — | HC navigation | `explore/presentation/explore_screen.dart` | — |
| F67 | AI assistant | — | PENDING | none | — | — | **Nowhere** |

## Wallet & Payments

| ID | Feature | User | Flutter Status | API Status | Data | Main Files | Pending Work |
|---|---|---|---|---|---|---|---|
| F68 | Balances (main/earnings/locked/bonus) | User | IMPLEMENTED | Active `GET /wallet/balance` | REAL + CACHED | `wallet/presentation/wallet_screen.dart`, `wallet/providers/wallet_provider.dart` | — |
| F72 | Transaction history | User | IMPLEMENTED | Active `GET /wallet/transactions` | REAL + CACHED | `wallet_transactions_screen.dart` | — |
| F70 | Add money (Razorpay) | User | IMPLEMENTED (not tested in TEST mode) | Active create-order / verify | REAL | `wallet_add_money_screen.dart`, `razorpay_checkout.dart` | Test-mode run; **Backend:** B-02 |
| F71 | Withdraw earnings | User, Expert | IMPLEMENTED (Batch 2) — no real payout tested | Active `POST /wallet/withdraw` | REAL | `wallet_withdraw_screen.dart`, `wallet/models/withdrawal.dart`, `wallet_repository.dart` | **Backend:** no idempotency key (B-06) |
| MF-18 | Wallet transfer (P2P) | User | BACKEND DEPENDENCY | 404 → coming soon | — | `wallet_transfer_screen.dart` | **Backend** |
| F74/F36 | ₹99 access pass | User | UI ONLY ("coming soon", nothing charged) | none | HC | `home/presentation/home_screen.dart` | **Backend** |
| F69/F73/F75/F94/F95 | KYC, refunds, subscriptions, referrals, offers | — | PENDING | none | — | — | **Nowhere** |

## Platform

| ID | Feature | Flutter Status | Data | Main Files | Pending Work |
|---|---|---|---|---|---|
| MF-19 | Offline banner + read-only caches + auto-refresh | IMPLEMENTED | LOCAL / CACHED | `core/network/*`, `local_storage.dart` | Override bug M-07 |
| MF-20 | Shimmer skeletons | IMPLEMENTED | — | `shared/widgets/shimmer_loading.dart` | — |
| F97 | Android app | PARTIAL | — | `android/app/build.gradle.kts` | **Flutter:** release signing (uses debug key) |
| F98 | iOS app | PARTIAL / NOT VERIFIED | — | `ios/` | Signing team, device test |
| F37/F38 | In-app audio/video calls | PENDING | — | — | **Nowhere** |

---

### Summary

- **Implemented end-to-end (some with notes):** auth incl. new OTP users, jobs, apply, saved jobs, applications, interviews, profile (education/experience edit-delete, skill remove, projects), network, chat, skills, experts & bookings + My Sessions, events, wallet balance/history/top-up/withdraw, settings, offline, shimmer.
- **Implemented, awaiting verification:** Open To Work / Providing Services (7d).
- **Blocked on backend:** profile viewers (B-08); multi-word skill removal (B-07).
- **Mock / fake content:** removed (H-01 fixed). Fallback labels remain (M-02, M-03).
- **Waiting on backend:** notifications, transfer, feed, services, ₹99 pass, gig dispatch, resume field, unread counts, bookmarks route fix.
- **Backend ready, Flutter not integrated:** event detail, settings `/settings/me`, username, expert availability, companies.
