# KaamMilega AI Quick Start

> **Last updated: 30 September 2026** · app branch `feat/map-location-integration` @ `0fa522f` + uncommitted 29–30 Sep work · backend monorepo `main` @ `5e57311` (read-only). Source code wins over docs.
> Last test run (29 Sep): `flutter analyze` no issues, `flutter test` +309 −1 (test-setup fix applied, re-run pending). Phone testing of the 26–30 Sep work is **pending** — [KNOWN_ISSUES.md § Verification log](KNOWN_ISSUES.md#verification-log).

## Status at a glance (30 Sep 2026)
- **Done:** auth + guest mode; jobs (search, voice search, filters, hero card, apply, saved); applications; interviews; profile (all sections, analytics, profile viewers); network + People You May Know card grid + member profiles; real-time chat (reconnect fixed 29 Sep, avatars); experts (booking, paid sessions, Pro Expert plans, My Booked Sessions, upcoming-call banner, ratings); events (register, paid tickets, My Tickets); Instant Milega (availability, InstantPass via wallet, Spot Gigs, active gig); wallet (balances, history, add money, withdraw request, refunds & disputes); settings; offline handling.
- **Waiting for checks:** run `dart format . && flutter analyze && flutter test` for the 30 Sep People You May Know grid; phone-test live chat; Razorpay TEST-mode runs (top-up, sessions, Pro Expert, event tickets).
- **Pending (app work):** event attendee list (backend ready), InstantPass by Razorpay, Home ₹99 banner decision, old Instant Work filter chips (M-01), fallback labels/cities (M-02/M-03), profile link `/in/` vs `/profile/` (M-05), jobs cache per filter (M-09), secure token storage (M-10), Android release signing, iOS signing.
- **Pending (backend first):** in-app notifications, wallet transfer, feed, services marketplace, resume field, push (FCM), chat unread counts, bank verification / automatic payouts, nearby professionals API, plus backend bugs B-01…B-16.
- **Open decisions:** rename "Instant UPI" → "UPI" on withdraw screen (offered, not confirmed).
- Details: [FEATURE_STATUS.md](FEATURE_STATUS.md) (per feature) · [KNOWN_ISSUES.md](KNOWN_ISSUES.md) (bugs + 26–30 Sep work log) · [flutter_app_feature_tracker.md](flutter_app_feature_tracker.md) (sheet view).

## What is this project?
KaamMilega is an Indian jobs and gig-work platform. This repo is its Flutter mobile app for candidates, guests and gig workers: jobs, applications, profile, networking, chat, experts/mentorship, events, skills and a Razorpay-backed wallet. All data comes from the separate Go backend `km-backend` (`https://api.kaammilega.com/api`), which is never edited from here.

## Primary users
- User / candidate (signed in with phone OTP or email+password)
- Guest ("Explore Jobs as Guest": browse only, in-memory, no token)
- Gig worker (same account as user; instant-work features mostly pending on backend)

## Architecture
```
UI (features/*/presentation)
↓
Riverpod Notifier / AsyncNotifier / FutureProvider (features/*/providers)
↓
Repository (features/*/repositories)
↓
ApiClient → Dio (core/network/api_client.dart)
↓
Go backend km-backend
```

## Important directories
- `lib/app/` — app, router, auth guard, theme
- `lib/core/` — `constants/api_constants.dart`, `network/`, `storage/`, `payments/`
- `lib/features/<feature>/` — models · repositories · providers · presentation
- `lib/shared/widgets/` — reusable UI
- `test/` — 21 test files, 184 tests

## Important files
| File | Why |
|---|---|
| `lib/app/router.dart` | all routes, splash timing |
| `lib/app/auth_guard.dart` | redirects, protected routes, guest rules |
| `lib/core/constants/api_constants.dart` | every endpoint path + base URL |
| `lib/core/network/api_client.dart` | auth header, 401 handling, error mapping |
| `lib/core/network/response_list.dart`, `provider_retry.dart` | list parsing (`null` = empty), app-wide retry policy |
| `lib/core/storage/local_storage.dart` | token, caches, device-only prefs |
| `lib/features/auth/providers/auth_provider.dart` | session + all profile mutations |
| `lib/features/auth/repositories/auth_repository.dart` | auth + profile endpoints |
| `lib/features/auth/models/user_profile.dart` | user model |
| `lib/features/jobs/providers/jobs_provider.dart` | jobs, filters, bookmarks |
| `lib/features/navigation/presentation/main_navigation_shell.dart` | bottom tabs |
| `lib/features/profile/presentation/profile_screen.dart` | profile UI (~7.3k lines) |
| `lib/features/chat/services/chat_websocket_service.dart` | realtime chat |
| `lib/features/wallet/providers/wallet_provider.dart` + `lib/core/payments/razorpay_checkout.dart` | wallet & payments |

## Authentication
Phone OTP (`/auth/otp/send` → `/auth/otp/verify`) or email+password. JWT saved in SharedPreferences (`km_auth_token`) and sent as `Bearer` by `ApiClient`. On 401 the session is cleared and auth state resets immediately, redirecting to `/login`. Startup: Splash → `checkAuthStatus` (`GET /user/profile`) → Home or Login. New OTP users complete their profile on `/complete-profile` (`POST /user/register`); Back / "Use a different account" log out safely. Logout resets all user-scoped data (`sessionUserIdProvider`).

## Guest mode
`AuthNotifier.enterGuestMode()` sets `isGuest` in memory (lost on restart). Guests can browse jobs, job detail, events, experts, skills, explore; protected routes (`/my-applications`, `/applications`, `/interviews`, `/my-sessions`, `/network`, `/apply-expert`, `/settings`, `/wallet`, `/peer-to-peer`, `/chats/:id`) redirect to Login and return afterwards. Actions (apply, save to server, register for events, edit profile) show a login prompt. The Chats tab shows a login prompt; guests make no authenticated API calls.

## Navigation
GoRouter with one redirect (`AuthGuard.redirect`). Tabs `/home`, `/jobs`, `/chats`, `/profile` share `MainNavigationShell` (IndexedStack; centre "+" = quick actions). Other screens are pushed routes. Full table: architecture.md §8.

## API
All paths in `api_constants.dart`, called through `ApiClient` from repositories. Errors become `AppException` subclasses (401/403 auth, 404 not found → "coming soon", 5xx server, others validation). Chat realtime uses `wss://…/api/ws/chats?token=…` with `NEW_MESSAGE` events — one socket per account, 20 s ping, endless backoff reconnect (architecture.md §12).

## Major features
| Feature | Status |
|---|---|
| Login (OTP, email), reset password, settings, session expiry | Implemented |
| New-user registration after OTP (`/complete-profile`) | Implemented |
| Jobs list/filter/detail/apply, blue hero card, voice search, filter reset from Home | Implemented |
| Home: horizontal quick actions + Popular Categories, featured companies | Implemented (₹99 banner still coming soon) |
| Saved jobs (loaded by ID) | Implemented |
| Applications, interviews | Implemented |
| Profile (intro, photos, education/experience/skills/projects, analytics) | Implemented |
| Profile viewers `/profile-viewers` | Implemented (backend also sends private fields — B-08) |
| Open To Work / Providing Services sheets | Implemented, **awaiting verification** |
| Network, member profile `/members/:id`, People You May Know grid | Implemented (grid 30 Sep, tests not run yet) |
| Chat (REST + WebSocket), avatars | Implemented (reconnect fix 29 Sep) |
| Experts, free & paid bookings, Pro Expert plans | Implemented |
| My Booked Sessions `/my-sessions` + upcoming-call banner + rating | Implemented |
| Events + registration + paid tickets + My Tickets | Implemented (attendee list pending) |
| Instant Milega: availability, InstantPass (wallet), Spot Gigs, active gig | Implemented (map removed; nearby professionals coming soon) |
| Skills marketplace | Implemented |
| Wallet balance / history / add money / withdraw / refunds & disputes | Implemented (no real payout or refund made in testing) |
| Wallet transfer, notifications, feed, services, company pages | Coming soon (backend missing) |
Full matrix: [FEATURE_STATUS.md](FEATURE_STATUS.md).

## Real vs hardcoded data
- **Real backend:** jobs, applications, interviews, profile, analytics, viewers, network, community members, chat, events + tickets, experts + subscriptions, Instant Milega, skills, wallet + disputes, top companies.
- **Local device:** guest bookmarks, resume URL, old phone-only Open To text (read only), offline caches (jobs, applications — offline only, wallet, user). Gig availability is now real (`/instant-work/availability`).
- **Hard-coded content:** home banners/categories, ₹99 benefits, explore modules, services categories, "coming soon" screens.
- **Mock:** none known (removed in Batch 3; `CompanyScreen` now "Coming Soon").
- **Website-confirmed constants:** Open To job types (`Full-time, Part-time, Contract, Freelance, Hourly`), visibility (`all`/`recruiters`), currency `INR`.
- **Fallback:** hard-coded 10 cities on `/cities` failure; default expert rating 5.0 / labels; event/interview/application placeholder labels.

## Known important issues
See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) — open (Flutter): H-02 remainder, M-01…M-03, M-05, M-07, M-09…M-11, L-01…L-07. Backend: B-01…B-16 — most important: B-11 chat hub (one socket per user), B-12 InstantPass / spot-gig money bugs, B-14 secrets committed in `docker-compose.yml`, B-08/B-04 private fields in public lists.

## Pending work
Summary above ("Status at a glance"); full list in [FEATURE_STATUS.md](FEATURE_STATUS.md) § Summary ("Pending Work" column separates Flutter / Backend / Nowhere).

## API reference
See [API_CONTRACT.md](API_CONTRACT.md) (verified requests/responses + mismatch table).

## Architecture reference
See [architecture.md](architecture.md) (§21 "Where do I change this?").

## Rules for AI agents
- Inspect before changing.
- Do not guess.
- Do not invent APIs.
- Do not create fake production data.
- Do not modify backend unless explicitly requested (the backend is developed by another developer; read the latest `main` only).
- The app is for candidates, guests and gig workers — not recruiters.
- Reuse existing architecture.
- Make minimal scoped changes.
- Test before finishing.
Full rules: [CLAUDE.md](CLAUDE.md).
