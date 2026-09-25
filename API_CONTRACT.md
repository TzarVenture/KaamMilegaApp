# KaamMilega Flutter — API Contract

> **Last Audited:** 25 September 2026
> **Verified against:** Flutter code (branch `feat/ui-ux-polish` @ `eaf5dc8` + uncommitted changes) and `km-backend` `main` @ `b5a2956` (`internal/features/<name>/{api,controller,domain,service}.go`), read-only.
> **Updated:** 25 September 2026 after fix Batches 1–7 — new/changed calls re-verified on `KaamMilega` monorepo `main` @ `51c8e10` (`km-backend/`).
> **Base URL:** `https://api.kaammilega.com/api` (`ApiConstants.baseUrl`). Paths below omit `/api`.
> **Rule:** Only verified fields are listed. Anything else: **"Not verified — do not assume."** Re-check `domain.go` + `api.go` before adding or changing a call; the backend changes often.

Auth legend: **Public** (no token) · **Required** (Bearer JWT; backend `AuthMiddleware`) · **Guest** = app lets guests trigger it.
Status legend: **Active** (used by Flutter, backend verified) · **Mismatch** · **Backend unavailable** (404) · **Available, not integrated**.

Common behaviour (from `lib/core/network/api_client.dart`; list bodies via `core/network/response_list.dart` `readListResponse` — JSON array, `{data:[…]}`, and Go `null` = empty list, anything else = error; failing providers auto-retry only network/timeout/5xx errors, max 2 — `core/network/provider_retry.dart`): Bearer token added automatically; errors are `{"error": "<text>"}` on the backend and become `AppException` subclasses — 401/403 → `AppAuthException` (401 also clears the local session), 404 → `AppNotFoundException`, ≥500 → `AppServerException`, other 4xx → `AppValidationException` (backend text kept). Backend controllers mostly return **400 or 500 with `error` text**; 422 is not used by any verified endpoint.

---

## 1. Authentication (`user/api.go`, group `/api/auth`, Public)

### POST `/auth/otp/send`
- **Auth:** Public · **Request:** `{mobile, role:"user"}` · **Response:** `{"message":"OTP sent successfully"}`
- **Flutter:** `AuthRepository.sendOtp` ← `AuthNotifier.sendOtp` ← `login_screen.dart`, `otp_screen.dart` (resend)
- **Errors:** 400 `error` text. · **Status:** Active

### POST `/auth/otp/verify`
- **Auth:** Public · **Request:** `{mobile, code, role:"user"}`
- **Response:** `VerifyOTPResponse {token, is_registered, user: User}`. New number + correct code creates a user with `is_registered:false`.
- **Flutter:** `AuthRepository.verifyOtp` (saves token + user) ← `AuthNotifier.verifyOtp` ← `otp_screen.dart`
- **Errors:** 400 `"Invalid OTP"`, 400 `"OTP not found or expired"` (mapped in `AuthNotifier.otpErrorMessage`, tested). · **Status:** Active (onboarding flow issue: KNOWN_ISSUES C-01)

### POST `/auth/login/password`
- **Auth:** Public · **Request:** `PasswordLoginRequest {email, password, role}` (`identifier` optional, unused) · **Response:** `PasswordLoginResponse {token, user, is_registered}`
- **Flutter:** `AuthRepository.loginWithPassword` ← `AuthNotifier.loginWithPassword` ← `login_screen.dart`
- **Errors:** 401 `"invalid email or password"` (wrong password and unknown email), 400 invalid body; mapped in `passwordLoginErrorMessage`. · **Status:** Active

### POST `/auth/register/password`
- **Auth:** Public (ignores bearer token; always creates a **new** user) · **Request:** `{name, email, password, role}` · **Response:** `PasswordLoginResponse`
- **Flutter:** `AuthRepository.registerWithPassword` ← `AuthNotifier.registerWithPassword` ← `register_screen.dart`
- **Errors:** 400: `"full name is required"`, `"please enter a valid email address"`, `"password must be at least 6 characters long"`, `"an account with this email already exists"`. · **Status:** Active

### POST `/auth/password/forgot` · POST `/auth/password/reset`
- **Auth:** Public · **Request:** forgot `{email, role}`; reset `{email, code, new_password, role}` · **Response:** `{"message": …}`
- **Flutter:** `AuthRepository.forgotPassword/resetPassword` ← `forgot_password_screen.dart` · **Errors:** 400 text · **Status:** Active

### POST `/auth/otp/email/send` · POST `/auth/otp/email/verify`
- **Auth:** Public route (app sends token anyway) · **Request:** `{email}` / `{email, code}` · **Response:** `{"message": …}`
- **Flutter:** `AuthRepository.sendEmailOtp/verifyEmailOtp` (return `bool`, **errors swallowed**) ← `profile_screen.dart` `_showEmailOtpDialog` · **Status:** Active

## 2. User & Profile (`user/api.go`, group `/api/user`, Required)

Most profile mutations return the **full updated `User`**; the app parses it with `UserProfile.fromJson` and caches it.

### GET `/user/profile`
- **Response:** `User` (see `user/domain.go`): `id, mobile, roles, is_registered, name, username, headline, about, profile_image, cover_image, gender, date_of_birth, city, email, is_email_verified, education[], experience[], skills[], projects[], portfolio_url, portfolio_label, bookmarked_jobs[], settings{…}, open_to_work{is_open, job_titles, job_types, locations, visibility}?, providing_services{is_providing, services, hourly_rate, currency, description}?, expert_* fields, profile_views, post_impressions, search_appearances, …`
- **Flutter:** `AuthRepository.getProfile` (falls back to cached user on **any** error), `JobRepository.getBookmarkedJobIds` (`bookmarked_jobs`), `AuthRepository.getSettings` (`settings`) → `authProvider`, `jobsProvider`, `settings_screen.dart`
- **Status:** Active. `open_to_work`/`providing_services` objects are parsed into `OpenToWorkPreferences` / `ProvidingServicesPreferences` (`user_profile.dart`).

### PATCH `/user/profile`
- **Request:** partial map of profile fields (app sends e.g. `name, headline, about, city, gender, profile_image, cover_image, portfolio_url, portfolio_label`; also `profile_picture`, `background_image` on delete — not verified as backend fields). **Response:** `User`
- **Flutter:** `AuthRepository.updateProfile` ← `AuthNotifier.updateProfile / upload*/delete*Photo` ← `profile_screen.dart`
- **Note:** `open_to_work`, `providing_services`, `is_available_for_gigs` are **never sent here** (`AuthNotifier.deviceOnlyProfileKeys`); Open To values are saved with their own PATCH endpoints below. · **Status:** Active

### POST `/user/register`
- **Request:** `RegisterRequest {mobile, roles[], name, gender, education_level, work_experience, city, job_categories[], experience_detail, email, is_email_verified, is_consultant}` · **Response:** `User`
- **Flutter:** `AuthRepository.registerCandidate` (body from `registerRequestBody`: keeps the account's current email and `is_email_verified`) ← `AuthNotifier.completeRegistration` ← `complete_profile_screen.dart` (`/complete-profile`, new OTP users). · **Status:** Active (Batch 1)

### POST `/user/education` · POST `/user/experience` · POST `/user/skill`
- **Request:** education `{school_name, degree, field_of_study, start_date, end_date, grade, description}`; experience `{title, company_name, employment_type, location, start_date, end_date, description}` (backend also has `skills[]`); skill `{skill_name}` · **Response:** `User`
- **Flutter:** `AuthRepository.addEducation/addExperience/addSkill` ← `profile_screen.dart` dialogs · **Errors:** 400 invalid body, 500 · **Status:** Active (add only)

### PUT/DELETE `/user/education/:id` · PUT/DELETE `/user/experience/:id`
- **Request (PUT):** same body as the POST; the backend **replaces the whole entry** and keeps its id. Experience edit re-sends the entry's existing `skills[]` so they are not lost. DELETE: no body.
- **Response:** `User`. A response without a user id is treated as an error (profile not wiped).
- **Flutter:** `AuthRepository.updateEducation/deleteEducation/updateExperience/deleteExperience` (empty id → `AppValidationException`, no request) ← `AuthNotifier` (`_applyProfileEdit`: state = server's profile) ← `profile_screen.dart` row ⋮ → edit sheet / confirm delete. · **Status:** Active (Batch 7a)

### DELETE `/user/skill/:skillName`
- **Request:** skill name URL-encoded (`Uri.encodeComponent`, same as the website). **Response:** `User`; **200 even if nothing matched**.
- **Backend bug (B-07):** the name is not URL-decoded before the case-insensitive compare, so names with spaces or `/` are never removed.
- **Flutter:** `AuthRepository.deleteSkill` ← `AuthNotifier.removeSkill` — succeeds only if the returned `skills` no longer contain the name, otherwise shows "Could not remove …". · **Status:** Active (Batch 7b)

### PATCH `/user/open-to-work` · PATCH `/user/providing-services`
- **Request (whole object; backend replaces it, no validation):**
  - open-to-work `{is_open, job_titles[], job_types[], locations[], visibility}` — `visibility` is `"all"` or `"recruiters"` (backend comment; `""` saved as `"all"`). Job types offered by the app = the website form's list: `Full-time, Part-time, Contract, Freelance, Hourly` (backend has no enum).
  - providing-services `{is_providing, services[], hourly_rate, currency, description}` — `currency` `""` saved as `"INR"`; app/website send `"INR"`.
- **Response:** `{message, open_to_work | providing_services, user: User}`; 400 `error` text.
- **Flutter:** `AuthRepository.updateOpenToWork/updateProvidingServices` ← `AuthNotifier.saveOpenToWork/saveProvidingServices` ← `profile/presentation/widgets/open_to_sheets.dart`. "Turn off" sends `is_open`/`is_providing: false` with the saved values. · **Status:** Active (Batch 7d, awaiting verification). `visibility` is not enforced by the backend (B-09).

### POST `/user/project` · PUT `/user/project/:id` · DELETE `/user/project/:id`
- **Request:** `{title, associated_with, description, project_url, start_date, end_date, skills[], is_current}` · **Response:** `User`
- **Flutter:** `AuthRepository.addProject` (POST or PUT by `id`), `deleteProject` ← `profile_screen.dart` · **Status:** Active

### PUT `/user/password`
- **Request:** `{current_password?, new_password}` (current omitted for OTP-only accounts) · **Response:** `{"message":"Password updated successfully"}`
- **Flutter:** `AuthRepository.changePassword` ← `settings_screen.dart` · **Errors:** 400 text · **Status:** Active

### PUT `/user/settings` (GET via `/user/profile`)
- **Request (full object, backend replaces it):** `{email_job_alerts, email_application_updates, email_marketing, sms_alerts, push_notifications, profile_visibility:"public"|"connections"|"private", language:"en"|"hi"|"hinglish", enable_ai_recommendations, search_engine_indexing}` · **Response:** `{message, settings}`
- **Flutter:** `AuthRepository.updateSettings` ← `settings_screen.dart` · **Status:** Active
- `GET /user/settings` → **500** (route-order bug B-01). `GET/PUT /settings/me` exist and are not shadowed — available, not integrated.

### POST `/user/apply-expert`
- **Request:** `{expert_category, expert_bio, expert_pricing, expert_documents:[Document]}` · **Response:** `User` (`expert_approval_status:"pending"`)
- **Flutter:** `AuthRepository.applyForExpert` ← `apply_expert_screen.dart` · **Status:** Active (document object fields not verified)

### POST `/user/bookmark/:jobId`
- **Request:** none · **Response:** `{message:"Bookmark updated", bookmarked_jobs:[jobId]}`
- **Flutter:** `JobRepository.toggleBookmark` ← `JobsNotifier.toggleSaveJob` (signed-in only; optimistic with rollback) · **Status:** Active
- `GET /user/bookmarks` → **500** (B-01), not used.

### GET `/user/:id`
- **Response:** `User` for other users; **403** `"This profile is private"` when `settings.profile_visibility == "private"`; 404 `"User not found"`.
- **Flutter:** `userLookupProvider` (returns `null` on any error) ← chat list/detail names & photos · **Status:** Active

### GET `/user/search?q=`
- **Request:** query `q` (app also sends `limit=20`; limit handling not verified) · **Response:** `[User]`
- **Flutter:** `peer_to_peer_screen.dart` `_searchUsers` (direct `ApiClient`, **no repository**; guests can trigger it) · **Status:** Active

### Other user routes (available, not integrated)
`GET /user/viewers` (blocked — B-08), `PATCH /user/username`, `GET /user/username/check`, `POST /user/impressions`.

## 3. Files (`file/api.go`)

### POST `/files/upload`
- **Auth:** registered without `AuthMiddleware` in `file/api.go` (comment says "Authenticated routes"; whether the controller checks auth is **not verified**); app sends the token.
- **Request:** multipart, field `file` · **Response:** 201 file record `{id, original_filename, url, path, size, mime_type, uploaded_by, created_at}`
- **Flutter:** `AuthRepository.uploadFile` (reads `url` or `file_url`, prefixes host for relative URLs) ← profile photo, cover, resume · **Status:** Active

## 4. Jobs & Cities

### GET `/jobs`
- **Auth:** Public (Guest OK)
- **Request (query):** `page`, `limit` (default 10), `search`, `city_ids` (comma list; ObjectIDs **or city names**), `job_types`, `genders`, `education` (comma lists), `salary_min`, `salary_max`, `experience_min`, `experience_max` (backend also accepts singular aliases). App sends via `JobFilter.toQueryParams` (`jobs/models/job_filter.dart`).
- **Response:** `{jobs:[Job], total, page, limit}`; with `recruiter_id` query → bare `[Job]` (app handles both).
- **Job fields:** `id, recruiter_id, title, description, company, city_id, city_name, location, salary_min, salary_max, job_type, status, requirements[], we_offer[], gender, education, experience_min, experience_max, created_at, updated_at, applicant_count`.
- **Flutter:** `JobRepository.getJobs` ← `jobsProvider`, `instantWorkProvider`, `profileJobsProvider` → `jobs_screen.dart`, `home_screen.dart`, `instant_work_screen.dart`, `profile_screen.dart`
- **Errors:** 500 text · **Status:** Active

### GET `/jobs/:id`
- **Auth:** Public · **Response:** `Job` (app also accepts `{job: Job}`); 404 when missing
- **Flutter:** `JobRepository.getJobById` ← `job_detail_screen.dart` (direct), `savedJobDetailProvider` (one call per saved job ID not already loaded; 404 → "unavailable" row) ← `saved_jobs_screen.dart` · **Status:** Active

### GET `/cities`
- **Auth:** Public · **Request:** `active=true`, `limit=100`, `search?` · **Response:** `{data:[City], total, page, limit}`
- **Flutter:** `CityRepository.getCities` ← `citiesFutureProvider` ← `city_selector_sheet.dart`, filters. **Any error → hard-coded fallback list** (KNOWN_ISSUES M-03). · **Status:** Active

## 5. Applications & Interviews (Required)

### POST `/applications`
- **Request:** `{job_id, cover_letter, resume_url?}` · **Response:** 201 `Application {id, job_id, recruiter_id, candidate_id, status, cover_letter, resume_url, created_at, updated_at}`
- **Flutter:** `ApplicationRepository.applyToJob` (throws offline) ← `apply_modal.dart`
- **Errors:** 400 `"job_id is required"`, 404 (job), **409 already applied** (app matches text `already applied`), 500. · **Status:** Active

### GET `/applications/check/:jobId`
- **Response:** `{applied: bool}` · **Flutter:** `ApplicationRepository.hasApplied` (any error → `false`) ← `job_detail_screen.dart` · **Status:** Active

### GET `/applications/my`
- **Response:** `[ApplicationResponse]` = Application fields + `job {id, title, company, company_id, location, city_name, salary_min, …}` (+ `candidate`)
- **Flutter:** `ApplicationRepository.getMyApplications` (rethrows; last list shown **only when offline**, raw items cached) ← `myApplicationsProvider` ← `my_applications_screen.dart`, `application_detail_screen.dart`, `jobs_screen.dart`, `job_detail_screen.dart` · **Status:** Active
- Status values (backend comment): `Applied, Shortlisted, Interviewing, Rejected, Hired`.

### GET `/interviews/my`
- **Response:** `[{id, application_id, recruiter_id, candidate_id, scheduled_at, type, location, status, notes, created_at, updated_at, job{id,title,company}, candidate{…}, recruiter{id,name,…}}]`
- **Flutter:** `InterviewRepository.getMyInterviews` (rethrows) ← `myInterviewsProvider` ← `interviews_screen.dart` · **Status:** Active

## 6. Network (`network/api.go`, Required)

| Endpoint | Request | Response | Flutter |
|---|---|---|---|
| POST `/network/connect` | `{receiver_id}` | not verified | `NetworkRepository.sendInvitation` ← `peer_to_peer_screen.dart`, `application_detail_screen.dart` |
| POST `/network/accept` | `{sender_id}` | not verified | `acceptInvitation` ← `network_screen.dart`, `peer_to_peer_screen.dart` |
| POST `/network/ignore` | `{sender_id}` | not verified | `ignoreInvitation` ← `network_screen.dart` |
| GET `/network/pending` | — | `[ConnectionRequest {id, sender_id, receiver_id, status, created_at, updated_at}]` | `getPendingInvitations` → `pendingInvitationsProvider` |
| GET `/network/connections` | — | `[userId]` | `getConnections` → `connectionsProvider` |
| GET `/network/status/:id` | — | `{status}` (values not verified) | `getConnectionStatus` → `connectionStatusProvider` |
| DELETE `/network/connections/:id` | — | not verified | `deleteConnection` ← `network_screen.dart` |

Errors: 401, 500 with `error`. GET errors are rethrown (Batch 5). **Status:** Active.

## 7. Chat (`chat/api.go`, Required)

### GET `/chats`
- **Response:** `[Conversation {id, participants[], last_message_id, last_message, updated_at, created_at}]` (no unread counts, no names)
- **Flutter:** `ChatRepository.getConversations` (rethrows) ← `conversationsProvider` ← `chat_list_screen.dart` (guests see a login prompt, no call), `open_chat.dart` · **Status:** Active

### GET `/chats/:id/messages?limit=50&offset=0`
- **Response:** `[Message {id, conversation_id, sender_id, content, is_read, created_at}]`; 400 on invalid id
- **Flutter:** `ChatRepository.getMessages` (rethrows) ← `ChatMessagesNotifier` (error + `retryHistory`) · **Status:** Active

### POST `/chats/messages`
- **Request:** `{receiver_id, content}` · **Response:** 201 `Message` (creates the conversation if needed); also pushed over WebSocket to sender and receiver
- **Errors:** 400 `"Receiver ID is required"`, `"Message content is required"` · **Flutter:** `ChatRepository.sendMessage` ← `ChatMessagesNotifier.sendMessage` · **Status:** Active

### WebSocket `GET /api/ws/chats?token=<JWT>`
- **Auth:** JWT in query string (`controller.go` `ctx.Query("token")`)
- **Server → client:** `{"type":"NEW_MESSAGE","message": Message}`. Client → server messages: none used.
- **Flutter:** `ChatWebSocketService` (`chat/services/chat_websocket_service.dart`), status via `webSocketStatusStreamProvider`. Details in [architecture.md §12](architecture.md#12-websocket-architecture). · **Status:** Active

## 8. Events (`event/api.go`)

### GET `/events`
- **Auth:** Public · **Request:** `page, limit, search?, location?` (backend also `sort`) · **Response:** `{data:[Event], total, page, limit}`; Event `{id, title, organizer, description, date, time, location, image_url?, participants[], created_at}`
- **Flutter:** `EventRepository.getEvents` (derives `isRegistered` from `participants` + current user id) ← `eventsProvider` ← `events_screen.dart` · **Status:** Active

### POST `/events/:id/register`
- **Auth:** Required · **Response:** `{"message":"Successfully registered for event"}`; 500 text on failure
- **Flutter:** `EventRepository.registerForEvent` ← `EventsNotifier.registerForEvent` (optimistic) ← `event_detail_screen.dart` · **Status:** Active
- `GET /events/:id` (Public) — available, not integrated.

## 9. Experts / Mentorship (`mentorship/api.go`)

### GET `/mentorships?category=`
- **Auth:** Public · **Response:** `[{mentorship:{id, expert_id, title, description, category, duration, price, rating?, reviews?, status, …}, expert:{id, name, headline, profile_image, bio, rating}}]`
- **Flutter:** `ExpertRepository.getExperts` (search `query` filtered **client-side**) ← `expertProvider` ← `experts_screen.dart` · **Status:** Active

### GET `/mentorships/:id`
- **Auth:** Public · **Response:** same `{mentorship, expert}` detail; 404 `"Mentorship not found"` · **Flutter:** `ExpertRepository.getExpertById` exists but has **no caller** (the detail screen receives the list item). · **Status:** Available, not integrated

### POST `/mentorships/book` (free) · POST `/mentorships/book-wallet` · POST `/mentorships/create-order` · POST `/mentorships/verify-payment`
- **Auth:** Required
- **Request (book / book-wallet / create-order):** `{mentorship_id, scheduled_at (RFC3339 with timezone; app sends UTC "…Z"), notes?}`
- **Responses:** book → 201 `Booking`; book-wallet → `{message, booking, wallet: WalletSummary}`; create-order → `{booking_id, order_id, amount, amount_paise, currency, key_id}`; verify-payment request `{booking_id, razorpay_order_id, razorpay_payment_id, razorpay_signature}` → `{message, booking}`
- **Errors:** 400 text (e.g. `"insufficient wallet balance: required ₹…"`), 500 for `/book`
- **Flutter:** `ExpertRepository.bookSession/bookWithWallet/createBookingOrder/verifyBookingPayment` ← `expert_detail_screen.dart` (price ≤ 0 → `/book`; wallet or Razorpay otherwise) + `RazorpayCheckout.pay` · **Status:** Active (Razorpay TEST mode not verified)

### GET `/mentorships/bookings/my`
- **Auth:** Required · **Response:** `[Booking]` (Go `null` = none): `{id, mentorship_id, expert_id, user_id, scheduled_at, status:"pending"|"confirmed"|"cancelled"|"completed", amount, payment_status:"pending"|"paid"|"refunded", payment_method?:"wallet"|"razorpay", meeting_link?, notes?, …, mentorship_title?, expert_name?, expert_headline?, expert_image?}` (`mentorship/domain.go` `Booking`, enriched in `service.go`).
- **Flutter:** `ExpertRepository.getMyBookings` (newest first) → `BookingItem` (`experts/models/booking.dart`) ← `myBookingsProvider` (autoDispose) ← `my_sessions_screen.dart` (route `/my-sessions`). Join button only for `confirmed` with a `meeting_link`. · **Status:** Active (Batch 7c)
- `GET /mentorships/expert/:expert_id/availability` — available, not integrated.

## 10. Skills Marketplace (`skill/api.go`, Public)

- **GET `/skills?q=&category=`** → `[Skill {id, name, category?, created_at, updated_at}]` · **GET `/skills/categories`** → `[string]`
- **Flutter:** `SkillsRepository.getSkills/getCategories` ← `skillsProvider` ← `skills_marketplace_screen.dart` · **Status:** Active

## 11. Wallet (`wallet/api.go`, Required)

### GET `/wallet/balance` (alias `/wallet/summary`)
- **Response:** `WalletSummaryResponse {wallet_id, user_id, total_balance, withdrawable_balance, main_balance, earnings_balance, locked_balance, bonus_balance, currency, status, updated_at}`
- **Flutter:** `WalletRepository.getSummary` ← `walletProvider` ← wallet screens, `profile_screen.dart` · **Status:** Active

### GET `/wallet/transactions?page&limit`
- **Response:** `{transactions:[{id, wallet_id, type:"credit"|"debit", target_balance, category, amount, balance_after, status, reference_id?, description, metadata?, created_at}], total, page, limit, total_pages}`. Backend also filters by `type`, `category`, `target_balance`. App requests `limit=50` (backend default 20).
- **Flutter:** `WalletRepository.getTransactions` ← `walletProvider` · **Status:** Active

### POST `/wallet/topup/create-order` → Razorpay → POST `/wallet/topup/verify`
- **create-order request:** `{amount}` (INR; ₹10 – ₹1,00,000) → `{order_id, amount, amount_paise, currency, key_id}`
- **verify request:** `{razorpay_order_id, razorpay_payment_id, razorpay_signature, amount}` → `{message, wallet, transaction}`
- **Errors:** 400 `"minimum recharge amount is ₹10"`, `"maximum recharge amount is ₹1,00,000"`, signature errors
- **Flutter:** `WalletRepository.createTopupOrder/verifyTopup` ← `WalletNotifier.addMoney` ← `wallet_add_money_screen.dart`; app always sends the **server order amount** (backend credits client amount — B-02). · **Status:** Active

### POST `/wallet/withdraw`
- **Request:** `WithdrawalRequest {amount (₹50–₹5,00,000), payout_method:"upi"|"bank", account_holder, account_number, ifsc_code, bank_name, upi_id, phone_number}`. Backend requires `account_number` + `ifsc_code` for `bank` and a valid `upi_id` for `upi` (`wallet/service.go`); the app also asks for `account_holder`; `bank_name` and `phone_number` are optional → `{transaction, wallet, message}`; 400 `error` text on validation. Withdraws from earnings. **No idempotency key** (B-06).
- **Flutter:** `WithdrawalRequest.upi/.bank` (`wallet/models/withdrawal.dart`) → `WalletRepository.requestWithdrawal` → `WithdrawalResult` ← `WalletNotifier.withdraw` ← `wallet_withdraw_screen.dart` (min ₹50, confirmation sheet). 404 → coming soon; timeout/5xx → `isOutcomeUnknown` ("check transactions before retrying"); 401 stays an auth error. · **Status:** Active (Batch 2; no real payout made in testing)

### POST `/wallet/transfer`
- No backend route → 404 → `WalletApiException(isBackendPending)` → "coming soon". · **Status:** Backend unavailable

## 12. Notifications

### GET `/notifications`
- No backend route (no notification feature in `km-backend/internal/features`) → 404 → `notificationsProvider` "Notifications are coming soon". App parses `{notifications:[…]}` or `[…]` — **response shape not verified — do not assume.** · **Status:** Backend unavailable

## 13. Declared in `ApiConstants` but not used

`userBookmarks`, `userSettings` (GET), `posts`, `feed` (no backend routes), `adminCompanies` (admin route, out of scope), `mentorship` (duplicate).

## 14. Backend endpoints relevant to mobile, not integrated

`GET /user/viewers` (**do not integrate** — returns private user fields, B-08), `PATCH /user/username`, `GET /user/username/check`, `GET /settings/me`, `PUT /settings/me`, `GET /events/:id`, `GET /mentorships/expert/:expert_id/availability`, `GET /companies/top`, `GET /companies`, `GET /questions`, `GET /platform/stats`, `GET /platform/live-activity`, `GET /files/download/:id`. Response shapes of these were **not verified** in this audit unless stated above.

Out of mobile scope (do not integrate without an explicit request): `/admin/*`, `POST/PATCH/DELETE /jobs`, `/jobs/my`, `/applications/job/:jobId`, `/applications/recruiter/all`, `PATCH /applications/:id/status`, `POST /interviews`, mentorship expert management routes, `/cities` mutations, `/skills` mutations, `/sms/send`, `POST /settings/:key`.

## Known Mismatches

| # | Flutter | Backend (`b5a2956`) | Impact | Ref |
|---|---|---|---|---|
| 1 | ~~Withdraw body `{destination_type, destination_detail}`~~ | `WithdrawalRequest` | **Fixed (Batch 2)** | C-02 |
| 2 | ~~New OTP user → `POST /auth/register/password`~~ | `POST /user/register` | **Fixed (Batch 1)** | C-01 |
| 3 | ~~Open To / Providing services saved on device~~ | `PATCH /user/open-to-work`, `/user/providing-services` | **Implemented (7d), awaiting verification** | M-06 |
| 4 | ~~Education/experience/skills add-only~~ | PUT/DELETE | **Fixed (7a, 7b)**; multi-word skill delete fails on backend | M-06, B-07 |
| 5 | Reads bookmarks/settings from `/user/profile` | `GET /user/bookmarks`, `/user/settings` shadowed by `/user/:id` (500) | Workaround OK; full saved-jobs list impossible | B-01, H-06 |
| 6 | Instant Work `job_types=Instant,Hourly,Gig,Part-time` | Only `Full-time/Part-time/Internship/Freelance/Contract` seen in backend/website | Likely only Part-time results | M-01 |
| 7 | ~~`UserProfile` read `profile_views_count` etc.~~ | `profile_views`, `post_impressions`, `search_appearances` | **Fixed** | — |
| 8 | `UserProfile.publicProfileUrl` `/in/{id}` | Website route `/profile/[Id]` | Broken shared link | M-05 |
