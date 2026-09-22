# KaamMilega — Flutter App & Backend API Integration Status

> **Context**: The KaamMilega Flutter mobile application connects to the Go (`km-backend`) REST & WebSocket service.
> Since `km-backend` is under active development, this document tracks all endpoints, their implementation status in Flutter, and their current backend availability.

---

## 1. API Architecture & Resilience Rules

1. **No Fake / Mock Production Data**: The Flutter application does **not** inject hardcoded fake datasets to disguise unimplemented backend routes.
2. **Distinct Failure Classification**:
   - `HTTP 404 (Not Found)`: Treated strictly as *Service/Endpoint Unavailable (Under Development)* — NOT as an empty list (`[]`). Displays clean, user-friendly unavailable cards with retry options.
   - `HTTP 401 / 403`: Session expiry / Unauthorized authentication errors.
   - `HTTP 500+`: Server internal error / temporary unavailability.
   - `Network / Timeout / SocketException`: Triggers offline banner, cached local data fallback, and auto-retry upon reconnection.
   - `HTTP 200 with []`: Rendered as normal empty data state (e.g., "0 applied jobs", "No new notifications").
3. **Structured Single-Line Developer Logs**:
   - Console logs print concise, structured entries such as: `[ApiClient] HTTP 404 | GET /api/skills - Backend endpoint unavailable` rather than dumping verbose multi-line Dio stack traces.

---

## 2. Endpoint Integration Matrix

| Feature / Domain | Method | Endpoint | Flutter Status | km-backend Status | Flutter Error / Fallback Behavior |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Auth — OTP Send** | `POST` | `/api/auth/otp/send` | ✅ Implemented | 🟢 Active | Displays validation / network error snackbar |
| **Auth — OTP Verify** | `POST` | `/api/auth/otp/verify` | ✅ Implemented | 🟢 Active | Session saved securely in `LocalStorage` |
| **Auth — Password Login** | `POST` | `/api/auth/login/password` | ✅ Implemented | 🟢 Active | Session saved securely in `LocalStorage` |
| **Auth — Register** | `POST` | `/api/auth/register/password` | ✅ Implemented | 🟢 Active | Creates account & authenticates session |
| **User Profile** | `GET` | `/api/user/profile` | ✅ Implemented | 🟢 Active | Cached in `LocalStorage` for offline resume |
| **User Profile Update** | `PUT` | `/api/user/profile` | ✅ Implemented | 🟢 Active | Network write, validates active connection |
| **User Skills** | `POST/DEL`| `/api/user/skill` | ✅ Implemented | 🟢 Active | Updates user candidate profile skills |
| **Jobs Listing** | `GET` | `/api/jobs` | ✅ Implemented | 🟢 Active | Cached locally; supports filters, pagination |
| **Job Details** | `GET` | `/api/jobs/:id` | ✅ Implemented | 🟢 Active | Guest/Auth view with retry state |
| **Submit Application** | `POST` | `/api/applications` | ✅ Implemented | 🟢 Active | Strictly requires active connection; double-tap guarded |
| **My Applications** | `GET` | `/api/applications/my` | ✅ Implemented | 🟢 Active | Cached locally; shows timestamp badge offline |
| **Scheduled Interviews** | `GET` | `/api/interviews/my` | ✅ Implemented | 🟢 Active | Displays candidate interview cards |
| **Network Connections** | `GET` | `/api/network/connections` | ✅ Implemented | 🟢 Active | Shows confirmed peers & contact options |
| **Pending Requests** | `GET` | `/api/network/pending` | ✅ Implemented | 🟢 Active | Accept/Ignore connection invites |
| **Send Invite** | `POST` | `/api/network/connect` | ✅ Implemented | 🟢 Active | Sends peer invite with snackbar feedback |
| **Chats Listing** | `GET` | `/api/chats` | ✅ Implemented | 🟢 Active | Lists conversation threads |
| **Chat Messages** | `GET` | `/api/chats/:id` | ✅ Implemented | 🟢 Active | Loads thread history |
| **Realtime Chat** | `WS` | `/api/ws/chats` | ✅ Implemented | 🟢 Active | WebSocket duplex messaging |
| **Notifications** | `GET` | `/api/notifications` | ✅ Implemented | 🟡 *Pending / 404* | Shows "Notifications service under development" with retry |
| **Skills Catalog** | `GET` | `/api/skills` | ✅ Implemented | 🟡 *Pending / 404* | Shows "Skills catalog unavailable" with retry |
| **Skills Categories** | `GET` | `/api/skills/categories` | ✅ Implemented | 🟡 *Pending / 404* | Shows "Skills catalog unavailable" with retry |
| **User Peer Search** | `GET` | `/api/users/search` | ✅ Implemented | 🟡 *Pending / 404* | Shows "User discovery unavailable" with retry |
| **Events & Webinars** | `GET` | `/api/events` | ✅ Implemented | 🟡 *Pending / 404* | Shows clean retry view if unmounted |
| **Mentorship Experts** | `GET` | `/api/mentorships` | ✅ Implemented | 🟡 *Pending / 404* | Shows clean retry view if unmounted |
| **Cities** | `GET` | `/api/cities` | ✅ Implemented | 🟢 Active | Populates city dropdowns & filters |

---

## 3. Developer Guidance for New Endpoints

When implementing a new feature in the Flutter app:
1. Always declare routes in `lib/core/constants/api_constants.dart`.
2. Do **not** prepend `/api` to route paths in repositories since `ApiConstants.baseUrl` already contains `/api`.
3. Wrap network calls with `ApiClient` (`get`, `post`, `put`, `delete`).
4. Catch `AppException` subtypes in Riverpod Notifiers/Providers and let `NetworkStateView` render the appropriate error / offline / retry UI.
5. Never hardcode fake production datasets as silent error fallbacks.
