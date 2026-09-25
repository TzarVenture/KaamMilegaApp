# KaamMilega AI Quick Start

> Last Audited: 25 September 2026 · branch `feat/ui-ux-polish` @ `eaf5dc8` · backend `km-backend` @ `b5a2956` (Batch 7 contracts re-checked @ `51c8e10`).
> **Updated 25 Sep 2026 after fix Batches 1–7** (uncommitted). Format/analyze/test pass (172 tests, 25 Sep 16:04); phone testing is **pending** — see [KNOWN_ISSUES.md § Verification log](KNOWN_ISSUES.md#verification-log). Source code wins over docs.

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
- `test/` — 21 test files, 172 tests

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
Phone OTP (`/auth/otp/send` → `/auth/otp/verify`) or email+password. JWT saved in SharedPreferences (`km_auth_token`) and sent as `Bearer` by `ApiClient`. On 401 the session is cleared; the next navigation goes to `/login`. Startup: Splash → `checkAuthStatus` (`GET /user/profile`) → Home or Login. New OTP users complete their profile on `/complete-profile` (`POST /user/register`); Back / "Use a different account" log out safely. Logout resets all user-scoped data (`sessionUserIdProvider`). Still open: a 401 mid-session does not redirect until the next navigation (H-05).

## Guest mode
`AuthNotifier.enterGuestMode()` sets `isGuest` in memory (lost on restart). Guests can browse jobs, job detail, events, experts, skills, explore; protected routes (`/my-applications`, `/applications`, `/interviews`, `/my-sessions`, `/network`, `/apply-expert`, `/settings`, `/wallet`, `/peer-to-peer`, `/chats/:id`) redirect to Login and return afterwards. Actions (apply, save to server, register for events, edit profile) show a login prompt. The Chats tab shows a login prompt; guests make no authenticated API calls.

## Navigation
GoRouter with one redirect (`AuthGuard.redirect`). Tabs `/home`, `/jobs`, `/chats`, `/profile` share `MainNavigationShell` (IndexedStack; centre "+" = quick actions). Other screens are pushed routes. Full table: architecture.md §8.

## API
All paths in `api_constants.dart`, called through `ApiClient` from repositories. Errors become `AppException` subclasses (401/403 auth, 404 not found → "coming soon", 5xx server, others validation). Chat realtime uses `wss://…/api/ws/chats?token=…` with `NEW_MESSAGE` events.

## Major features
| Feature | Status |
|---|---|
| Login (OTP, email), reset password, settings | Implemented |
| New-user registration after OTP (`/complete-profile`) | Implemented (Batch 1) |
| Jobs list/filter/detail/apply | Implemented |
| Saved jobs (loaded by ID) | Implemented (Batch 6) |
| Applications, interviews | Implemented |
| Profile (intro, photos, projects, analytics) | Implemented |
| Education / experience edit & delete (7a) | Implemented |
| Remove skill (7b) | Implemented; names with spaces or "/" fail on backend (B-07) |
| My Sessions `/my-sessions` (7c) | Implemented |
| Open To Work / Providing Services sheets (7d) | Implemented, **awaiting verification** |
| Profile viewers (7e) | **Blocked** — backend returns private fields (B-08) |
| Network, chat (WebSocket) | Implemented |
| Experts, free & paid bookings | Implemented |
| Events + registration | Implemented |
| Skills marketplace | Implemented |
| Wallet balance / history / add money / withdraw | Implemented (withdraw: Batch 2, no real payout tested) |
| Wallet transfer, notifications, feed, services, ₹99 pass, gig dispatch, company pages | Coming soon (backend missing) |
Full matrix: [FEATURE_STATUS.md](FEATURE_STATUS.md).

## Real vs hardcoded data
- **Real backend:** jobs, applications, interviews, profile, network, chat, events, experts, skills, wallet.
- **Local device:** guest bookmarks, resume URL, gig availability, old phone-only Open To text (read only), offline caches (jobs, applications — offline only, wallet, user).
- **Hard-coded content:** home banners/categories, ₹99 benefits, explore modules, services categories, "coming soon" screens.
- **Mock:** none known (removed in Batch 3; `CompanyScreen` now "Coming Soon").
- **Website-confirmed constants:** Open To job types (`Full-time, Part-time, Contract, Freelance, Hourly`), visibility (`all`/`recruiters`), currency `INR`.
- **Fallback:** hard-coded 10 cities on `/cities` failure; default expert rating 5.0 / labels; event/interview/application placeholder labels.

## Known important issues
See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) — open: H-05, H-02 remainder, M-01…M-03, M-05, M-07, M-09…M-11, L-01…L-07; backend: B-01…B-10 (incl. B-07 skill-name decoding, B-08 viewers privacy).

## Pending work
See [FEATURE_STATUS.md](FEATURE_STATUS.md) ("Pending Work" column separates Flutter / Backend / Nowhere).

## API reference
See [API_CONTRACT.md](API_CONTRACT.md) (verified requests/responses + mismatch table).

## Architecture reference
See [architecture.md](architecture.md) (§21 "Where do I change this?").

## Rules for AI agents
- Inspect before changing.
- Do not guess.
- Do not invent APIs.
- Do not create fake production data.
- Do not modify backend unless explicitly requested.
- Reuse existing architecture.
- Make minimal scoped changes.
- Test before finishing.
Full rules: [CLAUDE.md](CLAUDE.md).
