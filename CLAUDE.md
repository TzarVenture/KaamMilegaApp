# CLAUDE.md — Rules for AI coding agents

Applies to Claude, Cursor, Antigravity and any other agent working in this repo.
Start with [AI_QUICK_START.md](AI_QUICK_START.md). Details: [architecture.md](architecture.md) · [FEATURE_STATUS.md](FEATURE_STATUS.md) · [API_CONTRACT.md](API_CONTRACT.md) · [KNOWN_ISSUES.md](KNOWN_ISSUES.md).
**Source code wins over every doc.** Verify before acting.
Docs updated 25 Sep 2026 after fix Batches 1–7 (see [KNOWN_ISSUES.md § Fix batches](KNOWN_ISSUES.md#fix-batches-25-sep-2026)).

## Project
KaamMilega Flutter mobile application (`kaam_milega`, app id `com.kaammilega.app`). Backend: separate Go repo `km-backend` at `https://api.kaammilega.com/api`.

## Scope
- Primary users: normal users/candidates, guest users, gig workers.
- Employer/Recruiter and Admin functionality is **out of Flutter scope** unless explicitly requested.

## Architecture (actual)
```
Screen (Consumer*Widget) → Riverpod Notifier/AsyncNotifier/FutureProvider
  → Repository (features/*/repositories) → ApiClient (core/network/api_client.dart, Dio)
  → km-backend → AppException mapping → Model.fromJson → state → UI
```
- Endpoints only in `lib/core/constants/api_constants.dart`.
- Navigation: GoRouter in `lib/app/router.dart`; one redirect: `AuthGuard.redirect` (`lib/app/auth_guard.dart`).
- Auth state: `authProvider` (`features/auth/providers/auth_provider.dart`). Token + caches: `LocalStorage` (SharedPreferences).
- Profile/account endpoints live in `AuthRepository` (there is no profile repository).
- Shared UI: `lib/shared/widgets/`, theme in `lib/app/theme/`.
- List responses: `readListResponse` (`core/network/response_list.dart`) — Go `null` = empty, unknown shape = error.
- Errors on screens: `NetworkStateView.fromError(error, onRetry:)`.
- User-scoped providers must watch `sessionUserIdProvider` so they reset on logout / account switch.
- Root `ProviderScope(retry: appProviderRetry)`: only network/timeout/5xx auto-retry (max 2). In tests, pass `retry: appProviderRetry` (or `(_, _) => null`) to containers/scopes whose providers fail on purpose, or `.future` waits through Riverpod's default 10 retries.

## Rules
Future agents must:
- **Inspect before modifying**: read the target files and trace UI → provider → repository → endpoint.
- **Use the existing architecture**; do not add a second state/navigation/auth/HTTP layer. Do not copy existing deviations (screens calling repositories/ApiClient directly).
- **Reuse** existing widgets (`AppButton`, `AppTextField`, `showAppDialog`, `showAuthPromptDialog`, `NetworkStateView`, `LoginRequiredView`, shimmer set, `SheetDragHandle`, `FadeSlideIn`, `PressableScale`), providers, repositories and models.
- **Use real backend data.** No mock, demo or invented users/jobs/companies/ratings/counts. No fake success messages. H-01 (invented data) was fixed in Batch 3 — do not reintroduce any. Offer only backend or website-confirmed values in selectors (e.g. Open To job types, visibility, currency — API_CONTRACT §2).
- **Do not invent APIs, request fields or response fields.** Check backend `internal/features/<name>/{api,controller,domain}.go` (read-only) or [API_CONTRACT.md](API_CONTRACT.md). If it cannot be verified, stop and report.
- **Do not modify the backend** (or km-frontend) unless explicitly requested.
- **Error handling:** 404 = "coming soon"/unavailable, never "no data"; show real backend errors; don't swallow exceptions into empty lists.
- **Preserve authentication:** token handling in `ApiClient`/`LocalStorage`, `AuthNotifier`, 401 session clear, `AuthGuard`. No fake tokens.
- **Preserve guest mode:** guests stay unauthenticated (`AuthState.isGuest`, memory only); protected actions use `showAuthPromptDialog` / `AuthGuard.openProtected`; guests must not call authenticated APIs.
- **Preserve navigation:** add routes in `AppRouter.routes`; protected roots in `AuthGuard._protectedRoots`. No navigation from `build()`, no `Future.delayed` navigation, no competing redirects.
- **Preserve API contracts** already working; when app and backend disagree on an existing endpoint, align the app to the backend.
- **Backend bugs stay backend bugs:** do not hide or fake around them in Flutter (e.g. skill delete B-07: keep website URL-encoding and check the returned profile; profile viewers B-08: do not call `/user/viewers` until it returns public-safe fields). Record them in KNOWN_ISSUES.
- **Payments:** never mark money as added/paid unless the backend verify endpoint confirmed it (`core/payments/razorpay_checkout.dart` pattern).
- **Avoid unrelated refactoring**, renames and file moves. Report unrelated problems under "DISCOVERED BUT NOT CHANGED".
- **UI / brand (spec 25 Sep 2026):** use `AppColors` tokens only, never new inline hex values. Navy `#071A4D` (`brandNavy`/`primary`), Orange `#FF6B00` (`brandOrange`/`accent`), Blue `#0B5ED7` (`blue`: links, focus, Jobs), service colours `module*` (+ `module*Light`). Wordmark: "Kaammi" navy · "lega" orange · "™" navy. Fonts (`AppFonts`): Poppins (400 body, 500 labels, 600 buttons / H3, 700 headings, 800 hero); Inter for form fields, captions / meta, transaction ledgers and analytics; Noto Sans Devanagari for Hindi (fallback) and the Hindi tagline (`AppTextStyles.taglineHindi`). Type scale in `AppTextStyles`. Buttons: primary navy (hover / pressed `#0B1F52`), accent orange (`AppButton(accent: true)`, hover `#FF8A00`), outline navy (hover blue). Prohibited: emojis (UI text, messages, code comments), sparkle icons (`Icons.auto_awesome*`) as decoration, pulsing / blinking status dots, AI buzzword copy; do not cap text scaling — make layouts flexible; handle small screens, keyboard, long text, loading/empty/error states; mobile bottom sheets over desktop-style dropdowns.
- **Keep files' line endings** (repo uses CRLF on Windows, `core.autocrlf=true`).
- **Test changes.**

## Token Efficiency
- Read [AI_QUICK_START.md](AI_QUICK_START.md), then only the files relevant to the task (use architecture.md §20–21 as the map).
- Use targeted searches (`rg`), read file sections, not whole large files (`profile_screen.dart` is ~7.3k lines — search for the `_build…`/`_open…` method).
- Do not re-read unchanged files, print whole files, repeat findings, or explore unrelated folders.
- Implement the smallest correct change.

**Token efficiency must NEVER reduce** reasoning quality, implementation quality, testing, error handling, security, responsiveness or performance.
Optimize for: **"Maximum engineering quality per token."**

## Verification
Normally run (when the Flutter SDK is available):
```
dart format .        # only on files you changed if the task forbids repo-wide formatting
flutter analyze
flutter test
```
- Widget tests use a wide test font: text inside a `Row` must be `Flexible`/`Expanded` or it overflows.
- Avoid `<...>` in `///` doc comments (`unintended_html_in_doc_comment`); use backticks.
- The owner runs these on Windows and pastes results; record them in KNOWN_ISSUES "Verification log".
- A focused `TextField` scrolls itself back into view; unfocus before `ensureVisible` + tap on buttons lower in a sheet.
- For release-related work also build (`flutter build apk` / iOS) and note that release signing currently uses the debug key.

## Stop Conditions
Stop and report (do not guess) if:
- backend changes are required;
- the API contract is unclear or unverified;
- required backend functionality does not exist;
- destructive changes are required (deleting data/files, git history);
- authentication/security behaviour would change unexpectedly;
- payment/financial behaviour is unclear (see KNOWN_ISSUES B-02, B-03, B-06); never trigger a real withdrawal or payment in testing;
- existing behaviour would intentionally be broken.

## After significant changes
Update the relevant doc(s) only when the task asks for documentation maintenance: architecture.md (structure/flows), FEATURE_STATUS.md (status), API_CONTRACT.md (endpoints), KNOWN_ISSUES.md (fixed/new issues).
