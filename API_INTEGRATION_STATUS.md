# KaamMilega — Flutter App & Backend API Integration Status

> **Last verified:** 23 September 2026, against `km-backend` on GitHub `main` (commit 93461d1) (reference only; the backend is developed separately and is not edited from this repository).
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
| Complete registration | `POST /user/register` | Register (profile setup) |
| My profile | `GET /user/profile`, `PATCH /user/profile` | Profile, Settings |
| Change password | `PUT /user/password` | Settings → Password |
| Account settings | read from `GET /user/profile` (`settings`), save `PUT /user/settings` | Settings |
| Education / experience (add only) | `POST /user/education`, `POST /user/experience` | Profile |
| Projects | `POST /user/project`, `PUT /user/project/:id`, `DELETE /user/project/:id` | Profile → Projects |
| Skills | `POST /user/skill` | Profile → Skills |
| Apply as Expert | `POST /user/apply-expert` | Apply as Expert |
| Saved jobs | toggle `POST /user/bookmark/:jobId`, list from `GET /user/profile` (`bookmarked_jobs`) | Jobs, Saved Jobs |
| Other user's profile | `GET /user/:id` | Chat names & photos |
| Search people | `GET /user/search?q=` | Peer-to-Peer |
| File upload | `POST /files/upload` | Profile photo, cover, resume |
| Jobs list / detail | `GET /jobs`, `GET /jobs/:id` | Home, Jobs, Job Detail, Instant Work |
| Cities | `GET /cities` | City selector, filters |
| Apply to a job | `POST /applications` (with `resume_url` when a resume was uploaded) | Apply sheet |
| Already applied? | `GET /applications/check/:jobId` | Job Detail |
| My applications | `GET /applications/my` | My Applications |
| My interviews | `GET /interviews/my` | Interviews |
| Network | `POST /network/connect`, `/accept`, `/ignore`; `GET /network/pending`, `/connections`, `/status/:id`; `DELETE /network/connections/:id` | Network, Application Detail, Peer-to-Peer |
| Chat | `GET /chats`, `GET /chats/:id/messages`, `POST /chats/messages`, WebSocket `/ws/chats?token=` | Chats |
| Events | `GET /events`, `POST /events/:id/register` | Events |
| Experts / mentorship (free session) | `GET /mentorships`, `GET /mentorships/:id`, `POST /mentorships/book` | Experts |
| Paid session from wallet | `POST /mentorships/book-wallet` | Expert detail → Pay from Wallet |
| Paid session online | `POST /mentorships/create-order` → Razorpay checkout → `POST /mentorships/verify-payment` | Expert detail → Pay online |
| Wallet balances | `GET /wallet/balance` | Wallet, Add Money, Withdraw, Transfer, Profile |
| Wallet transactions | `GET /wallet/transactions?page&limit` (response key `transactions`) | Wallet, Transactions |
| Add money | `POST /wallet/topup/create-order` → Razorpay checkout → `POST /wallet/topup/verify` | Add Money |
| Skills catalog | `GET /skills`, `GET /skills/categories` | Skills Marketplace |

---

## 3. Known backend issues (app works around them)

| Issue | Effect | App workaround |
| :--- | :--- | :--- |
| `GET /user/:id` is registered before `GET /user/bookmarks` and `GET /user/settings` in `internal/features/user/api.go` | Both return **HTTP 500** ("bookmarks"/"settings" treated as a user ID) | App reads `bookmarked_jobs` and `settings` from `GET /user/profile`. Fix on backend: register `/:id` last. |
| No update/delete endpoints for education and experience | Can only add | Edit buttons removed; the app never re-sends an existing entry (that created duplicates). |
| No `resume` field on the user profile | Resume link can't be saved to profile | Resume link kept on the device and attached to every job application (`resume_url`). |
| `PATCH /user/profile` ignores `open_to_work`, `providing_services`, `is_available_for_gigs` | Values would be lost | Kept on the device; the app says "saved on this device". |
| Recruiter phone numbers are not shared with candidates | Nothing to dial | "Call" buttons say calling is coming soon and point to Chat. |
| `POST /wallet/topup/verify` credits the `amount` sent by the client, not the Razorpay order amount | A modified client could claim more than it paid | App always sends the server's order amount. **Backend must read the amount from the Razorpay order.** |
| `POST /mentorships/book-wallet` charges ₹100 when a session price is ₹0 | Free sessions could be charged | App books ₹0 sessions with `POST /mentorships/book` only. |
| `GET /api/community/users` and `GET /api/experts` are public and return full user records | Privacy (mobile, email, address, DOB) | App does not use them. Backend should return public fields only. |

---

## 4. Not built on the backend yet (app shows "coming soon")

| Feature | Planned path | App behaviour today |
| :--- | :--- | :--- |
| Notifications | `GET /notifications` | "Notifications are coming soon" with Retry |
| Wallet withdraw / transfer | `/wallet/withdraw`, `/wallet/transfer` | "Coming soon, nothing sent" (balances and top-up are live) |
| ₹99 access pass, paid events | — | "₹99 Access is coming soon, you have not been charged" |
| Instant Work dispatch / requests | — | Instant Work lists real hourly/gig jobs; "Instant Work request" says coming soon |
| Services marketplace | `/services` | "Services Marketplace is coming soon" |
| Feed / resources | `/posts`, `/feed` | "Career resources are coming soon" |
| Profile viewers / people suggestions | — | "Coming soon" card |
| Push notifications (FCM) | — | Not implemented in the app yet |

---

## 5. Adding a new endpoint

1. Declare the path in `lib/core/constants/api_constants.dart` (without the `/api` prefix, `baseUrl` already has it).
2. Call it through `ApiClient` (`get`, `post`, `put`, `patch`, `delete`) from a repository.
3. Check the backend `domain.go` for exact field names and `api.go` for the method and route order.
4. Handle `AppNotFoundException` (404) as "coming soon", never as fake data.
5. Update this file.
