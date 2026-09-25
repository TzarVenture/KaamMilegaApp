# KaamMilega Flutter — Known Issues

> **Last Audited:** 25 September 2026 · app branch `feat/ui-ux-polish` @ `eaf5dc8` + uncommitted `user_profile.dart` / `profile_screen.dart` · backend `km-backend` `main` @ `b5a2956` (read-only).
> **Updated:** 25 September 2026 after fix Batches 1–7 (Flutter only; backend read-only, re-checked on `KaamMilega` monorepo `main` @ `51c8e10`). Each issue below carries an **Update** line with its current state. Fix summary: [§ Fix batches](#fix-batches-25-sep-2026).
> Status values: **Open** (confirmed in code) · **Fixed (Batch N)** · **Partly fixed** · **Backend** (needs backend developer) · **Blocked** · **Needs verification** (evidence strong, runtime not tested).
> Architecture context: [architecture.md](architecture.md) · API details: [API_CONTRACT.md](API_CONTRACT.md) · Feature impact: [FEATURE_STATUS.md](FEATURE_STATUS.md)

---

## Critical

### C-01 — New phone (OTP) users are sent to email sign-up, which creates a second account
- **Severity:** Critical · **Feature:** Auth / registration (F01, F02) · **Status:** Open
- **Files:** `lib/features/auth/presentation/otp_screen.dart` (`_verifyOtp`, `is_registered == false` → `context.go('/register')`), `lib/features/auth/presentation/register_screen.dart` (calls `registerWithPassword`), `lib/features/auth/providers/auth_provider.dart` (`registerCandidate` never called).
- **Evidence:**
  - `POST /auth/otp/verify` for a new number creates a user with `is_registered:false` and returns a token; the app saves the token and sets `isAuthenticated: true`.
  - `/register` (`RegisterScreen`) collects name/email/password and calls `POST /auth/register/password`. Backend `RegisterWithPassword` (`km-backend/internal/features/user/service.go`) is public, ignores the bearer token and **creates a new user** by email, returning a new token that replaces the phone session.
  - `AuthNotifier.registerCandidate` → `POST /user/register` (the endpoint that completes the OTP user's profile) has **no caller** (`rg registerCandidate` → only definitions).
  - An OTP user who leaves `/register` stays signed in with an unregistered account (guard checks only token + `isAuthenticated`).
- **Next investigation:** confirm intended onboarding with the product owner; decide whether the OTP path should use `POST /user/register` (fields: `roles, name, gender, education_level, work_experience, city, job_categories, experience_detail, email`) and whether `AuthGuard` should block unregistered users.
- **Update:** **Fixed (Batch 1).** New OTP users go to `/complete-profile` (`auth/presentation/complete_profile_screen.dart`) → `POST /user/register`. `AuthState.needsProfileCompletion` keeps them there (router guard); Back and "Use a different account" both confirm, log out and return to Login. Registered users are unchanged. Tests: `complete_profile_test.dart`, `auth_flow_test.dart`.

### C-02 — Wallet withdrawal request does not match the now-live backend endpoint
- **Severity:** Critical (money flow) · **Feature:** Wallet withdraw (F71) · **Status:** Open
- **Files:** `lib/features/wallet/repositories/wallet_repository.dart` (`initiateWithdrawal`), `lib/features/wallet/presentation/wallet_withdraw_screen.dart` (`_destinationType = 'UPI' | 'BANK'`).
- **Evidence:** App sends `{amount, destination_type: "UPI"|"BANK", destination_detail}`. Backend `POST /api/wallet/withdraw` now exists (`wallet/api.go:31`) and expects `WithdrawalRequest{amount, payout_method: "bank"|"upi", account_holder, account_number, ifsc_code, bank_name, upi_id, phone_number}`; it rejects anything else with **400 "payout method must be 'bank' or 'upi'"**. Min ₹50, max ₹5,00,000; withdraws from earnings. The app's "coming soon" branch only runs on 404, which no longer happens, so users now get a red error instead.
- **Next investigation:** align the request body and screen fields with `WithdrawalRequest`; check the response (`{transaction, wallet, message}`); stop and confirm payout rules before shipping.
- **Update:** **Fixed (Batch 2).** App sends `WithdrawalRequest` (`wallet/models/withdrawal.dart`): `payout_method` `upi` (`upi_id`) or `bank` (`account_holder`, `account_number`, `ifsc_code`); `bank_name` and `phone_number` optional. Min ₹50 checked before sending; confirmation sheet; 404 → coming soon; timeout/5xx → "outcome unknown, check transactions before retrying" (`WalletApiException.isOutcomeUnknown`). No real withdrawal was made in testing. Backend has no idempotency key — B-06. Tests: `wallet_withdrawal_test.dart`.

---

## High

### H-01 — Hard-coded mock data shown as if real
- **Severity:** High · **Status:** Open
- **Evidence:**
  - `lib/features/company/presentation/company_screen.dart`: entire page is invented ("Reliance Logistics & Retail", "10,000+ employees", two fake job openings, local-only Follow with "Now following Reliance Logistics!"). `companyId` is ignored. No widget navigates to `/company/:id` (unreachable, but routed).
  - `lib/features/profile/presentation/profile_screen.dart` `_buildCompaniesToFollowCard` (~line 6177): fixed list "Technova", "Infosys Digital", "TCS Global"; Follow shows "You are now following …" with no API call (fake success).
  - `lib/features/applications/presentation/my_applications_screen.dart` (~339–407) and `application_detail_screen.dart` (~198–207): every application shows "4.2 | 4.4K+ Reviews" and "Recruiter last active 5w ago".
  - `profile_screen.dart` `_showOpenToModal` (~2861–2869): text fields are pre-filled with example values ("Computer Science roles, Software Engineering Internships", "Web Development, Technical Writing, and Go Microservices") that are saved if the user taps save.
- **Next investigation:** backend has `GET /api/companies/top` and `/api/companies` (public) — verify its shape before using; otherwise remove/replace with honest empty or coming-soon states.
- **Update:** **Fixed (Batch 3; Open To part replaced in 7d).** Application cards/detail show real `company • city` instead of the rating/"last active" text; "Companies to follow" card removed; `CompanyScreen` route kept but shows "Coming Soon"; the Open To sheet has no pre-filled examples (now the structured sheets, see M-06). Test: `no_invented_data_test.dart`.

### H-02 — API failures silently become empty lists / "not applied"
- **Severity:** High · **Status:** Open
- **Files & evidence** (`catch (_) { return []; }` or equivalent):
  - `applications/repositories/application_repository.dart` `getMyApplications` (falls back to cache, else `[]`), `hasApplied` (→ `false`, so the Apply button may show for an already-applied job).
  - `interviews/repositories/interview_repository.dart` `getMyInterviews`.
  - `network/repositories/network_repository.dart` `getPendingInvitations`, `getConnections`, `getConnectionStatus` (→ `''`).
  - `chat/repositories/chat_repository.dart` `getConversations`, `getMessages`.
  - `cities/repositories/city_repository.dart` `getCities` → hard-coded 10 cities with slug ids (`'mumbai'` …), see M-03.
- **Impact:** 401/404/500/offline all look like "no data"; violates the project rule "HTTP 404 must not be interpreted as no data".
- **Next investigation:** rethrow `AppException` and let providers show `NetworkStateView` error/coming-soon states.
- **Update:** **Partly fixed (Batch 5).** Applications, interviews, network (pending/connections/status) and chat repositories rethrow; list bodies go through `core/network/response_list.dart` (`readListResponse`: JSON array, `{data:[…]}`, and Go `null` = empty; anything else = error). Screens use `NetworkStateView.fromError` (Retry). Applications cache is shown **only when offline** (server errors are reported). Chat history has error + Retry. **Still open:** `hasApplied` error → `false`; `/cities` fallback (M-03); profile connections count shows 0 on error. Test: `error_states_test.dart`.

### H-03 — Logout / account switch leaves the previous user's data and socket alive
- **Severity:** High (privacy) · **Feature:** Auth, chat, applications, network · **Status:** Open
- **Evidence:** `AuthNotifier.logout()` only clears storage and resets `AuthState`. No `ref.invalidate` for `myApplicationsProvider`, `myInterviewsProvider`, `conversationsProvider`, `pendingInvitationsProvider`, `connectionsProvider`, `connectionStatusProvider`, `chatMessagesProvider`, `userLookupProvider` (all non-autoDispose, none watch `authProvider`). `chatWebSocketServiceProvider` is never disposed, so the socket opened with the old token stays connected and keeps delivering the old user's `NEW_MESSAGE` events. `LocalStorage.clearSession()` keeps `km_saved_job_ids` and `km_cache_jobs`. (`walletProvider` and `jobsProvider` bookmarks do handle it.)
- **Next investigation:** reproduce: log in as A → open chats/applications → log out → log in as B in the same app session.
- **Update:** **Fixed (Batch 4).** `sessionUserIdProvider` (auth_provider.dart); user-scoped providers (applications, interviews, network, conversations, chat messages, user lookup, chat WebSocket service) watch it and reset on logout/account switch; the socket is closed; `clearSession` removes `km_saved_job_ids` and saved IDs are cleared. Test: `session_cleanup_test.dart`.

### H-04 — Guest mode triggers authenticated API calls
- **Severity:** High · **Feature:** Guest mode (F99) · **Status:** Open
- **Evidence:**
  - `main_navigation_shell.dart` `build` always `ref.watch(conversationsProvider)` → `GET /chats` without a token for guests (401 swallowed → empty list). The Chats tab (`ChatListScreen`) has no guest gating.
  - `/peer-to-peer` is not in `AuthGuard._protectedRoots`; `PeerToPeerScreen.initState` calls `GET /user/search` (auth-only) → guest sees "Could not load users".
  - `IndexedStack` builds Profile and Chats for guests immediately.
- **Next investigation:** make those providers auth-aware or gate the screens with the existing `showAuthPromptDialog` / `AuthGuard`.
- **Update:** **Fixed (Batch 4).** Shell no longer watches `conversationsProvider`; Chats tab shows `LoginRequiredView` (`shared/widgets/login_required_view.dart`) for guests; `/peer-to-peer` is protected (Explore uses `AuthGuard.openProtected`); `/my-sessions` protected too (Batch 7).

### H-05 — Mid-session 401 does not update auth state
- **Severity:** High · **Feature:** Auth/session · **Status:** Open (by design comment, but user-visible)
- **Evidence:** `ApiClient` `onError` 401 → `LocalStorage.clearSession()` only. `AuthState.isAuthenticated` stays `true`, the router is not refreshed (its listenable watches `AuthState`), so the user stays on the current screen, UI still shows the old user, and every later call is unauthenticated until the next navigation redirects to `/login` (`auth_guard.dart` doc comment confirms).
- **Next investigation:** decide whether ApiClient should notify `authProvider` (without creating a second auth system).
- **Update:** **Still open** (not in Batches 1–7).

### H-06 — Saved Jobs screen shows only saved jobs that are on the current Jobs page
- **Severity:** High · **Feature:** Saved jobs (F24) · **Status:** Open
- **Evidence:** `lib/features/jobs/presentation/saved_jobs_screen.dart` lines ~33–37 filter `jobsState.jobs` (the currently loaded page, `limit: 10`, current filters) by `savedJobIds`. Saved jobs on other pages/filters are counted in `savedJobIds` but never displayed. Backend has `GET /user/bookmarks` (full jobs) but it returns 500 (route-order bug, see B-01).
- **Next investigation:** fetch saved jobs by id (`GET /jobs/:id`) or wait for the backend fix.
- **Update:** **Fixed (Batch 6).** Every saved ID is loaded with `GET /jobs/:id` (`savedJobDetailProvider`, reuses already-loaded jobs); a 404 shows an "unavailable" row with Remove; other errors show Retry. Tests: `saved_jobs_test.dart`. New related issue: L-07.

---

## Medium

### M-01 — Instant Work filters do nothing; job types not verified
- **Files:** `instant_work/providers/instant_work_provider.dart`, `instant_work/presentation/instant_work_screen.dart`.
- **Evidence:** `setFilter` stores `activeFilter` ('Today', 'Hourly', 'Urgent', 'Nearby') but `loadGigs` always sends the same query `job_types=Instant,Hourly,Gig,Part-time`. `Instant`, `Hourly`, `Gig` do not appear anywhere in km-backend or km-frontend (only `Full-time`, `Part-time`, `Internship`, `Freelance`, `Contract` found) → probably only Part-time jobs match. **Status:** Open / needs verification against production data.

### M-11 — Old phone-only Open To text still counts as "On"
- **Files:** `auth/models/user_profile.dart` (`isOpenToWork`, `isProvidingServices`, `*Summary`).
- **Evidence:** when the backend has no `open_to_work` / `providing_services` object, text saved on the phone by the old sheet still turns the profile badge "On" and is shown as the summary. It stops after the user's first save from the new sheets (the server object then wins). The new sheets show the old text in a note and never convert it. **Status:** Open (decide whether to ignore device text).

### M-12 — Automatic provider retry (app-wide policy)
- **File:** `core/network/provider_retry.dart`, `main.dart` (`ProviderScope(retry: appProviderRetry)`).
- **Evidence:** Riverpod 3 retried every failing provider up to 10 times (~40 s; `.future` pending, 404/401 repeated). The app now retries only `AppNetworkException`, `AppTimeoutException` and `AppServerException`, at most twice (200 ms, 400 ms); 401/403/404/validation errors show immediately. **Status:** Fixed (behaviour change — watch on device). Tests: `error_states_test.dart` ("Automatic retry policy").

### M-02 — Fallback labels and ratings in models look like real data
- **Evidence:** `experts/models/expert_profile.dart`: `rating` falls back to `5.0` when both `mentorship.rating` and `expert.rating` are absent; `expertName` → 'Verified Expert', `expertHeadline` → 'Senior Professional', `title` → '1-on-1 Mentorship Session', `duration` → 45. `events/models/event.dart`: organizer → 'KaamMilega Network', location → 'Online Webinar', title → 'Webinar & Career Event'. `interviews/models/interview.dart`: 'Interview Position', 'Recruiting Company'. `applications/models/application.dart`: 'Applied Position', 'Company', job type 'Full-time'. **Status:** Open.

### M-03 — City list falls back to a hard-coded list on any error
- **File:** `cities/repositories/city_repository.dart`. Returns 10 invented `City(id: 'mumbai', …)` entries on any failure, hiding errors and producing ids the backend does not have. Jobs filter sends the selected **name** as `city_ids`; backend `job/repository.go` treats values that are not ObjectIDs as city names, so names work (runtime not tested). **Status:** Open.

### M-04 — Offline applications cache loses job title and company
- **Files:** `applications/repositories/application_repository.dart` (cache writes flat `job_title`, `company_name`), `applications/models/application.dart` (`fromJson` reads nested `job.title`, `job.company`).
- **Evidence:** cached cards fall back to 'Applied Position' / 'Company'. **Status:** Open.
- **Update:** **Fixed (Batch 5)** — the cache stores the raw backend items, so title/company are kept.

### M-05 — Two different public-profile URLs
- **Evidence:** `ApiConstants.publicProfileUrl` → `https://kaammilega.com/profile/{id}` (used by Copy link / View public profile). `UserProfile.publicProfileUrl` / `fullPublicProfileUrl` and `profile_screen.dart` `_buildPublicProfileAndLanguageCard` → `https://www.kaammilega.com/in/{id}`. km-frontend (`src/app/(user)/profile`) has **no `/in/` route** → the profile-card link is likely a 404 page. **Status:** Open.

### M-06 — Backend features available but not integrated (app still says "not possible"/device-only)
- Verified in `km-backend` `b5a2956` routes: `PUT/DELETE /user/education/:id`, `PUT/DELETE /user/experience/:id`, `DELETE /user/skill/:skillName`, `PATCH /user/open-to-work`, `PATCH /user/providing-services`, `GET /user/viewers`, `PATCH /user/username`, `GET /mentorships/bookings/my`, `GET /events/:id`, `GET /companies/top`, `GET/PUT /settings/me` (not shadowed by `/user/:id`).
- **Impact:** app comments/UI say edit/delete is unsupported; Open To preferences are saved on device only (`AuthNotifier.deviceOnlyProfileKeys`) so recruiters never see them; users cannot see their booked sessions. **Status:** Open (Flutter work; contracts must be re-verified before use).
- **Update (Batch 7):**
  - **7a Fixed** — education/experience edit + delete (`PUT/DELETE /user/education/:id`, `/user/experience/:id`; experience edit re-sends its existing `skills`). Row ⋮ menu → edit sheet / confirm delete.
  - **7b Fixed in app** — remove skill (chip ✕ → `DELETE /user/skill/:skillName`, name URL-encoded like the website). Success only if the returned profile no longer has the skill. Multi-word names fail on the backend — **B-07**.
  - **7c Fixed** — My Sessions: `/my-sessions` (protected, drawer entry) → `GET /mentorships/bookings/my` (`experts/presentation/my_sessions_screen.dart`, `myBookingsProvider`).
  - **7d Implemented, awaiting verification** — structured Open To Work / Providing Services sheets (`profile/presentation/widgets/open_to_sheets.dart`) save with `PATCH /user/open-to-work` and `/user/providing-services`. Old phone-only text is shown, never split or sent automatically. See B-09, M-11.
  - **7e Blocked** — Profile viewers stay "coming soon" until `GET /user/viewers` returns public-safe fields — **B-08**.
  - Tests: `profile_entries_sessions_test.dart`, `open_to_preferences_test.dart`.

### M-07 — Connectivity override can hide real offline state
- **File:** `core/network/connectivity_service.dart`, `core/network/api_client.dart`.
- **Evidence:** every successful response calls `updateStatus(online)`, which sets `_isOverridden = true`; while overridden, `connectivity_plus` changes are ignored (`if (!_isOverridden)`). Only `probeInternet()`/`clearOverride()` reset it. After the first API response, turning on airplane mode is not detected until an API call fails. **Status:** Needs verification on device.

### M-08 — Chat robustness gaps
- `main_navigation_shell.dart`: unread chat count hard-coded `0`.
- `chat_provider.dart`: `chatMessagesProvider` family is not autoDispose (stream subscriptions and message lists kept per conversation); history load failure → empty conversation (no error state).
- `chat_websocket_service.dart`: reconnect gives up after 5 attempts (linear 2/4/6/8/10 s, comment says exponential); `_processedMessageIds` grows without limit. **Status:** Open.
- **Update:** `chatMessagesProvider` is now autoDispose and has an error state + Retry (Batch 5). Unread badge (backend has no counts) and WebSocket reconnect/ID growth are still open.

### M-09 — Jobs offline cache is not tied to the filter
- `jobs_provider.dart` `fetchJobs`: on any error it shows the last cached list (single key `km_cache_jobs`) even when the current search/filter/page differs, labelled only by timestamp; 404/500 are also replaced by cache. **Status:** Open.

### M-10 — Tokens stored unencrypted
- `core/storage/local_storage.dart`: JWT in SharedPreferences (`km_auth_token`); no secure storage package. JWT is also sent in the WebSocket query string (backend design). **Status:** Open (security review item).

---

## Low

- **L-01 — Marketing content for features that do not exist.** `home_screen.dart` ₹99 Access sheet/banners list "AI Profile Resume and Score Enhancement", "Unlimited Job Applications", "Earn more reward coins & cashback vouchers"; tapping says coming soon and nothing is charged. `explore_screen.dart` badges "Verified Mentors", "InstantMilega™". HARDCODED CONTENT. Status: Open.
- **L-02 — "Recommended for You" / "Top Picks" are not personalised.** `home_screen.dart` uses the first jobs of `jobsProvider` (latest jobs for the current filter). Status: Open.
- **L-03 — Dead / unused code.** `AuthNotifier.registerCandidate` + `AuthRepository.registerCandidate`; `LocalStorage.saveSelectedCity/getSelectedCity`; `ApiConstants.userBookmarks`, `userSettings` (GET), `posts`, `feed`, `adminCompanies`, duplicate `mentorship`; unreachable `CompanyScreen`. Status: Open.
- **L-04 — Architecture drift.** Direct repository/ApiClient calls from screens (`peer_to_peer_screen.dart`, `settings_screen.dart`, `job_detail_screen.dart`, `expert_detail_screen.dart`, `network_screen.dart`); `profile_screen.dart` is 7,289 lines; many inline `Color(0x…)`/`TextStyle` instead of `AppColors`/`AppTextStyles`; some literal paths bypass `ApiConstants`. Status: Open.
- **L-05 — Two logout paths navigate differently.** `profile_drawer.dart` → `context.go('/home')` (then redirected to `/login`), `profile_screen.dart` → `context.go('/login')`. Status: Open.
- **L-07 — Saved Jobs "Chat" goes to a route that does not exist.** `saved_jobs_screen.dart` `onChat: () => context.push('/chat')` (router has `/chats`, `/chats/:id`). Status: Open (found in Batch 6, not changed).
- **L-06 — Services "Register as Service Provider" opens Apply as Expert.** `services_marketplace_screen.dart` ~line 282 → `/apply-expert`. Status: Needs product confirmation.

---

## UI/UX Issues
- Open: M-01 (filters), M-05 (profile URL), M-11 (old Open To text), L-01, L-02, L-06, L-07. Fixed: H-01, H-06.

## API/Backend Issues

Flutter ↔ backend mismatches from the audit (**C-01**, **C-02**, **H-06**, **M-06**) are fixed or implemented; see updates above. Full table in [API_CONTRACT.md](API_CONTRACT.md#known-mismatches).

Backend-side issues (report to backend developer; **do not fix from this repo**). Verified in `km-backend` `b5a2956`:

| ID | Issue | Evidence | App workaround today |
|---|---|---|---|
| B-01 | `GET /user/:id` registered before `GET /user/bookmarks` and `GET /user/settings` | `user/api.go` lines 42 vs 58–59 | reads `bookmarked_jobs` / `settings` from `GET /user/profile` |
| B-02 | `POST /wallet/topup/verify` credits the client-sent `amount` | `wallet/service.go` uses `req.Amount` for the credit | app sends the server order amount |
| B-03 | `POST /mentorships/book-wallet` charges ₹100 when price ≤ 0 | `mentorship/service.go` `price = 100 // fallback` | app books price ≤ 0 via `/mentorships/book` (`expert_detail_screen.dart` line ~72) |
| B-04 | `GET /api/community/users` returns full user records publicly | `user/controller.go` `GetCommunityUsers` returns `users` | app does not call it |
| B-06 | `POST /wallet/withdraw` has no idempotency key | `wallet/api.go`, `WithdrawalRequest` has no request id | a retried request could create a second withdrawal; app treats timeout/5xx as "outcome unknown" and tells the user to check transactions first |
| B-07 | `DELETE /user/skill/:skillName` does not URL-decode the name | Fiber config has no `UnescapePath`; `controller.go` `c.Params("skillName")` compared with `strings.EqualFold` (`service.go` `DeleteSkill`), 200 even when nothing matched | app keeps website-style encoding and reports "Could not remove …" when the returned profile still has the skill (single-word skills work). Backend fix: `url.PathUnescape` before comparing |
| B-08 | `GET /user/viewers` returns private fields of viewers (mobile, email) | `user/controller.go` `GetProfileViewers` returns full `[]*User` records | app does **not** call it; Profile viewers blocked (7e) until public-safe fields are returned |
| B-09 | `open_to_work.visibility` "recruiters" is not enforced | only used as a default in `service.go` `UpdateOpenToWork`; website shows it publicly | app says "Saved as your preference. KaamMilega does not yet limit who can see this status." |
| B-10 | Open To / Providing Services values are not validated | `UpdateOpenToWork` / `UpdateProvidingServices` accept any strings | app offers only the website's job types, `all`/`recruiters`, and `INR` |
| B-05 | No `/notifications`, `/wallet/transfer`, feed/posts, services, ₹99 pass, gig dispatch, resume field, push/FCM | route list | coming-soon states |

## Authentication Issues
- H-05 (mid-session 401), M-10 (token storage) — open. C-01, H-03, H-04 fixed (Batches 1, 4).

## Performance Issues
- `IndexedStack` builds all four tab screens (incl. 7.3k-line Profile) at shell start. Observed in code; impact not measured.
- `chatMessagesProvider` now autoDispose; `userLookupProvider` resets per session (Batch 4).
- `_processedMessageIds` unbounded (M-08).
- No measured performance problems — **not profiled** in this audit.

## Fix batches (25 Sep 2026)

| Batch | Scope | Result |
|---|---|---|
| 1 | C-01 OTP new-user registration | Fixed |
| 2 | C-02 wallet withdrawal contract | Fixed (no real payout made) |
| 3 | H-01 invented data | Fixed |
| 4 | H-03 logout leftovers, H-04 guest API calls | Fixed |
| 5 | H-02 errors as empty data, M-04 cache | Partly fixed (see H-02) |
| 6 | H-06 saved jobs | Fixed |
| 7 | M-06: 7a edit/delete education & experience, 7b remove skill, 7c My Sessions, 7d Open To sheets, 7e profile viewers | 7a–7c fixed · 7d implemented, awaiting verification · 7e blocked (B-08) |
| — | Test-run fixes | App-wide provider retry policy (M-12) |

Not addressed yet: H-05, M-01, M-02, M-03, M-05, M-07, M-09, M-10, M-11, L-01…L-07, B-01…B-10.

## Verification log
| When | `dart format` | `flutter analyze` | `flutter test` | Phone |
|---|---|---|---|---|
| After Batch 7 (first run) | 12 files formatted | 1 warning | +153 −3 | — |
| After retry-policy fix + 7d (25 Sep, 15:57) | 4 files formatted | 1 warning, 2 info (all in `open_to_preferences_test.dart`) | +171 −1 (`Open To Work sheet server error` — Save scrolled off the 800×600 test view) | — |
| After test fix (25 Sep, 16:04) | 0 files changed | **No issues found** | **+172, all passed** | **pending** |

## Build/Environment Issues
- **Release signing:** `android/app/build.gradle.kts` release build uses `signingConfigs.getByName("debug")`. iOS signing team not configured (per project notes; not re-verified in Xcode).
- **Base URL is a compile-time constant** (`ApiConstants.baseUrl`), no dev/staging flavour.
- **Working tree:** branch `feat/ui-ux-polish`; Batches 1–8 are uncommitted (the owner commits and pushes). Empty folders `Daily report/` and `New folder/` at repo root (not tracked by git).
- **Verification:** `dart format` / `flutter analyze` / `flutter test` are run by the owner on Windows (see Verification log). Not verified yet: Android/iOS release builds, Razorpay TEST mode, phone testing of Batches 1–7.
- Platform folders `web/`, `windows/`, `macos/`, `linux/` exist, but `razorpay_flutter` supports Android/iOS only; other platforms are untested.

## Data Issues
- Open: M-02 (fallback labels/ratings), M-03 (fallback cities), M-09 (jobs cache). Fixed: H-01 (mock data), M-04 (cache mapping).
- Profile analytics read backend keys `profile_views`, `post_impressions`, `search_appearances` (correct per backend `User` struct).

## Documentation Issues
- **D-01 — `API_INTEGRATION_STATUS.md` (23 Sep) is outdated:** says education/experience have no update/delete (now exist), withdraw is not built (now exists, C-02), `PATCH /user/profile` ignores open-to-work (now separate endpoints), and lists `POST /user/register` as used by Register (it is not, C-01).
- **D-02 — `flutter_app_feature_tracker.md`** is not maintained with these docs; use FEATURE_STATUS.md for current status.
- **D-03 — `README.md`** is the default Flutter template.
- Code comment still wrong: `chat_websocket_service.dart` "Exponential backoff" (backoff is linear).
