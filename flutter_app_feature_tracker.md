# KaamMilega™ — Mobile Application Feature Tracking (Candidate & Gig Workers)

> **Exact Google Sheets Format**: Mirrored to your 8-column tracking schema (`Seq #`, `Feature ID`, `Feature Name`, `Module / Phase`, `Milestone & Sprint`, `Current Status`, `Branch / PR Reference`, `Live Progress & Developer Notes`).
> **Last updated**: **2026-10-06**, checked against the app code (branch `main` @ `6824103`, all work committed) and backend `main` @ `807fe02`. Rows changed 1–6 Oct carry the commit where the work lives. Older rows still name the branch/commit of their last change.
> **For the detailed, file-level status use [FEATURE_STATUS.md](FEATURE_STATUS.md)** (this tracker mirrors the Google Sheet).
> **Files Available**:
> - [flutter_app_feature_tracker.csv](flutter_app_feature_tracker.csv) *(Google Sheets: File → Import → Upload)*

---

## 📊 Summary Dashboard (Candidate & Gig Worker Mobile Scope)

| Status Category | Feature Count | Description |
| :--- | :---: | :--- |
| 🟢 **Fully Implemented** | **49** | Auth (OTP, email, reset, new-user sign-up, session expiry), Profile (info, education/experience/skills edit & delete, photo, resume, projects, strength bar), Jobs (search + voice, hero card, filters, detail, apply, bookmarks), Applications, Interviews, Experts (apply + Pro Expert plans, directory, free & paid booking, ratings & reviews, Expert Dashboard), Pro Expert subscription, Connections, People You May Know, Real-time chat (conversation list + unread badges, attachments), Events (list, register, paid tickets, attendee list), Wallet (balances, add money, history, refunds & disputes), Mentorship checkout, Emails, Instant Milega availability toggle, Settings, Guest mode |
| 🟡 **Partially Implemented** | **8** | Android & iOS release (signing), Withdrawals (manual payouts), Services browse, ₹99 pass / InstantPass (wallet only), GPS location (no background tracking), Spot-gig dispatch (list, no dispatch card) |
| ⏳ **Pending Implementation** | **1** | FCM push notifications (in-app notifications are live since 5 Oct) |
| 🚀 **Upcoming / Not Started** | **14** | KYC, Skill certifications, Services booking / quotes / tracking, Community feed (3), Chat block/report, WebRTC audio & video, AI assistant, Refer & Earn, Offers |
| **Total Tracked Mobile Features** | **72** | **Milestones 1 to 5 (Candidate & Gig Workers Exclusive)** |

---

## 🔹 MILESTONE 1: WEEK 1 (Days 1–7) — Core Auth, Candidate Profile, Jobs & Real-Time Chat

| Seq # | Feature ID | Feature Name | Module / Phase | Milestone & Sprint | Current Status | Branch / PR Reference | Live Progress & Developer Notes |
| :---: | :---: | :--- | :--- | :---: | :---: | :---: | :--- |
| **1** | **F01** | Candidate Registration - OTP Phone Verification | Core Auth | M1 - Week 1 | `Fully Implemented` | `main` | LoginScreen & OtpScreen wired to POST /auth/otp/send & /auth/otp/verify. SMS OTP flow working. |
| **2** | **F02** | Candidate Registration - Email & Profile Setup | Core Auth | M1 - Week 1 | `Fully Implemented` | `d1e0444` | New OTP users finish sign-up on CompleteProfileScreen -> POST /user/register (fixed 25 Sep, Batch 1). Email sign-up uses POST /auth/register/password. |
| **3** | **F04** | User Login - OTP-Based Phone Login | Core Auth | M1 - Week 1 | `Fully Implemented` | `main` | Phone OTP login returns signed JWT with role claims; token stored in LocalStorage (SharedPreferences). |
| **4** | **F05** | User Login - Email + Password Login | Core Auth | M1 - Week 1 | `Fully Implemented` | `main` | Email + password login built in LoginScreen and available on main. |
| **5** | **F06** | Forgot Password & Password Reset Flow | Core Auth | M1 - Week 1 | `Fully Implemented` | `main` | ForgotPasswordScreen email OTP reset flow (backend sends the email) available on main. |
| **6** | **F07** | JWT Authentication Middleware & RBAC | Core Auth | M1 - Week 1 | `Fully Implemented` | `d1e0444` | Bearer JWT on every call; a 401 mid-session calls AuthNotifier.sessionExpired() and the router sends the user to Login (H-05 fixed). Backend also supports cookie auth for the website. |
| **7** | **F08** | SMS OTP Service Integration | Core Auth | M1 - Week 1 | `Fully Implemented` | `main` | SMS OTP is sent by the backend; app calls /auth/otp/send and /auth/otp/verify. |
| **8** | **F09** | File Upload Service (Images, PDFs, Docs) | Core Auth | M1 - Week 1 | `Fully Implemented` | `main` | App uploads avatars and documents via backend POST /api/files/upload and uses the returned URL. |
| **9** | **F10** | Candidate Profile - Personal & Professional Info | Candidate Profile | M1 - Week 1 | `Fully Implemented` | `fix/backend-alignment-wallet-payments (a30fa29)` | EditProfileDialog calls PATCH /user/profile for name, headline, gender and about. Profile read from GET /user/profile. |
| **10** | **F11** | Candidate Profile - Education History | Candidate Profile | M1 - Week 1 | `Fully Implemented` | `d1e0444` | Add, edit and delete: POST /user/education, PUT/DELETE /user/education/:id (Batch 7a, 25 Sep). |
| **11** | **F12** | Candidate Profile - Work Experience | Candidate Profile | M1 - Week 1 | `Fully Implemented` | `d1e0444` | Add, edit and delete: POST /user/experience, PUT/DELETE /user/experience/:id (Batch 7a, 25 Sep). |
| **12** | **F13** | Candidate Profile - Skills Tagging & Multi-Select | Candidate Profile | M1 - Week 1 | `Fully Implemented` | `d1e0444` | Add (POST /user/skill) and remove (DELETE /user/skill/:skillName). Backend bug: multi-word skill names are not decoded, so they cannot be removed (B-07). |
| **13** | **F14** | Candidate Profile - Profile Photo Upload | Candidate Profile | M1 - Week 1 | `Fully Implemented` | `main` | Profile photo upload and remove with instant preview and fallback avatar. No image cropping. |
| **14** | **F15** | Candidate Profile - Resume Upload & Download | Candidate Profile | M1 - Week 1 | `Fully Implemented` | `fix/backend-alignment-wallet-payments (a30fa29)` | Resume picked and uploaded on device, sent as resume_url when applying to a job. Waiting on backend: no resume field on the user profile, so it is not saved to the profile. |
| **15** | **F16** | Candidate Profile - Profile Strength Bar | Candidate Profile | M1 - Week 1 | `Fully Implemented` | `main` | ProfileStrengthCard with weighted completeness calculation, checklist and 1-tap actions. |
| **16** | **F17** | Candidate Profile - Portfolio Links & Projects | Candidate Profile | M1 - Week 1 | `Fully Implemented` | `main` | Projects add, edit (PUT) and delete, plus portfolio_label. Available on main. |
| **17** | **F21** | Candidate - Job Search & Discovery Engine | Jobs & Hiring | M1 - Week 1 | `Fully Implemented` | `main (6824103)` | Jobs tab with blue hero card; search with voice input (speech_to_text); city dropdown with search; Home "Explore Popular Job Categories" photos open Jobs with a search, and filters reset when the user goes back to Home. |
| **18** | **F22** | Candidate - Category & City Filters | Jobs & Hiring | M1 - Week 1 | `Fully Implemented` | `main` | FilterModalSheet & CitySelectorSheet multi-select filters for Job Type, City, Gender, Education, Salary, Experience. |
| **19** | **F23** | Candidate - Job Detail View & 1-Click Apply | Jobs & Hiring | M1 - Week 1 | `Fully Implemented` | `fix/backend-alignment-wallet-payments (a30fa29)` | Job detail with 1-click apply; Already Applied state from GET /applications/check/:jobId. Errors shown with clear messages. |
| **20** | **F24** | Candidate - Save / Bookmark Jobs | Jobs & Hiring | M1 - Week 1 | `Fully Implemented` | `d1e0444` | Bookmark toggle synced with POST /user/bookmark/:jobId; Saved Jobs loads every saved job by ID (GET /jobs/:id), deleted jobs show as unavailable. |
| **21** | **F25** | Candidate - My Applications Dashboard | Jobs & Hiring | M1 - Week 1 | `Fully Implemented` | `main` | MyApplicationsScreen fetches GET /applications/my with status badges (Applied, Shortlisted, Interview, Rejected). |
| **22** | **F29** | Candidate - Interview Calendar & Schedule View | Jobs & Hiring | M1 - Week 1 | `Fully Implemented` | `main` | InterviewsScreen fetches GET /interviews/my showing date, time (UTC handled), location, mode and notes. |
| **23** | **F42** | Experts - Become an Expert Registration | Skills & Experts | M1 - Week 1 | `Fully Implemented` | `feat/map-location-integration (0fa522f)` | Apply to be an Expert opens the Pro Expert plans screen (monthly / yearly) and the application form; drawer has a highlighted Apply card. Backend issues found 6 Oct: B-25, B-26 (see F75). |
| **24** | **F43** | Experts - Verified Expert Public Directory | Skills & Experts | M1 - Week 1 | `Fully Implemented` | `fix/backend-alignment-wallet-payments (a30fa29)` | Expert directory reads GET /mentorships (not /admin/users). No fake ratings shown. |
| **25** | **F44** | Experts - Book 1-on-1 Mentorship Session | Skills & Experts | M1 - Week 1 | `Fully Implemented` | `fix/backend-alignment-wallet-payments (a30fa29)` | Free sessions booked via POST /mentorships/book; paid sessions via wallet (POST /mentorships/book-wallet) or Razorpay (create-order + verify-payment). |
| **26** | **F54** | Networking - Professional Connections Hub | Social & Chat | M1 - Week 1 | `Fully Implemented` | `feat/map-location-integration (0fa522f)` | Connections, pending invitations, connect/accept/ignore/remove; member profile page (/members/:id) with Connect and Message. |
| **27** | **F56** | Real-Time Chat - Conversation List & Badges | Social & Chat | M1 - Week 1 | `Fully Implemented` | `main (6824103)` | 5 Oct: website-style Messages list — All Chats / Unread, search chats and find people, online dot, last message, time, unread count, "typing..."; Chats tab badge from unread_count (GET /chats); delete a chat by swipe-left or long-press (DELETE /chats/:id, removes it for both people — B-23). |
| **28** | **F57** | Real-Time Chat - Instant WebSocket Delivery | Social & Chat | M1 - Week 1 | `Fully Implemented` | `main (6824103)` | Shared LiveSocket on web_socket_channel (works on web): one socket, 20 s ping, endless backoff reconnect, catch-up after reconnect. 5 Oct: read ticks (PUT /chats/:id/read, MESSAGES_READ), typing indicator (TYPING / USER_TYPING), delete own message for everyone, clear chat, delete conversation; messaging only to recruiters or accepted connections (backend does not enforce — B-24). |
| **29** | **F61** | Events - Public Event Directory & Category Stream | Events & Community | M1 - Week 1 | `Fully Implemented` | `main` | EventsScreen: GET /api/events list and search, shimmer loading and refresh. No category filter. |
| **30** | **F62** | Events - One-Click Event Registration | Events & Community | M1 - Week 1 | `Fully Implemented` | `main` | Register Event button calls POST /api/events/:id/register; My Registered Events view. |
| **31** | **F92** | Platform - WebSocket Hub (Real-Time Engine) | Platform Utilities | M1 - Week 1 | `Fully Implemented` | `main (6824103)` | Two live sockets on the shared LiveSocket base: /api/ws/chats and /api/ws/notifications (token in the query). Backend hub now keeps several sockets per user. |
| **32** | **F93** | Platform - Settings & Account Preferences | Platform Utilities | M1 - Week 1 | `Fully Implemented` | `fix/backend-alignment-wallet-payments (a30fa29)` | SettingsScreen syncs settings via GET /user/profile + PUT /user/settings; change password, logout. |
| **33** | **F97** | Mobile App - Native Android Application | Mobile Client | M1 - Week 1 | `Partially Implemented` | `fix/backend-alignment-wallet-payments (a30fa29)` | Android app ID set to com.kaammilega.app with ProGuard rules. Pending: release signing key (planned for later). |
| **34** | **F98** | Mobile App - Native iOS Application | Mobile Client | M1 - Week 1 | `Partially Implemented` | `fix/backend-alignment-wallet-payments (a30fa29)` | iOS bundle ID set to com.kaammilega.app. Pending: Apple team / signing setup. |
| **35** | **F99** | Platform - Guest User Mode & Auth Guards | Mobile Client | M1 - Week 1 | `Fully Implemented` | `fix/backend-alignment-wallet-payments (a30fa29)` | Guest browsing with login prompts on apply, notifications, follow and profile edits, plus a router login guard for protected screens. |

---

## 🔹 MILESTONE 2: WEEK 2 (Days 8–14) — Multi-Type Wallet, Razorpay & Transactional Emails

| Seq # | Feature ID | Feature Name | Module / Phase | Milestone & Sprint | Current Status | Branch / PR Reference | Live Progress & Developer Notes |
| :---: | :---: | :--- | :--- | :---: | :---: | :---: | :--- |
| **36** | **F68** | Multi-Type Wallet - Balance Ledger (Main/Earnings/Locked/Bonus) | Payments & Wallet | M2 - Week 2 | `Fully Implemented` | `fix/backend-alignment-wallet-payments (a30fa29)` | WalletScreen shows real balances from GET /wallet/balance. No fake amounts. |
| **37** | **F70** | Multi-Type Wallet - Add Money via Razorpay | Payments & Wallet | M2 - Week 2 | `Fully Implemented` | `fix/backend-alignment-wallet-payments (a30fa29)` | Add Money: POST /wallet/topup/create-order -> Razorpay checkout -> POST /wallet/topup/verify. Money shown only after server confirms. Needs Razorpay TEST-mode testing. Backend note: verify credits the amount sent by the client. |
| **38** | **F72** | Multi-Type Wallet - Transaction History & Ledger Logs | Payments & Wallet | M2 - Week 2 | `Fully Implemented` | `feat/map-location-integration (0fa522f)` | Website-style transaction rows: category badge, Main/Locked balance, balance after, short reference, plain-language purpose, status; category filter. |
| **39** | **F74** | Rs 99 One-Time Platform Access Pass (10 Gigs Quota) | Payments & Wallet | M2 - Week 2 | `Partially Implemented` | `feat/map-location-integration (0fa522f)` | InstantPass (10 spot gigs) is bought with the wallet on the Instant Milega page (POST /instant-work/pass/pay-wallet). The Home Rs 99 Access banner still says coming soon and charges nothing. |
| **40** | **F76** | Paid Expert Mentorship Session Checkout (Razorpay) | Payments & Wallet | M2 - Week 2 | `Fully Implemented` | `fix/backend-alignment-wallet-payments (a30fa29)` | Paid mentorship checkout: book-wallet or Razorpay create-order + verify-payment. Needs Razorpay TEST-mode testing. |
| **41** | **F63** | Events - Paid Event Ticket Checkout (Razorpay) | Events & Community | M2 - Week 2 | `Fully Implemented` | `feat/map-location-integration (95c0800)` | Paid event tickets: Razorpay (create-order + verify-payment) or wallet checkout, QR ticket view, My Tickets (GET /events/my/tickets). Razorpay TEST-mode run pending. |
| **42** | **F75** | Paid Tier - Become a Professional / Expert Subscription | Payments & Wallet | M2 - Week 2 | `Fully Implemented` | `feat/map-location-integration (0fa522f)` | Pro Expert: plans and perks from the server, current plan with days left, wallet or Razorpay checkout, safe "could not confirm" / "paid but unconfirmed" handling. Razorpay TEST-mode run pending. Backend (6 Oct): plan not tied to the paid order and payment can be verified twice (B-25); wallet plan saved before the debit, role never removed on expiry, perks not built, no purchase notification (B-26, B-27). |
| **43** | **F69** | Multi-Type Wallet - Aadhaar & PAN KYC Identity Verification | Payments & Wallet | M2 - Week 2 | `Upcoming` | `fix/backend-alignment-wallet-payments (a30fa29)` | Not built in the app (no KYC screen). Waiting on backend: KYC API. |
| **44** | **F71** | Multi-Type Wallet - Bank Payout API (Withdraw Earnings) | Payments & Wallet | M2 - Week 2 | `Partially Implemented` | `d1e0444` | Withdraw request live: POST /wallet/withdraw (UPI or bank, min Rs 50). Backend has no bank verification or RazorpayX payouts; withdrawals are processed manually. No real withdrawal made in testing. |
| **45** | **F73** | Multi-Type Wallet - Refunds & Dispute Handling | Payments & Wallet | M2 - Week 2 | `Fully Implemented` | `feat/map-location-integration (0fa522f)` | Dispute / Refund on money-out rows: reason list with hints, 10-1000 characters, status of existing requests (POST /wallet/disputes, GET /wallet/my/disputes). Approved refunds go to the Main balance. |
| **46** | **F66** | Notifications - Transactional Email Automation (Brevo SMTP) | Notifications & AI | M2 - Week 2 | `Fully Implemented` | `fix/backend-alignment-wallet-payments (a30fa29)` | Transactional emails are sent by the backend; app settings has the email notification toggle. |

---

## 🔹 MILESTONE 3: WEEK 3 (Days 15–21) — InstantMilega™ Geospatial Gig Engine & WebRTC

| Seq # | Feature ID | Feature Name | Module / Phase | Milestone & Sprint | Current Status | Branch / PR Reference | Live Progress & Developer Notes |
| :---: | :---: | :--- | :--- | :---: | :---: | :---: | :--- |
| **47** | **F30** | InstantMilega - Gig Worker "Free Now" Real-Time Toggle | InstantMilega Gig | M3 - Week 3 | `Fully Implemented` | `feat/map-location-integration (0fa522f)` | Online / Offline availability toggle on Instant Milega (POST /instant-work/availability); needs InstantPass (HTTP 402 requires_pass opens the pass purchase). |
| **48** | **F31** | InstantMilega - 30-Second Real-Time GPS Location Tracking | InstantMilega Gig | M3 - Week 3 | `Partially Implemented` | `feat/map-location-integration (0fa522f)` | Location sent when going online / from the location bar (POST /instant-work/location). Continuous 30-second background tracking is not built. |
| **49** | **F32** | InstantMilega - MongoDB 2dsphere Spatial Indexing Engine | InstantMilega Gig | M3 - Week 3 | `Fully Implemented` | `backend fb1c62e` | Backend feature (2dsphere index) is live; the app uses it through the spot-gig feed. Nothing else to build in the app. |
| **50** | **F35** | InstantMilega - 60-Second WebSocket Job Dispatch Card | InstantMilega Gig | M3 - Week 3 | `Partially Implemented` | `feat/map-location-integration (0fa522f)` | Spot Gigs feed + claim + active gig + complete (GET /instant-work/candidate/feed, POST /claim, GET /candidate/active-job, PUT /jobs/:id/complete). Pull-based list, not a 60-second WebSocket dispatch card. Map removed from the page. |
| **51** | **F36** | InstantMilega - Rs 99 Gig Access & Quota Engine | InstantMilega Gig | M3 - Week 3 | `Partially Implemented` | `feat/map-location-integration (0fa522f)` | InstantPass quota via wallet works; Razorpay pass purchase (/pass/order, /pass/verify) not integrated. Backend issues reported (B-12). |
| **52** | **F37** | WebRTC - In-App P2P Audio Calling | InstantMilega Gig | M3 - Week 3 | `Upcoming` | `main` | Not started. Waiting on backend: WebRTC signaling. |
| **53** | **F38** | WebRTC - In-App P2P Video Calling | InstantMilega Gig | M3 - Week 3 | `Upcoming` | `main` | Not started. Waiting on backend: WebRTC signaling. |

---

## 🔹 MILESTONE 4: WEEK 4 (Days 22–28) — Services Marketplace, Social Community Feed & Skills

| Seq # | Feature ID | Feature Name | Module / Phase | Milestone & Sprint | Current Status | Branch / PR Reference | Live Progress & Developer Notes |
| :---: | :---: | :--- | :--- | :---: | :---: | :---: | :--- |
| **54** | **F39** | Skills Marketplace - Skill Profile Showcase | Skills & Experts | M4 - Week 4 | `Fully Implemented` | `main` | Skills shown on profile with master catalog browse and tagging. No endorsements. |
| **55** | **F41** | Skills Marketplace - Skill Certifications & Badges | Skills & Experts | M4 - Week 4 | `Upcoming` | `main` | Not started. Waiting on backend: certification / badge API. |
| **56** | **F45** | Experts - Expert Session Rating & Reviews | Skills & Experts | M4 - Week 4 | `Fully Implemented` | `main (3caaca2)` | Rate a completed session from My Booked Sessions (POST /mentorships/bookings/:id/review). 3 Oct: Ratings & Reviews on the Expert page — average, bar per star, newest reviews (GET /mentorships/expert/:id/reviews). |
| **57** | **F46** | Experts - Expert Earnings Dashboard & Session History | Skills & Experts | M4 - Week 4 | `Fully Implemented` | `main (166242e)` | Expert Dashboard (expert role only): sessions booked with me (confirm, decline, meeting link, mark completed, cancel), my session offers (create, edit, delete), weekly hours, earnings and held amounts from the wallet. |
| **58** | **F47** | Services - Service Directory & Category Browse | Services Market | M4 - Week 4 | `Partially Implemented` | `fix/backend-alignment-wallet-payments (a30fa29)` | Service category tiles shown with a coming soon state (no fake providers). Waiting on backend: services API. |
| **59** | **F48** | Services - Book Local Handyman / Technician | Services Market | M4 - Week 4 | `Upcoming` | `fix/backend-alignment-wallet-payments (a30fa29)` | Not built in the app (coming soon state only). Waiting on backend: service booking API. |
| **60** | **F49** | Services - Provider Profile & Service Quotes | Services Market | M4 - Week 4 | `Upcoming` | `fix/backend-alignment-wallet-payments (a30fa29)` | Not built in the app (coming soon state only). Waiting on backend: provider profile and quotes API. |
| **61** | **F50** | Services - Real-Time Provider GPS Tracking on Map | Services Market | M4 - Week 4 | `Upcoming` | `main` | Not started. Waiting on backend: provider location tracking. |
| **62** | **F51** | Social Feed - Professional Community Discussion Feed | Social & Chat | M4 - Week 4 | `Upcoming` | `fix/backend-alignment-wallet-payments (a30fa29)` | Feed shows a coming soon placeholder (no fake posts). Waiting on backend: community feed API. |
| **63** | **F52** | Social Feed - Post Multimedia Sharing (Images/Videos) | Social & Chat | M4 - Week 4 | `Upcoming` | `main` | Not started. Depends on F51 feed API. |
| **64** | **F53** | Social Feed - Hashtags, Likes, Comments & Shares | Social & Chat | M4 - Week 4 | `Upcoming` | `main` | Not started. Depends on F51 feed API. |
| **65** | **F55** | Networking - People You May Know / Suggested Connections | Social & Chat | M4 - Week 4 | `Fully Implemented` | `main` | People You May Know from GET /community/users (public member list, not personalised): 2-column cards with cover, photo, headline or skills, city, Connect and Message. |
| **66** | **F58** | Real-Time Chat - Media & Document Attachment Sharing | Social & Chat | M4 - Week 4 | `Fully Implemented` | `main (6824103)` | 5 Oct: photo, camera and document (PDF/DOC/DOCX/TXT) attachments up to 10 MB — preview before sending, uploaded with POST /files/upload, sent with attachment_* fields; photos open full screen, files open in the phone viewer; emoji sheet in the composer. |
| **67** | **F59** | Real-Time Chat - Block User & Report Conversation | Social & Chat | M4 - Week 4 | `Upcoming` | `fix/backend-alignment-wallet-payments (a30fa29)` | Not built in the app (no block/report actions). Waiting on backend: block and report API. |
| **68** | **F64** | Events - Attendee List Modal (Clickable Join Count) | Events & Community | M4 - Week 4 | `Fully Implemented` | `main (166242e)` | Event page shows "N attending" with photos; See all opens a searchable list; tap opens the member profile. Uses GET /events/:id/attendees (public fields only). |

---

## 🔹 MILESTONE 5: WEEK 5 (Days 29–35) — Push Alerts, AI Career Assistant & Growth

| Seq # | Feature ID | Feature Name | Module / Phase | Milestone & Sprint | Current Status | Branch / PR Reference | Live Progress & Developer Notes |
| :---: | :---: | :--- | :--- | :---: | :---: | :---: | :--- |
| **69** | **F65** | Notifications - Firebase FCM Push Notifications | Notifications & AI | M5 - Week 5 | `Pending Implementation` | `main` | Not started. Waiting on backend: FCM device token and push sending. In-app notifications (list, live socket, banner, bell) are live since 5 Oct. |
| **70** | **F67** | AI Assistant - Chat with AI (Prompt Chips + Paywall) | Notifications & AI | M5 - Week 5 | `Upcoming` | `fix/backend-alignment-wallet-payments (a30fa29)` | Not built in the app (no AI chat screen). Waiting on backend: AI assistant API. |
| **71** | **F94** | Platform - Refer & Earn (Referral Links & Rewards) | Platform Utilities | M5 - Week 5 | `Upcoming` | `main` | Not started. Waiting on backend: referral API. |
| **72** | **F95** | Platform - Offers & Cashback (Bonus Wallet) | Platform Utilities | M5 - Week 5 | `Upcoming` | `main` | Not started. Waiting on backend: offers and bonus wallet API. |
