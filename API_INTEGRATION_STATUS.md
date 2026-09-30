# KaamMilega — Flutter App & Backend API Integration Status

> **Last verified:** **30 September 2026**, against the `KaamMilega` monorepo `main` @ **`5e57311`** (`km-backend/`, read-only; the backend is developed separately and is not edited from this repository). App: branch `feat/map-location-integration` @ `0fa522f` + uncommitted work.
> Field-level details: [API_CONTRACT.md](API_CONTRACT.md). Backend bugs with IDs: [KNOWN_ISSUES.md § API/Backend Issues](KNOWN_ISSUES.md#apibackend-issues).
>
> The Flutter app talks to the Go backend (`km-backend`) at `ApiConstants.baseUrl` (`https://api.kaammilega.com/api`). All paths below are relative to `/api`. Every path used by the app is declared in `lib/core/constants/api_constants.dart`.

---

## 1. Rules the app follows

1. **No fake data, no fake success.** If the backend does not support something yet, the app says "coming soon". It never shows invented records, ratings or counts, and never says "saved / sent / paid" unless the server confirmed it.
2. **Error types**
   - `HTTP 404` → feature not live yet → friendly "coming soon" state (not an empty list).
   - `HTTP 401 / 403` → session expired / not allowed.
   - `HTTP 500+` → temporary server problem, with Retry.
   - Network / timeout → offline banner, cached data where available, auto-retry on reconnect.
   - `HTTP 200` with `[]` → normal empty state.
3. **Match the backend exactly.** Field names and request types in the app follow the backend `domain.go` models.
4. **Payments are credited only by the server.** The app opens Razorpay checkout (`lib/core/payments/razorpay_checkout.dart`) and then sends the payment ID, order ID and signature to the backend "verify" endpoint. Nothing is shown as paid until the server confirms it. Times are sent in UTC (`...Z`).

---

## 2. Live on the backend and connected in the app

| Feature | Method & path | Where in the app |
| :--- | :--- | :--- |
| Send / verify phone OTP | `POST /auth/otp/send`, `POST /auth/otp/verify` | Login, OTP screens |
| Email + password login / register | `POST /auth/login/password`, `POST /auth/register/password` | Login, Register |
| Forgot / reset password | `POST /auth/password/forgot`, `POST /auth/password/reset` | Forgot Password |
| Email OTP | `POST /auth/otp/email/send`, `POST /auth/otp/email/verify` | Profile → verify email |
| Complete registration (new OTP user) | `POST /user/register` | Complete Profile screen |
| My profile | `GET /user/profile`, `PATCH /user/profile` | Profile, Settings |
| Change password | `PUT /user/password` | Settings → Password |
| Account settings | read from `GET /user/profile` (`settings`), save `PUT /user/settings` | Settings |
| Education / experience | `POST`, `PUT /:id`, `DELETE /:id` on `/user/education`, `/user/experience` | Profile |
| Projects | `POST /user/project`, `PUT /user/project/:id`, `DELETE /user/project/:id` | Profile → Projects |
| Skills | `POST /user/skill`, `DELETE /user/skill/:skillName` | Profile → Skills |
| Open To Work / Providing Services | `PATCH /user/open-to-work`, `PATCH /user/providing-services` | Profile → Open To sheets |
| Custom profile URL | `PATCH /user/username`, `GET /user/username/check` | Profile |
| Profile analytics | counters in `GET /user/profile`; `POST /user/impressions` | Profile analytics card, impression tracking |
| Profile viewers | `GET /user/viewers` | Profile Viewers screen |
| Apply as Expert | `POST /user/apply-expert` | Apply as Expert |
| Pro Expert subscription | `GET /subscriptions/expert/plans`, `GET /subscriptions/expert/my`, create-order → Razorpay → verify, or wallet-checkout | Apply as Expert → Pro Expert plans |
| Saved jobs | toggle `POST /user/bookmark/:jobId`; each saved job `GET /jobs/:id` | Jobs, Saved Jobs |
| Other user's profile | `GET /user/:id` | Member profile, chat names & photos |
| Search people / suggestions | `GET /user/search?q=`, `GET /community/users`, `GET /experts` | Peer-to-Peer, People You May Know, Home |
| File upload | `POST /files/upload` | Profile photo, cover, resume |
| Jobs list / detail | `GET /jobs`, `GET /jobs/:id` | Home, Jobs, Job Detail |
| Top companies | `GET /companies/top` | Home → featured companies |
| Cities | `GET /cities` | City selector, filters |
| Apply to a job | `POST /applications` (with `resume_url` when a resume was uploaded) | Apply sheet |
| Already applied? | `GET /applications/check/:jobId` | Job Detail |
| My applications / interviews | `GET /applications/my`, `GET /interviews/my` | My Applications, Interviews |
| Network | `POST /network/connect`, `/accept`, `/ignore`; `GET /network/pending`, `/connections`, `/status/:id`; `DELETE /network/connections/:id` | Network, Peer-to-Peer, member profile |
| Chat | `GET /chats`, `GET /chats/:id/messages?limit&offset` (paged — oldest first), `POST /chats/messages`, WebSocket `/ws/chats?token=` (`NEW_MESSAGE` events) | Chats |
| Events | `GET /events`, `POST /events/:id/register` | Events |
| Paid event tickets | `POST /events/:id/create-order` → Razorpay → `POST /events/:id/verify-payment`; `POST /events/:id/wallet-checkout`; `GET /events/my/tickets` | Event detail, My Tickets |
| Experts / mentorship | `GET /mentorships`, `GET /mentorships/:id`, `POST /mentorships/book` | Experts |
| Paid session | `POST /mentorships/book-wallet`, or `POST /mentorships/create-order` → Razorpay → `POST /mentorships/verify-payment` | Expert detail |
| My booked sessions + review | `GET /mentorships/bookings/my`, `POST /mentorships/bookings/:id/review` | My Booked Sessions, upcoming-call banner |
| Instant Milega (gig worker) | `GET /instant-work/candidate/status`, `POST /instant-work/availability`, `POST /instant-work/location`, `GET /instant-work/candidate/feed`, `POST /instant-work/claim`, `GET /instant-work/candidate/active-job`, `PUT /instant-work/jobs/:id/complete`, `POST /instant-work/pass/pay-wallet` | Instant Milega page |
| Wallet balances | `GET /wallet/balance` | Wallet, Add Money, Withdraw, Profile |
| Wallet transactions | `GET /wallet/transactions?page&limit&category` | Wallet, Transactions |
| Add money | `POST /wallet/topup/create-order` → Razorpay → `POST /wallet/topup/verify` | Add Money |
| Withdraw request | `POST /wallet/withdraw` (`payout_method` `upi`/`bank`) | Withdraw |
| Refunds & disputes | `POST /wallet/disputes`, `GET /wallet/my/disputes` | Transaction row → Dispute / Refund |
| Skills catalog | `GET /skills`, `GET /skills/categories` | Skills Marketplace |

---

## 3. Available on the backend, not used by the app yet

| Path | Note |
| :--- | :--- |
| `GET /events/:id/attendees` | Attendee list (F64). Verify the fields before using. |
| `GET /events/:id`, `GET /events/:id/ticket` | Single event / single ticket (the app uses the list and My Tickets). |
| `POST /instant-work/pass/order`, `POST /instant-work/pass/verify` | InstantPass by Razorpay — app flow built 30 Sep, switched off (`InstantPassTerms.onlinePaymentLive`) until the backend double debit B-12 is fixed. |
| `POST/GET /auth/logout` | Clears the website cookie; app logout is local. |
| `GET /settings/me`, `GET /platform/stats`, `GET /platform/live-activity` | Not needed by the app so far. |
| Recruiter/admin routes (`/instant-work/dispatch`, `/recruiter/*`, `/jobs/:id/close`, `/admin/*`) | Out of scope — the app is for candidates and gig workers. |

---

## 4. Known backend issues (app works around them)

| Issue | App workaround |
| :--- | :--- |
| `GET /user/:id` registered before `GET /user/bookmarks` / `GET /user/settings` → **500** (B-01) | Reads `bookmarked_jobs` and `settings` from `GET /user/profile`. |
| No `resume` field on the user profile | Resume link kept on the device and attached to each application (`resume_url`). |
| Recruiter phone numbers not shared on normal jobs | "Call" says coming soon and points to Chat. |
| `POST /wallet/topup/verify` credits the client-sent `amount` (B-02) | App sends the server order amount. |
| `POST /mentorships/book-wallet` charges ₹100 when price is ₹0 (B-03) | ₹0 sessions booked with `POST /mentorships/book`. |
| `/community/users`, `/experts`, `/user/viewers` return private fields (B-04, B-08) | App shows public fields only; backend should strip the rest. |
| Chat hub keeps one socket per user; history is oldest-first (B-11) | One socket, ping, reconnect, history paging. |
| InstantPass / spot-gig money bugs (B-12) | Wallet-only pass purchase. |
| `POST /wallet/withdraw` has no idempotency key and no automatic payout (B-06, B-16) | Timeout/5xx shown as "outcome unknown, check transactions first". |
| Uploaded files lost when the server container is rebuilt (B-15) | Initials / gradient fallback when an image fails. |
| Secrets committed in `km-backend/docker-compose.yml` (B-14) | Backend owner must rotate. |

---

## 5. Not built on the backend yet (app shows "coming soon")

| Feature | Planned path | App behaviour today |
| :--- | :--- | :--- |
| In-app notifications | `GET /notifications` (404) | "Notifications are coming soon" with Retry (backend only sends e-mails) |
| Wallet transfer | `/wallet/transfer` | "Coming soon, nothing sent" |
| Home ₹99 Access banner | — | "Coming soon, you have not been charged" (InstantPass itself is live, see §2) |
| Nearby professionals (Instant Milega) | — | "Coming soon" section |
| Services marketplace | `/services` | "Services Marketplace is coming soon" |
| Feed / resources | `/posts`, `/feed` | "Career resources are coming soon" |
| Chat unread counts | — | Badge not shown |
| Push notifications (FCM) | — | Not implemented |
| Bank verification / automatic payouts | — | Withdrawals are requests processed by the team |

---

## 6. Adding a new endpoint

1. Declare the path in `lib/core/constants/api_constants.dart` (without the `/api` prefix, `baseUrl` already has it).
2. Call it through `ApiClient` (`get`, `post`, `put`, `patch`, `delete`) from a repository.
3. Check the backend `domain.go` for exact field names and `api.go` for the method and route order.
4. Handle `AppNotFoundException` (404) as "coming soon", never as fake data.
5. Update this file.
