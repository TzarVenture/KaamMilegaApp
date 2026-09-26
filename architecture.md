# KaamMilega Flutter Application Architecture

> **IMPORTANT:**
> This document describes the current implementation and must be updated after significant architectural or feature changes.
>
> **Last Audited:** 25 September 2026
> **Audited code:** branch `feat/ui-ux-polish`, HEAD `eaf5dc8`.
> **Updated:** 25 September 2026 after fix Batches 1–7 (uncommitted working tree). Summary of changes: [KNOWN_ISSUES.md § Fix batches](KNOWN_ISSUES.md#fix-batches-25-sep-2026).
> **Backend checked (read-only):** `TzarVenture/KaamMilega` → `km-backend`, `main` @ `b5a2956` (audit) and `51c8e10` (25 Sep, for Batch 7 contracts).
> **Rule:** SOURCE CODE > this document. Verify before relying on any detail.

Related docs: [AI_QUICK_START.md](AI_QUICK_START.md) · [CLAUDE.md](CLAUDE.md) · [FEATURE_STATUS.md](FEATURE_STATUS.md) · [API_CONTRACT.md](API_CONTRACT.md) · [KNOWN_ISSUES.md](KNOWN_ISSUES.md)
Older docs in the repo (not maintained by this audit): `API_INTEGRATION_STATUS.md` (23 Sep, partly outdated, see KNOWN_ISSUES D-01), `flutter_app_feature_tracker.md/.csv` (feature IDs reused in FEATURE_STATUS.md).

---

## 1. Project Overview

- **KaamMilega** is an Indian jobs / gig-work platform (jobs, instant/hourly work, skills, experts & mentorship, events, networking, chat, wallet).
- **This repo** is the Flutter mobile app (`pubspec.yaml` name `kaam_milega`, Android/iOS app id `com.kaammilega.app`).
- **Primary mobile users:** normal users / candidates, guest users, gig workers.
- **Backend:** separate Go repo `km-backend` (Fiber v2, MongoDB, JWT). Base URL `https://api.kaammilega.com/api`. **Never edited from this repo.**
- **Out of mobile scope:** Employer/Recruiter and Admin functionality (job posting, applicant management, `/api/admin/*`, recruiter application routes). The website `km-frontend` covers those.

## 2. Technology Stack

Versions from `pubspec.yaml` / `pubspec.lock` (verified).

| Area | Package | Locked version |
|---|---|---|
| SDK | Dart `^3.13.3`, Flutter `>=3.44.0` (lock `sdks`) | — |
| State | `flutter_riverpod` (+ `flutter_riverpod/legacy.dart` for `ChangeNotifierProvider` in chat) | 3.4.3 |
| Navigation | `go_router` | 18.0.1 |
| HTTP | `dio` | 5.11.1 |
| WebSocket | `dart:io` `WebSocket` (no package) | — |
| Local storage | `shared_preferences` | 2.5.5 |
| Connectivity | `connectivity_plus` | 7.3.1 |
| Payments | `razorpay_flutter` | 1.4.7 |
| Images / files | `cached_network_image` 4.0.0, `image_picker` 1.2.3, `file_picker` 8.3.7 | — |
| Other | `shimmer` 3.0.0, `intl` 0.20.3, `url_launcher` 6.3.2 | — |
| Lints | `flutter_lints` ^6.0.0 (`analysis_options.yaml` excludes platform folders) | — |

**Not present:** Firebase / FCM, secure storage (`flutter_secure_storage`), code generation (freezed/json_serializable/riverpod_generator), localization files, crash reporting.

## 3. Project Structure

```
lib/
├── main.dart                     # LocalStorage.init() → ProviderScope(KaamMilegaApp)
├── app/
│   ├── app.dart                  # MaterialApp.router + OfflineBannerOverlay
│   ├── router.dart               # routerProvider (GoRouter), AppRouter.routes, kMinSplashDuration
│   ├── auth_guard.dart           # AuthGuard.redirect / openProtected / takePendingPath
│   └── theme/                    # app_colors.dart, app_text_styles.dart, app_theme.dart
├── core/
│   ├── constants/                # api_constants.dart (ALL endpoint paths), app_branding.dart
│   ├── network/                  # api_client.dart, app_exception.dart, connectivity_*.dart, network_status.dart, offline_banner.dart
│   ├── payments/razorpay_checkout.dart
│   └── storage/local_storage.dart
├── features/<feature>/
│   ├── models/                   # fromJson/toJson by hand
│   ├── repositories/             # ApiClient calls; Provider<XRepository>
│   ├── providers/                # Notifier / AsyncNotifier / FutureProvider
│   ├── services/                 # chat only (WebSocket)
│   └── presentation/             # screens + widgets/
└── shared/widgets/               # reusable UI (buttons, fields, shimmer, dialogs, state views)
test/                             # 13 test files (see §19)
```

Features: `applications, auth, chat, cities, company, events, experts, explore, feed, home, instant_work, interviews, jobs, navigation, network, notifications, peer_to_peer, profile, services, skills_marketplace, splash, wallet`.

## 4. Architecture Pattern

```
Presentation (ConsumerWidget / ConsumerStatefulWidget)
  → Riverpod provider (Notifier / AsyncNotifier / FutureProvider)
    → Repository (features/*/repositories)
      → ApiClient (core/network/api_client.dart, wraps Dio)
        → km-backend  (https://api.kaammilega.com/api)
      ← Response → AppException mapping
    ← Model.fromJson
  ← State
← UI
```

| Layer | Responsibility | Where |
|---|---|---|
| UI | Render state, user input, navigation | `features/*/presentation` |
| Provider/Notifier | Screen state, loading/error, offline cache fallback, optimistic updates | `features/*/providers` (some `FutureProvider`s live at the bottom of repository files, e.g. `myApplicationsProvider`) |
| Repository | Endpoint call, body building, response parsing | `features/*/repositories` |
| ApiClient | Base URL, timeouts, auth header, 401 session clear, error → `AppException` | `core/network/api_client.dart` |
| LocalStorage | Token, cached user, offline caches, device-only prefs | `core/storage/local_storage.dart` |

**Deviations that exist today (do not copy):**
- Some screens call repositories directly without a provider: `job_detail_screen.dart` (`getJobById`, `hasApplied`), `apply_modal.dart`, `expert_detail_screen.dart` (booking/payment), `settings_screen.dart` (`getSettings`/`updateSettings`), `network_screen.dart`, `application_detail_screen.dart`.
- `peer_to_peer_screen.dart` calls `ApiClient` directly (`GET /user/search`) — no repository.
- `userLookupProvider` (`chat/providers/user_lookup_provider.dart`) calls `ApiClient` directly.
- Chat messages use a legacy `ChangeNotifierProvider.family`.
- There is no dedicated profile repository: all profile/account endpoints live in `AuthRepository`.

## 5. Application Startup

```
main()  → WidgetsFlutterBinding.ensureInitialized()
        → LocalStorage.init()                          (SharedPreferences)
        → runApp(ProviderScope(retry: appProviderRetry, KaamMilegaApp))
                                                       (core/network/provider_retry.dart: only network/timeout/5xx
                                                        errors auto-retry, max 2 times; 401/403/404/validation shown at once)
KaamMilegaApp → MaterialApp.router(routerConfig: routerProvider)
routerProvider → GoRouter(initialLocation: '/splash', refreshListenable: auth + splash timer)
authProvider.build() → returns AuthState(isChecking: true) → microtask checkAuthStatus()
checkAuthStatus():
   no token            → isChecking=false, not authenticated
   token present       → load cached user → refreshProfile() (GET /user/profile)
                          401 → ApiClient clears session → AuthState()          (logged out)
                          offline/5xx → keep token + cached profile → authenticated
AuthGuard.redirect: stays on /splash while isChecking OR < kMinSplashDuration (1.5 s)
   then → '/home' (signed in)  or  '/login' (not signed in)
         → '/complete-profile' while AuthState.needsProfileCompletion (OTP account not registered yet)
```

Files: `lib/main.dart`, `lib/app/app.dart`, `lib/app/router.dart`, `lib/features/auth/providers/auth_provider.dart` (`checkAuthStatus`), `lib/app/auth_guard.dart`, `lib/features/splash/presentation/splash_screen.dart`.

## 6. Authentication

| Flow | UI | Notifier method | Endpoint |
|---|---|---|---|
| Phone OTP send | `login_screen.dart` | `AuthNotifier.sendOtp` | `POST /auth/otp/send` `{mobile, role:"user"}` |
| Phone OTP verify | `otp_screen.dart` | `verifyOtp` → `AuthVerificationResult{token,isRegistered,user}` | `POST /auth/otp/verify` `{mobile, code, role}` |
| Email + password login | `login_screen.dart` | `loginWithPassword` | `POST /auth/login/password` |
| Email + password register | `register_screen.dart` | `registerWithPassword` | `POST /auth/register/password` |
| Forgot / reset password | `forgot_password_screen.dart` | `forgotPassword`, `resetPassword` | `POST /auth/password/forgot`, `/auth/password/reset` |
| Email verification (profile) | `profile_screen.dart` `_showEmailOtpDialog` | `sendEmailOtp`, `verifyEmailOtp` | `POST /auth/otp/email/send`, `/verify` |
| Change password | `settings_screen.dart` | `changePassword` | `PUT /user/password` |

- **After OTP verify:** registered users → `context.go(AuthGuard.takePendingPath())`. New users (`is_registered:false`) → `/complete-profile` (`complete_profile_screen.dart`) → `AuthNotifier.completeRegistration` → `POST /user/register` (Batch 1, fixed C-01). `AuthState.needsProfileCompletion` = signed in and `!hasCompletedRegistration` (`is_registered`, or education level and city already set); `AuthGuard` keeps such accounts on `/complete-profile`. Back and "Use a different account" both confirm, log out and return to Login (no half-signed-in state).
- **Token storage:** `LocalStorage.saveToken` → SharedPreferences key `km_auth_token` (plain, not encrypted). Cached user: `km_user_data`.
- **Auth header:** `ApiClient` `onRequest` interceptor adds `Authorization: Bearer <token>` when a token exists.
- **401:** `ApiClient` `onError` → `LocalStorage.clearSession()`. `AuthState` is **not** updated at that moment; `AuthGuard.isSignedIn` requires a saved token, so the next redirect sends the user to Login. `checkAuthStatus` does reset state on startup.
- **403:** mapped to `AppAuthException` (same class as 401) but does not clear the session.
- **Session restore:** `checkAuthStatus` (see §5). Offline start keeps the cached user.
- **Logout:** `AuthNotifier.logout()` → `AuthRepository.logout()` → `LocalStorage.clearSession()` (local only; no backend logout endpoint). Callers: `profile_drawer.dart` (then `context.go('/home')` → redirected to `/login`) and `profile_screen.dart` `_showLogoutConfirmationDialog` (then `context.go('/login')`). User-scoped providers watch `sessionUserIdProvider` and reset on logout / account switch; the chat socket is closed; saved job IDs are cleared (Batch 4, fixed H-03).
- **Route protection:** `AuthGuard` (§8) + per-action `showAuthPromptDialog` (`shared/widgets/auth_prompt_dialog.dart`) + `AuthGuard.openProtected`.
- **Login role:** every auth request sends `role: "user"`.

## 7. Guest Mode

- Entered from Login → "Explore Jobs as Guest": `authProvider.notifier.enterGuestMode()` then `context.go('/jobs')` (`login_screen.dart`).
- `AuthState.isGuest = true` **in memory only**. Restart → Splash → `/login`. No token is created; `isAuthenticated` stays false.
- **Guest can open:** every route not in `AuthGuard._protectedRoots` and not `/chats/:id` — `/home`, `/jobs`, `/jobs/:id`, `/saved-jobs`, `/events`, `/experts`, `/explore`, `/instant-work`, `/skills-marketplace`, `/services`, `/feed`, `/notifications`, `/company/:id`, and the Chats (login prompt, `LoginRequiredView`) / Profile tabs of the shell.
- **Guest is redirected to Login for:** `/my-applications`, `/applications/*`, `/interviews`, `/my-sessions`, `/network`, `/apply-expert`, `/settings`, `/wallet/*`, `/peer-to-peer`, `/chats/:id`. The requested path is remembered (`_pendingPath`) and restored after login (except chat).
- **Action-level gating (login prompt instead of API call):** Apply (`apply_modal.dart` checks `isAuthenticated`), profile edits (`profile_screen.dart`), event registration (`event_detail_screen.dart`), wallet/network/interviews/apply-expert via `AuthGuard.openProtected`.
- **Saved jobs for guests:** stored on device only (`JobsNotifier.toggleSaveJob` → `LocalStorage.saveSavedJobIds`), never sent to the server.
- Guests no longer trigger `GET /chats` or `GET /user/search` (Batch 4, fixed H-04).

## 8. Navigation

- `GoRouter` built in `routerProvider` (`lib/app/router.dart`); single global `redirect` → `AuthGuard.redirect` (`lib/app/auth_guard.dart`). `refreshListenable` = auth fields `(isChecking, isAuthenticated, isGuest, needsProfileCompletion)` + splash timer.
- Tabs: `/home`(0), `/jobs`(1), `/chats`(3), `/profile`(4) all build `MainNavigationShell(initialIndex)` (`features/navigation/presentation/main_navigation_shell.dart`), which holds an `IndexedStack` of Home / Jobs / ChatList / Profile. Index 2 is the centre "+" quick-action sheet. Tab switches inside the shell use `setState`, not routes.

| Path | Screen | Params / extra | Access |
|---|---|---|---|
| `/splash` | `SplashScreen` | — | startup |
| `/` | redirect → `/home` | — | — |
| `/login`, `/register`, `/otp`, `/forgot-password` | auth screens | `/otp` extra `String phone`; `/forgot-password` extra `String? email` | always open |
| `/complete-profile` (`AuthGuard.completeProfilePath`) | `CompleteProfileScreen` | — | signed-in accounts not registered yet (forced by guard) |
| `/home`, `/jobs`, `/chats`, `/profile` | `MainNavigationShell` | — | guest + user |
| `/jobs/:id` | `JobDetailScreen` | `id`; extra `Job?` (initial data) | guest + user |
| `/saved-jobs` | `SavedJobsScreen` | — | guest + user |
| `/my-applications` | `MyApplicationsScreen` | — | protected |
| `/applications/:id` | `ApplicationDetailScreen` | `id` = application id **or job id** (matched either way) | protected |
| `/interviews` | `InterviewsScreen` | — | protected |
| `/my-sessions` | `MySessionsScreen` (drawer "My Sessions") | — | protected |
| `/network` | `NetworkScreen` | — | protected |
| `/chats/:id` | `ChatDetailScreen` | `id` conversation id or `new-<userId>`; extra `Map<String,String>{receiverId,title}` | protected (pending path not restored) |
| `/apply-expert` | `ApplyExpertScreen` | — | protected |
| `/settings` | `SettingsScreen` | — | protected |
| `/wallet`, `/wallet/transactions`, `/wallet/add-money`, `/wallet/withdraw`, `/wallet/transfer` | wallet screens | — | protected |
| `/events` | `EventsScreen` (detail opened as a pushed page) | — | guest + user |
| `/experts` | `ExpertsScreen` | — | guest + user |
| `/explore` | `ExploreScreen` | — | guest + user |
| `/instant-work` | `InstantWorkScreen` | — | guest + user |
| `/skills-marketplace` | `SkillsMarketplaceScreen` | — | guest + user |
| `/services` | `ServicesMarketplaceScreen` | — | guest + user |
| `/peer-to-peer` | `PeerToPeerScreen` | — | protected |
| `/feed` | `FeedScreen` | — | guest + user |
| `/notifications` | `NotificationsScreen` | — | guest + user |
| `/company/:id` | `CompanyScreen` | `id` (ignored by screen) | no in-app link; shows "Coming Soon" |

## 9. State Management

All providers are global (no `ProviderScope` overrides except in tests). `autoDispose`: `profileJobsProvider`, `chatMessagesProvider`, `savedJobDetailProvider`, `myBookingsProvider`. The root `ProviderScope` sets `retry: appProviderRetry` (§5).

| Provider | Type | File | Owns |
|---|---|---|---|
| `authProvider` | `NotifierProvider<AuthNotifier, AuthState>` | `auth/providers/auth_provider.dart` | user, isAuthenticated, isGuest, isChecking, isLoading, error, needsProfileCompletion; all profile mutations (edits via `_applyProfileEdit`: state = profile returned by server) |
| `sessionUserIdProvider` | Provider | same | current user id; user-scoped providers watch it to reset on logout/switch |
| `routerProvider` | `Provider<GoRouter>` | `app/router.dart` | router |
| `apiClientProvider` | `Provider<ApiClient>` | `core/network/api_client.dart` | Dio client |
| `networkStatusProvider` / `isOnlineProvider` | Notifier / Provider | `core/network/connectivity_provider.dart` | online/offline |
| `jobsProvider` | `NotifierProvider<JobsNotifier, JobsState>` | `jobs/providers/jobs_provider.dart` | job list, filter, pagination, savedJobIds, cache timestamp |
| `savedJobsProvider`, `savedJobDetailProvider(family, autoDispose)` | Provider / FutureProvider | same | Saved Jobs list, one `GET /jobs/:id` per saved ID (404 → unavailable) |
| `myBookingsProvider` | `FutureProvider.autoDispose` | `experts/repositories/expert_repository.dart` | My Sessions |
| `profileJobsProvider` | `FutureProvider.autoDispose.family<ProfileJobs,String city>` | `profile/providers/profile_jobs_provider.dart` | "Jobs Based On Your Profile" |
| `instantWorkProvider` | Notifier | `instant_work/providers/instant_work_provider.dart` | gig list |
| `myApplicationsProvider` | `FutureProvider` | `applications/repositories/application_repository.dart` | my applications |
| `myInterviewsProvider` | `FutureProvider` | `interviews/repositories/interview_repository.dart` | interviews |
| `pendingInvitationsProvider`, `connectionsProvider`, `connectionStatusProvider(family)` | FutureProvider | `network/providers/network_provider.dart` | network |
| `conversationsProvider` | FutureProvider | `chat/providers/chat_provider.dart` | chat list |
| `chatMessagesProvider(family)` | legacy `ChangeNotifierProvider.autoDispose.family` | same | messages per conversation (+ isLoading/error/`retryHistory`) |
| `chatWebSocketServiceProvider`, `webSocketStatusStreamProvider` | Provider / StreamProvider | `chat/services/…`, `chat/providers/…` | socket |
| `userLookupProvider(family)` | FutureProvider | `chat/providers/user_lookup_provider.dart` | other user profile (names/photos) |
| `eventsProvider` | AsyncNotifier | `events/providers/event_provider.dart` | events (+ optimistic register) |
| `expertProvider` | Notifier | `experts/providers/expert_provider.dart` | mentorship list, category, search |
| `skillsProvider` | Notifier | `skills_marketplace/providers/skills_provider.dart` | skills + categories |
| `walletProvider` | Notifier | `wallet/providers/wallet_provider.dart` | balances, transactions, top-up flow |
| `notificationsProvider`, `unreadNotificationsCountProvider` | AsyncNotifier / Provider | `notifications/providers/notification_provider.dart` | notifications (backend missing) |
| `citiesFutureProvider` | FutureProvider | `cities/repositories/city_repository.dart` | city list |

Refresh / invalidation patterns: `ref.invalidate(...)` after mutations (network, applications, chat); `ref.listen(networkStatusProvider)` auto-refresh on reconnect in `AuthNotifier`, `JobsNotifier`, `WalletNotifier`; `WalletNotifier` wipes state on logout; `JobsNotifier` re-syncs bookmarks on login; `eventsProvider` rebuilds when `authProvider.user` changes. User-scoped providers (applications, interviews, network, conversations, chat messages, user lookup, chat socket) watch `sessionUserIdProvider` (Batch 4).

## 10. API Architecture

- **Base URL:** `ApiConstants.baseUrl = 'https://api.kaammilega.com/api'` (compile-time constant; no flavors/env switching). Every path lives in `lib/core/constants/api_constants.dart` (a few repositories still use literal paths: `'/files/upload'`, `'${mentorships}/book'`, `'${skills}/categories'`, `'${events}/$id/register'`).
- **Timeouts:** connect 15 s, receive 15 s. Headers: JSON content-type/accept.
- **Interceptors (`ApiClient`):** add bearer token; on any response mark online; on 401 clear session; on connection error/timeout mark offline.
- **Error mapping (`ApiClient._handleError` → `core/network/app_exception.dart`):**

| Condition | Exception |
|---|---|
| timeout (connect/send/receive) | `AppTimeoutException` |
| connection error / `SocketException` | `AppNetworkException` (+ offline status) |
| 401, 403 | `AppAuthException(statusCode)` (message from `error`/`message`) |
| 404 | `AppNotFoundException` |
| ≥ 500 | `AppServerException` (generic message) |
| other 4xx (400, 409, 422…) | `AppValidationException` (backend `error` text) |
| cancel / bad certificate / unknown | Validation / Network exception |

- **Response parsing:** hand-written `fromJson`. List responses use `core/network/response_list.dart` (`readListResponse` / `readRawListResponse`): JSON array or `{data:[…]}`; Go `null` / `{data:null}` = empty; any other shape = error (never silently empty).
- **Uploads:** `AuthRepository.uploadFile` → multipart `POST /files/upload` field `file` → reads `url`; relative URLs prefixed with the API host. `ApiConstants.resolveImageUrl` normalises image URLs.

## 11. API Endpoint Inventory

Full contracts: [API_CONTRACT.md](API_CONTRACT.md). Status: **Live** = used by app and verified on backend `b5a2956`; **404** = app calls it, backend has no route; **Mismatch** = route exists, body/shape differs.

| Feature | HTTP | Endpoint (`/api` prefix omitted) | Flutter file | Purpose | Status |
|---|---|---|---|---|---|
| Auth | POST | `/auth/otp/send`, `/auth/otp/verify` | `auth_repository.dart` | phone OTP | Live |
| Auth | POST | `/auth/login/password`, `/auth/register/password` | `auth_repository.dart` | email auth | Live |
| Auth | POST | `/auth/password/forgot`, `/auth/password/reset` | `auth_repository.dart` | reset | Live |
| Auth | POST | `/auth/otp/email/send`, `/auth/otp/email/verify` | `auth_repository.dart` | email verify | Live |
| Auth | POST | `/user/register` | `auth_repository.dart` | complete profile (`/complete-profile`) | Live |
| Profile | GET / PATCH | `/user/profile` | `auth_repository.dart`, `job_repository.dart` | profile, bookmarks, settings | Live |
| Profile | POST | `/user/education`, `/user/experience`, `/user/skill` | `auth_repository.dart` | add items | Live |
| Profile | PUT / DELETE | `/user/education/:id`, `/user/experience/:id` | `auth_repository.dart` | edit / delete (7a) | Live |
| Profile | DELETE | `/user/skill/:skillName` (URL-encoded) | `auth_repository.dart` | remove skill (7b) | Live; multi-word names fail on backend (B-07) |
| Profile | PATCH | `/user/open-to-work`, `/user/providing-services` | `auth_repository.dart` | Open To sheets (7d) | Live (awaiting verification) |
| Profile | POST / PUT / DELETE | `/user/project`, `/user/project/:id` | `auth_repository.dart` | projects | Live |
| Profile | PUT | `/user/password` | `auth_repository.dart` | change password | Live |
| Profile | PUT | `/user/settings` | `auth_repository.dart` | save settings | Live |
| Experts | POST | `/user/apply-expert` | `auth_repository.dart` | become expert | Live |
| Jobs | POST | `/user/bookmark/:jobId` | `job_repository.dart` | toggle bookmark | Live |
| Users | GET | `/user/:id` | `user_lookup_provider.dart` | chat names/photos | Live |
| Users | GET | `/user/search?q=` | `peer_to_peer_screen.dart` | people search | Live |
| Files | POST | `/files/upload` | `auth_repository.dart` | photo/cover/resume | Live |
| Jobs | GET | `/jobs`, `/jobs/:id` | `job_repository.dart` | list/detail | Live |
| Cities | GET | `/cities` | `city_repository.dart` | city list | Live |
| Applications | POST / GET | `/applications`, `/applications/my`, `/applications/check/:jobId` | `application_repository.dart` | apply, list, check | Live |
| Interviews | GET | `/interviews/my` | `interview_repository.dart` | list | Live |
| Network | POST/GET/DELETE | `/network/connect`, `/accept`, `/ignore`, `/pending`, `/connections`, `/connections/:id`, `/status/:id` | `network_repository.dart` | connections | Live |
| Chat | GET / POST | `/chats`, `/chats/:id/messages`, `/chats/messages` | `chat_repository.dart` | chat | Live |
| Chat | WS | `/api/ws/chats?token=` | `chat_websocket_service.dart` | realtime | Live |
| Events | GET / POST | `/events`, `/events/:id/register` | `event_repository.dart` | events | Live |
| Mentorship | GET | `/mentorships` | `expert_repository.dart` | experts | Live (`/mentorships/:id` method exists, no caller) |
| Mentorship | POST | `/mentorships/book`, `/book-wallet`, `/create-order`, `/verify-payment` | `expert_repository.dart` | booking & payment | Live |
| Mentorship | GET | `/mentorships/bookings/my` | `expert_repository.dart` | My Sessions (7c) | Live |
| Mentorship | POST | `/mentorships/bookings/:id/review` | `expert_repository.dart` | rate a completed session | Live (26 Sep) |
| Skills | GET | `/skills`, `/skills/categories` | `skills_repository.dart` | marketplace | Live |
| Wallet | GET | `/wallet/balance`, `/wallet/transactions` | `wallet_repository.dart` | wallet | Live |
| Wallet | POST | `/wallet/topup/create-order`, `/wallet/topup/verify` | `wallet_repository.dart` | add money | Live |
| Wallet | POST | `/wallet/withdraw` | `wallet_repository.dart` | withdraw (`WithdrawalRequest`) | Live (Batch 2) |
| Wallet | POST | `/wallet/transfer` | `wallet_repository.dart` | transfer | 404 → "coming soon" |
| Notifications | GET | `/notifications` | `notification_repository.dart` | list | 404 → "coming soon" |

Declared in `api_constants.dart` but not called: `userBookmarks`, `userSettings` (GET), `posts`, `feed`, `adminCompanies`, `mentorship` (duplicate of `mentorships`).

## 12. WebSocket Architecture

- **Service:** `ChatWebSocketService` (`lib/features/chat/services/chat_websocket_service.dart`), one instance via `chatWebSocketServiceProvider` (never auto-disposed).
- **URL:** built from `baseUrl` → `wss://api.kaammilega.com/api/ws/chats?token=<JWT>` (token in query string; backend reads `ctx.Query("token")`).
- **Connect:** lazily, from `ChatMessagesNotifier._init()` (opening a chat). Skips when offline or no token. 8 s connect timeout.
- **Messages:** JSON `{"type":"NEW_MESSAGE","message":{…ChatMessage}}` — the backend sends it to receiver **and** sender. Other types ignored. Deduplicated by message id (`_processedMessageIds`, grows unbounded).
- **Reconnect:** on error/close while online: up to 5 attempts, delay `attempt × 2 s` (linear). Resets when `ConnectivityService` reports online.
- **Chat state:** `ChatMessagesNotifier` loads history (`GET /chats/:id/messages?limit=50&offset=0`), appends socket messages for the active conversation id, sends via REST `POST /chats/messages` (not over the socket); switches from temporary `new-<userId>` id to the real conversation id after the first send; invalidates `conversationsProvider`.
- **Cleanup:** `dispose()` closes socket/streams, but the provider is never disposed and logout does not close the socket (KNOWN_ISSUES H-03).

## 13. Feature Architecture

Data source codes: **REAL** backend · **LOCAL** device · **HC** hard-coded content/constant · **MOCK** invented data · **FALLBACK** substituted on missing/failed data · **CACHED** last good response. Detailed status: [FEATURE_STATUS.md](FEATURE_STATUS.md).

| Feature | UI | State | Repository / API | Model | Data | Status |
|---|---|---|---|---|---|---|
| Auth | `auth/presentation/{login,otp,register,forgot_password}_screen.dart` | `authProvider` | `AuthRepository` → `/auth/*` | `UserProfile`, `AuthVerificationResult` | REAL | Implemented (incl. `/complete-profile`) |
| Home | `home/presentation/home_screen.dart` | `jobsProvider`, `unreadNotificationsCountProvider` | via `JobRepository` | `Job` | REAL jobs + HC sections (₹99 banner, categories, quick actions) | Partial |
| Jobs list / filters | `jobs/presentation/jobs_screen.dart`, `widgets/filter_modal.dart`, `job_card.dart`, `pagination_bar.dart` | `jobsProvider` | `GET /jobs` | `Job`, `JobFilter`, `JobsResponse` | REAL + CACHED (`km_cache_jobs`) | Implemented |
| Job detail | `jobs/presentation/job_detail_screen.dart` | direct repo calls + `jobsProvider` | `GET /jobs/:id`, `GET /applications/check/:jobId` | `Job` | REAL | Implemented |
| Saved jobs | `jobs/presentation/saved_jobs_screen.dart` | `savedJobsProvider`, `savedJobDetailProvider` | `POST /user/bookmark/:jobId`, ids from `GET /user/profile`, `GET /jobs/:id` per id | `Job` | REAL (user) / LOCAL ids (guest) | Implemented (Batch 6) |
| Apply | `applications/presentation/apply_modal.dart` | direct repo | `POST /applications` | — | REAL | Implemented |
| Applications | `applications/presentation/my_applications_screen.dart`, `application_detail_screen.dart` | `myApplicationsProvider` | `GET /applications/my` | `ApplicationItem` | REAL + CACHED (offline only) | Implemented |
| Interviews | `interviews/presentation/interviews_screen.dart` | `myInterviewsProvider` | `GET /interviews/my` | `InterviewItem` | REAL | Implemented |
| Profile (intro, about, photo, cover, portfolio, contact) | `profile/presentation/profile_screen.dart` (7.3k lines) | `authProvider` | `PATCH /user/profile`, `POST /files/upload` | `UserProfile` | REAL | Implemented |
| Education / Experience | same | `authProvider` add/update/delete | `POST`, `PUT/DELETE /user/education/:id`, `/user/experience/:id` | `EducationItem`, `ExperienceItem` (in `user_profile.dart`) | REAL | Implemented (7a) |
| Skills (profile) | same | `authProvider.addSkill/removeSkill` | `POST /user/skill`, `DELETE /user/skill/:skillName` | `List<String>` | REAL | Implemented (7b; backend decoding bug B-07) |
| Projects | same | `addProject/deleteProject` | `/user/project` POST/PUT/DELETE | `ProjectItem` | REAL | Implemented |
| Resume | same | `uploadResumePdf` | `POST /files/upload` | — | LOCAL URL (`km_resume_url`), sent as `resume_url` on apply | Partial (backend has no resume field) |
| Open To / Providing services | `profile/presentation/widgets/open_to_sheets.dart` (`showOpenToWorkSheet`, `showProvidingServicesSheet`) | `authProvider.saveOpenToWork/saveProvidingServices` | `PATCH /user/open-to-work`, `/user/providing-services` | `OpenToWorkPreferences`, `ProvidingServicesPreferences` | REAL (old phone-only text shown, not sent — M-11) | Implemented (7d), awaiting verification |
| Profile analytics | same `_buildAnalyticsCard` | `authProvider` | `GET /user/profile` (`profile_views`, …) | `UserProfile` | REAL | Implemented |
| Profile viewers | `_buildPeopleWhoViewedCard` | none | none (`GET /user/viewers` exposes private fields, B-08) | — | — | Blocked (7e), "coming soon" |
| Jobs based on profile | `_buildJobsBasedOnProfileCard` | `profileJobsProvider` | `GET /jobs` | `Job` | REAL | Implemented |
| Settings | `profile/presentation/settings_screen.dart` | direct repo | `GET /user/profile`→`settings`, `PUT /user/settings`, `PUT /user/password` | map | REAL | Implemented |
| Network | `network/presentation/network_screen.dart` | network providers | `/network/*` | `ConnectionRequestItem` | REAL | Implemented |
| Peer-to-peer | `peer_to_peer/presentation/peer_to_peer_screen.dart` | local `setState` | `GET /user/search`, `/network/*` | `UserProfile` | REAL | Implemented (protected route) |
| Chat | `chat/presentation/{chat_list,chat_detail}_screen.dart`, `open_chat.dart` | `conversationsProvider`, `chatMessagesProvider` | `/chats*`, WS | `ConversationItem`, `ChatMessage` | REAL | Implemented; unread count HC 0 |
| Instant work (gig) | `instant_work/presentation/instant_work_screen.dart` | `instantWorkProvider` | `GET /jobs?job_types=Instant,Hourly,Gig,Part-time` | `Job` | REAL; filter chips do nothing | Partial |
| Skills marketplace | `skills_marketplace/presentation/skills_marketplace_screen.dart` | `skillsProvider` | `GET /skills`, `/skills/categories` | `SkillItem` | REAL | Implemented |
| Experts / mentorship | `experts/presentation/{experts,expert_detail,apply_expert}_screen.dart` | `expertProvider`, direct repo | `/mentorships*`, `/user/apply-expert` | `ExpertItem` | REAL + FALLBACK labels/rating | Implemented |
| My Sessions | `experts/presentation/my_sessions_screen.dart` | `myBookingsProvider` | `GET /mentorships/bookings/my` | `BookingItem` (`experts/models/booking.dart`) | REAL | Implemented (7c) |
| Services marketplace | `services/presentation/services_marketplace_screen.dart` | none | none | — | HC "coming soon" | UI only |
| Events | `events/presentation/{events,event_detail}_screen.dart` | `eventsProvider` | `GET /events`, `POST /events/:id/register` | `EventItem` | REAL + FALLBACK labels | Implemented |
| Feed / resources | `feed/presentation/feed_screen.dart` | none | none | — | HC "coming soon" | Pending (backend) |
| Explore | `explore/presentation/explore_screen.dart` | none | none | inline `_modules` | HC navigation hub | Implemented |
| Company page | `company/presentation/company_screen.dart` | none | none | — | — | "Coming Soon", unreachable |
| Wallet | `wallet/presentation/*.dart` | `walletProvider` | `/wallet/*` | `WalletSummary`, `WalletTransaction`, `PaymentOrder` | REAL + CACHED (`km_cache_wallet`) | Balance/tx/top-up/withdraw implemented; transfer pending |
| Payments | `core/payments/razorpay_checkout.dart` | `walletProvider.addMoney`, `expert_detail_screen.dart` | create-order → Razorpay → verify | `RazorpayResult` | REAL (server-verified) | Implemented (test mode verification pending) |
| Notifications | `notifications/presentation/notifications_screen.dart` | `notificationsProvider` | `GET /notifications` (404) | `NotificationItem` | — | Backend dependency |
| Cities | `cities/presentation/city_selector_sheet.dart` | `citiesFutureProvider` | `GET /cities` | `City` | REAL + **FALLBACK hard-coded 10 cities** | Implemented |
| Offline | `core/network/offline_banner.dart` | `networkStatusProvider` | — | — | LOCAL | Implemented |

## 14. Loading States

- **Shimmer:** `lib/shared/widgets/shimmer_loading.dart` — `AppShimmer`, `ShimmerBox`, `ShimmerCircle`, `ShimmerLoadingList`, `JobCardSkeleton`, `MyApplicationsSkeleton`, `JobDetailSkeleton`. Used in 11 feature files (home, jobs, applications, profile, etc.).
- **`CircularProgressIndicator`:** 26 occurrences (buttons, small inline loaders, sheets). Do not replace globally.
- **Loading flags:** Notifier states carry `isLoading` / `isActionLoading`; `AsyncValue` for FutureProvider/AsyncNotifier.
- **Empty / error / offline:** `shared/widgets/network_state_view.dart` (`NetworkStateView`, `CachedDataBadge`) + per-screen messages; `OfflineBannerOverlay` app-wide.
- **Errors:** `NetworkStateView.fromError(error, onRetry:)` / `errorMessageFor` pick the error or coming-soon state; repositories rethrow instead of returning `[]` (Batch 5). Remaining exceptions: H-02.

## 15. Error Handling

- Central mapping in `ApiClient` (§10). User-facing texts for auth in `AuthNotifier.otpErrorMessage` / `passwordLoginErrorMessage` (tested in `test/auth_error_messages_test.dart`).
- **404 policy (intended):** "feature not live yet" → coming-soon state, never fake data. Implemented for notifications, wallet (`WalletApiException.isBackendPending`), experts/skills (“under development”), people search.
- **Still hiding errors:** `ApplicationRepository.hasApplied` (→ false), `CityRepository.getCities` (→ hard-coded list), `userLookupProvider` (→ null), profile connections count (→ 0). Applications, interviews, network and chat repositories now rethrow (Batch 5).
- **Automatic retry:** `appProviderRetry` (§5) — failing providers retry network/timeout/5xx errors at most twice; other errors show immediately with a Retry button.
- 500: generic "Server temporarily unavailable" (backend message discarded).
- Parsing errors: mostly unguarded casts (`as Map<String, dynamic>`) inside `try` blocks of the callers; `JobRepository.getJobById` throws `Exception('Invalid job detail response…')`.

## 16. Offline / Network Handling

- `ConnectivityService` singleton (`core/network/connectivity_service.dart`): `connectivity_plus` stream + manual overrides from `ApiClient`; `probeInternet()` DNS lookup (`kaammilega.com`, fallback `google.com`).
- `OfflineBannerOverlay` shows the offline banner.
- **Read-only caches** (SharedPreferences): jobs feed, my applications (shown **only when offline**; server errors are reported), wallet summary + transactions, cached user profile. Shown with a cached timestamp.
- **Writes require network:** apply (`ApplicationRepository.applyToJob`), wallet actions.
- Auto-refresh on reconnect: auth profile, jobs, wallet, chat socket.
- Not supported: offline queueing of writes, background sync.

## 17. Local Storage

All in SharedPreferences via `LocalStorage` (`core/storage/local_storage.dart`). **No secure storage.**

| Key | Content | Cleared on logout/401 |
|---|---|---|
| `km_auth_token` | JWT | yes |
| `km_user_data` (+`km_user_cache_time`) | cached `UserProfile` JSON | yes |
| `km_resume_url` | uploaded resume URL (device-only) | yes |
| `km_device_profile_prefs` | device-only profile fields (`is_available_for_gigs`; legacy `open_to_work` / `providing_services` text from the old sheet, no longer written) | yes |
| `km_cache_applications`(+time) | applications cache | yes |
| `km_cache_wallet`(+time) | wallet cache | yes |
| `km_cache_jobs`(+time) | jobs cache (single key, not per filter) | no |
| `km_saved_job_ids` | saved job ids | yes (Batch 4) |
| `km_selected_city` | city (`saveSelectedCity`/`getSelectedCity` exist but are not called anywhere) | no |
| generic cache keys | `setGenericCache` helper | no |

## 18. UI Architecture

- **Theme:** `app/theme/app_theme.dart` (`AppTheme.lightTheme`: Poppins + Noto Sans Devanagari fallback, buttons, inputs, dialogs radius 20, bottom sheets radius 24, navy floating snackbars, page transitions), `app_colors.dart` (brand spec 25 Sep 2026: `brandNavy #071A4D` = `primary`, `navy #0B1F52`, `blue #0B5ED7`, `brandOrange #FF6B00` = `accent`, `orangeLight #FF8A00`, seven service colours `module*` + light tints, background `#F4F7FB`, text `#111827` / `#5B6472`, border `#D9E0EA`), `app_text_styles.dart` (`AppFonts`, type scale). Fonts bundled in `assets/fonts/` (OFL). Light theme only. Brand/purple/neutral inline colours were replaced by tokens; other inline shades (slate greys, amber/red status colours, events screens' `#D97706`) remain.
- **Reusable widgets (`lib/shared/widgets`):** `AppButton`, `AppTextField`, `AppLogo`/`AppBrandBarLogo`, `showAppDialog` (`app_dialog.dart`), `showAuthPromptDialog`, `SheetDragHandle`, `FadeSlideIn`, `PressableScale`, `NetworkStateView` (+ `.fromError`), `CachedDataBadge`, `LoginRequiredView`, shimmer set, `CategoryTopHeader` + `ThemedCategoryBottomNav` (module screens), `ProfileDrawer` (`features/profile/presentation/widgets/profile_drawer.dart`, used as `endDrawer`).
- **Jobs widgets:** `JobCard`, `FilterModal`, `PaginationBar`, `PromoBanner`, `TopMatchBanner`.
- **Patterns:** mobile bottom sheets for actions (`_showActionSheet`, `_sheetTile` in profile), `IndexedStack` tabs, text scaling not capped (layouts must wrap/flex).
- **Brand assets:** `assets/images/` (`logo.png`, `logo_text.png`, `logo_transparent.png`, …).

## 19. Testing

`test/` — 21 files, 184 `test`/`testWidgets` cases (counted by pattern, 26 Sep 2026).

| File | Covers |
|---|---|
| `auth_flow_test.dart` (22) | `AuthGuard.redirect` / splash / guest routing, complete-profile rules, `/my-sessions` guest redirect |
| `complete_profile_test.dart` (6) | new OTP user registration (Batch 1) |
| `wallet_withdrawal_test.dart` (15) | `WithdrawalRequest` bodies, min ₹50, 400/404/401, outcome unknown (Batch 2) |
| `no_invented_data_test.dart` (3) | no fake rating / company content (Batch 3) |
| `session_cleanup_test.dart` (8) | logout / account switch resets, socket closed (Batch 4); 401 → `onUnauthenticated` |
| `error_states_test.dart` (15) | `readListResponse`, repositories rethrow, error views, retry policy (Batch 5 + fix) |
| `saved_jobs_test.dart` (5) | saved jobs by ID, unavailable rows (Batch 6) |
| `profile_entries_sessions_test.dart` (22) | education/experience/skill requests, `removeSkill` check, `BookingItem`, My Sessions screen (Batch 7a–7c), personal info, rate a completed session |
| `open_to_preferences_test.dart` (14) | Open To PATCH bodies, sheets, turn off, old text, small screen (Batch 7d) |
| `auth_error_messages_test.dart` (9), `auth_screens_ui_test.dart` (3), `network_resilience_test.dart` (14), `wallet_test.dart` (7), `explore_modules_test.dart` (8), `widget_test.dart` (7), `profile_share_link_test.dart` (3), `splash_screen_test.dart` (3), `app_button_text_field_test.dart` (5), `dialogs_sheets_test.dart` (6), `cards_lists_states_test.dart` (7), `home_jobs_ui_test.dart` (2) | audit-time suites |

- Repository tests use a Dio interceptor that answers locally (no network, no real payments). No WebSocket or integration tests.
- **Verification:** run by the owner (Windows). Latest (25 Sep, 16:04): `dart format` 0 changed, `flutter analyze` no issues, `flutter test` 172 passed. **Phone testing pending** (log in [KNOWN_ISSUES.md](KNOWN_ISSUES.md#verification-log)).
- Widget tests use a wide test font: text in a `Row` must be `Flexible`/`Expanded`. A focused text field scrolls itself back into view — unfocus before tapping buttons lower in a sheet.

## 20. Important File Map

| Area | Files |
|---|---|
| Startup / routing | `lib/main.dart`, `lib/app/app.dart`, `lib/app/router.dart`, `lib/app/auth_guard.dart`, `lib/features/splash/presentation/splash_screen.dart` |
| Network core | `lib/core/network/api_client.dart`, `app_exception.dart`, `response_list.dart`, `provider_retry.dart`, `connectivity_service.dart`, `connectivity_provider.dart`, `offline_banner.dart` |
| Endpoints | `lib/core/constants/api_constants.dart` |
| Storage | `lib/core/storage/local_storage.dart` |
| Auth + profile logic | `lib/features/auth/providers/auth_provider.dart`, `repositories/auth_repository.dart`, `models/user_profile.dart` |
| Auth UI | `lib/features/auth/presentation/*.dart` (incl. `complete_profile_screen.dart`) |
| Jobs | `lib/features/jobs/{models,providers,repositories,presentation}/…` |
| Applications / interviews | `lib/features/applications/…`, `lib/features/interviews/…` |
| Profile UI | `lib/features/profile/presentation/profile_screen.dart`, `settings_screen.dart`, `widgets/profile_drawer.dart`, `widgets/open_to_sheets.dart`, `providers/profile_jobs_provider.dart` |
| Chat | `lib/features/chat/{models,providers,repositories,services,presentation}/…` |
| Network | `lib/features/network/…`, `lib/features/peer_to_peer/presentation/peer_to_peer_screen.dart` |
| Wallet / payments | `lib/features/wallet/…`, `lib/core/payments/razorpay_checkout.dart` |
| Experts | `lib/features/experts/…` |
| Shell / tabs | `lib/features/navigation/presentation/main_navigation_shell.dart` |
| Shared UI | `lib/shared/widgets/*.dart`, `lib/app/theme/*.dart` |
| Android | `android/app/build.gradle.kts` (id `com.kaammilega.app`, release uses debug signing), `android/app/src/main/AndroidManifest.xml` |

## 21. Where Do I Change This?

| Task | Inspect first |
|---|---|
| Login / OTP / register | `auth/presentation/{login,otp,register}_screen.dart` → `auth/providers/auth_provider.dart` → `auth/repositories/auth_repository.dart` → `test/auth_*` |
| Session / 401 / logout | `core/network/api_client.dart`, `core/storage/local_storage.dart`, `AuthNotifier.checkAuthStatus/logout`, `app/auth_guard.dart` |
| Add / change an API request | `core/constants/api_constants.dart` → the feature repository → backend `internal/features/<name>/{api,controller,domain}.go` → [API_CONTRACT.md](API_CONTRACT.md) |
| Error texts / HTTP mapping | `core/network/api_client.dart` `_handleError`, `core/network/app_exception.dart` |
| Job UI | `jobs/presentation/jobs_screen.dart`, `widgets/job_card.dart`, `job_detail_screen.dart`, `home/presentation/home_screen.dart` |
| Job model / filters | `jobs/models/job.dart`, `job_filter.dart` (`toQueryParams`), `jobs_response.dart`, cache map in `jobs_provider.dart` `fetchJobs` |
| Navigation / new screen | `app/router.dart` (routes), `app/auth_guard.dart` (`_protectedRoots`), `main_navigation_shell.dart` (tabs) |
| Chat | `chat/services/chat_websocket_service.dart`, `chat/providers/chat_provider.dart`, `chat/repositories/chat_repository.dart`, `chat/presentation/*` |
| Profile | `profile/presentation/profile_screen.dart` (search the `_open…Dialog`/`_build…Card` method), `auth/models/user_profile.dart`, `AuthNotifier` profile methods |
| Settings | `profile/presentation/settings_screen.dart`, `AuthRepository.getSettings/updateSettings` |
| Wallet / payments | `wallet/providers/wallet_provider.dart`, `wallet/repositories/wallet_repository.dart`, `wallet/models/{wallet_summary,withdrawal}.dart`, `core/payments/razorpay_checkout.dart` |
| Experts / bookings | `experts/repositories/expert_repository.dart`, `experts/presentation/expert_detail_screen.dart`, `my_sessions_screen.dart`, `experts/models/{expert_profile,booking}.dart` |
| Open To Work / Providing Services | `profile/presentation/widgets/open_to_sheets.dart`, `OpenToWorkPreferences` / `ProvidingServicesPreferences` in `auth/models/user_profile.dart`, `AuthNotifier.saveOpenToWork/saveProvidingServices` |
| Theme / shared widgets | `app/theme/*`, `shared/widgets/*` |
| Offline behaviour | `core/network/connectivity_service.dart`, `offline_banner.dart`, caches in `local_storage.dart` |
