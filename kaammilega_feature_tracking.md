# KaamMilega — Feature Implementation & Tracking Report

> **Google Sheets CSV Export Available**: You can import [kaammilega_feature_tracking.csv](file:///C:/Users/QUIKCARE%20COMPUTERS/.gemini/antigravity/brain/aedc753b-ac31-4e60-be61-806807f28ced/kaammilega_feature_tracking.csv) directly into Google Sheets or Microsoft Excel for interactive tracking.

---

## 📊 Summary Dashboard

| Status Category | Feature Count | Description |
| :--- | :---: | :--- |
| ✅ **Flutter Mobile App: Fully Implemented** | **22** | Core Candidate Auth, Profile, CV, Job Search, Filters, Apply, Applications, Interviews, Network, & Real-Time Chat |
| 🌐 **Web-Only / Excluded from Mobile** | **31** | Employer, Recruiter & Admin Dashboards (Web Portal Scope) |
| ⏳ **Pending Tasks / Recommended App Enhancements** | **25** | Profile strength bar, bookmarking, expert booking, event directory, push notifications, media sharing |
| 🚀 **Future Growth / Payment & Wallet Verticals** | **20** | Razorpay payment gate, InstantMilega 30s GPS radar, WebRTC calling, Services marketplace |
| **Total Tracked Features** | **98** | **F01 to F98** |

---

## 🟢 1. Fully Implemented Features in Flutter Mobile App

| Code | Feature Name | Target | Flutter Mobile Implementation Status |
| :--- | :--- | :--- | :--- |
| **F01** | Candidate Registration - OTP Phone Verification | Candidate | `LoginScreen` & `OtpScreen` calling `POST /auth/otp/send` & `/auth/otp/verify` |
| **F02** | Candidate Registration - Email & Profile Setup | Candidate | `RegisterScreen` calling `POST /user/register` |
| **F04** | User Login - OTP-Based Phone Login | All Users | OTP login flow storing JWT in `LocalStorage` (SharedPreferences) |
| **F06** | Passwordless Auth & Recovery Flow | All Users | Passwordless OTP login handles authentication & recovery natively |
| **F07** | JWT Middleware & Token Injection | Platform | Dio `ApiClient` interceptor attaches Authorization Bearer token to all requests |
| **F08** | SMS OTP Integration | Platform | Backend `sms/service.go` dispatches SMS OTPs |
| **F09** | File & Media Upload Service | Platform | Backend `POST /api/files/upload` serves media and document uploads |
| **F10** | Personal & Professional Profile Info | Candidate | `ProfileScreen` displays & updates bio, headline, city via `PATCH /user/profile` |
| **F11** | Education History Management | Candidate | `ProfileScreen` Add Education modal appending via `POST /user/education` |
| **F12** | Work Experience Management | Candidate | `ProfileScreen` Add Experience modal appending via `POST /user/experience` |
| **F13** | Skills Tagging & Catalog Selection | Candidate | `ProfileScreen` Add Skill modal searching catalog via `POST /user/skill` |
| **F14** | Profile Photo Upload & Avatar | Candidate | Avatar display with network image URL and fallback initials placeholder |
| **F15** | Resume View & Download | Candidate | Profile loads resume URL; opens via `url_launcher` |
| **F21** | Job Search & Discovery Engine | Candidate | `HomeScreen` & `JobsScreen` with typing debouncer (400ms) & `GET /api/jobs` |
| **F22** | Multi-Select Category & City Filters | Candidate | `FilterModalSheet` & `CitySelectorSheet` for City, Job Type, Salary, Exp, Edu |
| **F23** | Job Detail View & 1-Click Apply | Candidate | `JobDetailScreen` & `ApplyModalSheet` with duplicate application prevention |
| **F25** | My Applications Dashboard | Candidate | `MyApplicationsScreen` fetching `GET /applications/my` with status chips |
| **F29** | Interview Calendar & Schedule | Candidate | `InterviewsScreen` fetching `GET /interviews/my` with mode, date, time, location |
| **F39** | Skill Profile Showcase | Candidate | Master catalog skill chips rendered on profile |
| **F54** | Network Connections & Invitations Hub | All Users | `NetworkScreen` with Active Connections & Pending Invitations (Accept/Ignore/Connect) |
| **F56** | Real-Time Chat Conversation List | All Users | `ChatListScreen` fetching `GET /api/chats` with unread indicators & timestamps |
| **F57** | Instant Message WebSocket Delivery | All Users | `ChatWebSocketService` connecting to `ws://.../api/ws/chats` with auto-reconnect |
| **F92** | Platform WebSocket Engine | Platform | Backend WebSocket hub delivering messages to Flutter app |
| **F97** | Native Android Application | Mobile Users | Flutter cross-platform architecture targeting Android SDK |
| **F98** | Native iOS Application | Mobile Users | Flutter cross-platform architecture targeting iOS SDK |

---

## ⏳ 2. Pending Tasks & Recommended Next Steps for Flutter App

Here is the exact list of candidate-facing features that can be added to the Flutter mobile app in upcoming phases:

### Phase 2 Profile Enhancements
1. **F16 Candidate Profile Strength Bar**: Add a dynamic % calculation card on `ProfileScreen` (e.g. 80% complete: missing resume / education).
2. **F17 Candidate Portfolio & Projects**: Add a portfolio projects list widget and creation dialog on `ProfileScreen`.

### Phase 3 Job Enhancements
3. **F24 Save / Bookmark Jobs**: Add a bookmark icon on `JobCard` and a "Saved Jobs" tab using local storage or backend persistence.

### Phase 4 & 5 Gig & Expert Features
4. **F30 InstantMilega "Free Now" Toggle**: Add an Online/Offline availability switch on `HomeScreen` header for gig workers.
5. **F31 Real-Time GPS Location Updates**: Integrate `geolocator` plugin for periodic location updates when active.
6. **F35 Real-Time Gig Dispatch Card**: Build a 60-second countdown alert sheet when a new gig dispatch WebSocket event arrives.
7. **F41 Skill Certifications & Badges**: Add a certifications showcase section on `ProfileScreen`.
8. **F42 Become an Expert Application Form**: Add an "Apply as Expert" modal calling `POST /user/apply-expert`.
9. **F43 Verified Expert Public Directory**: Add an Experts directory screen in Flutter app querying `GET /admin/users` (role=expert).
10. **F44 Book Expert Mentorship Session**: Add a mentorship booking bottom sheet calling `POST /mentorships`.
11. **F45 Expert Session Ratings & Reviews**: Add a rating dialog for completed mentorship sessions.

### Phase 7 Social & Chat Enhancements
12. **F51 Social Feed Screen**: Add a community discussion feed screen displaying posts and creating text/media posts.
13. **F55 Suggested Connections Carousel**: Add "People You May Know" horizontal card list in `NetworkScreen`.
14. **F58 Chat File & Media Attachments**: Add an image/file attachment button in `ChatDetailScreen` calling `/api/files/upload`.
15. **F59 Chat Block & Report Action**: Add a menu action to block user or report conversation in `ChatDetailScreen`.

### Phase 8 & 9 Community & Notifications
16. **F61 Public Events Directory**: Add an Events list screen querying `GET /api/events`.
17. **F62 One-Click Event Registration**: Add a "Register for Event" button calling `POST /events/:id/register`.
18. **F65 Push Notifications (FCM / OneSignal)**: Integrate `firebase_messaging` plugin for system-wide push notifications.
19. **F93 Settings & Account Preferences**: Add a Settings screen for notification toggles and app theme.

### Phase 10 Payment Gateway Integration (Razorpay)
20. **F68-F76 Wallet Ledger & Razorpay Checkout**: Integrate `razorpay_flutter` plugin for paid event tickets, expert bookings, and platform wallet top-ups.

---

## 🌐 3. Web Portal Features (Out of Mobile Scope)

The following features belong strictly to the **Recruiter / Employer** and **Admin** web dashboards and are excluded from the candidate mobile app by architectural design:
- **Recruiter Features**: F03 (Company Reg), F18 (Post Job), F19 (Manage Jobs), F20 (AI Job Generator), F26 (View Applicants), F27 (Kanban Board), F28 (Schedule Interview), F33 (Employer Spot Hire), F34 (Employer Radar Map), F60 (Create Events), F89 (Self-Serve Ads).
- **Admin Panel Features**: F77 (Admin Metrics), F78 (User Control), F79 (Company Verification), F80 (Expert Approvals), F81 (Job Moderation), F82 (Ads Campaign), F83 (City Mgmt), F84 (Skill Catalog), F85 (Learn Videos), F86 (Policies), F87 (Question Bank), F88 (Job-City Mapping), F90 (Testimonials Upload), F91 (Admin Reports).
- **Landing Page**: F96 (Web Landing Page Video Popup).
