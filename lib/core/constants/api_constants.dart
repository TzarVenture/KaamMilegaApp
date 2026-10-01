/// API Constants matching km-backend Fiber routes
class ApiConstants {
  ApiConstants._();

  /// Default production Base API URL
  /// If running locally with Docker/Go server, can change to http://10.0.2.2:8000/api (emulator)
  /// or http://localhost:8000/api (desktop / web)
  static const String baseUrl = 'https://api.kaammilega.com/api';

  /// KaamMilega website (km-frontend). Same domain the website itself uses.
  static const String websiteUrl = 'https://kaammilega.com';

  /// Public profile page on the website: `/profile/{username or userId}`,
  /// the same link the website builds (it loads GET /user/:id, which accepts
  /// either).
  static String publicProfileUrl(String usernameOrId) =>
      '$websiteUrl/profile/$usernameOrId';

  /// Resolves any relative, partial, or malformed image/file URL into a full absolute HTTP/HTTPS URL.
  static String resolveImageUrl(String? url) {
    if (url == null) return '';
    var trimmed = url.trim();
    if (trimmed.isEmpty) return '';

    // Handle malformed file:/// URLs that might have been saved locally or in state
    if (trimmed.startsWith('file:///api/') ||
        trimmed.startsWith('file:///files/')) {
      trimmed = trimmed.substring(7); // strips 'file://'
    } else if (trimmed.startsWith('file://api/') ||
        trimmed.startsWith('file://files/')) {
      trimmed = trimmed.substring(7);
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('assets/') ||
        trimmed.startsWith('data:') ||
        trimmed.startsWith('blob:')) {
      return trimmed;
    }

    final base = baseUrl;
    final host = base.endsWith('/api')
        ? base.substring(0, base.length - 4)
        : base;
    final formattedUrl = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$host$formattedUrl';
  }

  // --- Auth Endpoints ---
  static const String sendOtp = '/auth/otp/send';
  static const String verifyOtp = '/auth/otp/verify';
  static const String loginPassword = '/auth/login/password';
  static const String registerPassword = '/auth/register/password';
  static const String forgotPassword = '/auth/password/forgot';
  static const String resetPassword = '/auth/password/reset';
  static const String otpEmailSend = '/auth/otp/email/send';
  static const String otpEmailVerify = '/auth/otp/email/verify';
  static const String userProfile = '/user/profile';
  static const String userRegister = '/user/register';

  // --- Jobs Endpoints (Candidate Discovery) ---
  static const String jobs = '/jobs';
  static const String jobDetail = '/jobs/'; // append :id

  // --- Cities Endpoints ---
  static const String cities = '/cities';

  // --- Applications Endpoints (Candidate Tracking) ---
  static const String applications = '/applications';
  static const String myApplications = '/applications/my';

  // --- Interviews Endpoints ---
  static const String myInterviews = '/interviews/my';

  // --- Skills Endpoints ---
  static const String skills = '/skills';

  // --- User Profile Endpoints ---
  static const String userSkill =
      '/user/skill'; // POST add, DELETE /:skillName (URL-encoded)
  static const String userEducation =
      '/user/education'; // POST add, PUT/DELETE /:id
  static const String userExperience =
      '/user/experience'; // POST add, PUT/DELETE /:id
  static const String userProject =
      '/user/project'; // POST add, PUT/DELETE /:id
  static const String userPassword = '/user/password'; // PUT
  static const String userOpenToWork = '/user/open-to-work'; // PATCH
  static const String userUsername = '/user/username'; // PATCH custom URL
  static const String userUsernameCheck =
      '/user/username/check'; // GET ?username=
  static const String userProvidingServices =
      '/user/providing-services'; // PATCH
  static const String userApplyExpert = '/user/apply-expert'; // POST
  static const String userSettings = '/user/settings'; // GET / PUT
  static const String userBookmark =
      '/user/bookmark/'; // POST toggle, append :jobId
  // NOTE: GET /user/bookmarks and GET /user/settings return 500 on the current
  // backend (shadowed by GET /user/:id). The app reads both from GET /user/profile.
  static const String userBookmarks =
      '/user/bookmarks'; // GET (not used, see note)
  static const String userSearch = '/user/search'; // GET ?q=
  static const String userById = '/user/'; // GET, append :id
  // InstantMilega for workers (login required)
  static const String instantCandidateStatus =
      '/instant-work/candidate/status'; // GET
  static const String instantAvailability =
      '/instant-work/availability'; // POST online / offline
  static const String instantLocation =
      '/instant-work/location'; // POST {lat, lng} while online
  static const String instantPassPayWallet =
      '/instant-work/pass/pay-wallet'; // POST (₹99 InstantPass)
  static const String instantPassOrder =
      '/instant-work/pass/order'; // POST → Razorpay order (amount in paise)
  static const String instantPassVerify =
      '/instant-work/pass/verify'; // POST {razorpay_order_id, …}
  static const String instantCandidateFeed =
      '/instant-work/candidate/feed'; // GET ?lat&lng&radius_km&skill
  static const String instantClaim = '/instant-work/claim'; // POST {job_id}
  static const String instantActiveJob =
      '/instant-work/candidate/active-job'; // GET (null = none)
  static const String instantJobs = '/instant-work/jobs/'; // PUT :id/complete
  // Profile analytics
  static const String userViewers = '/user/viewers'; // GET who viewed me
  static const String userImpressions =
      '/user/impressions'; // POST {author_ids}
  static const String applicationCheck =
      '/applications/check/'; // GET, append :jobId

  // --- File Upload ---
  static const String fileUpload = '/files/upload';

  // --- Network / Connections Endpoints ---
  static const String networkConnect = '/network/connect';
  // Public people list shown on the website home ("Connect Just Like You")
  static const String communityUsers = '/community/users'; // GET
  static const String experts = '/experts'; // GET public list of experts
  // Pro Expert plans (Apply to be an Expert)
  static const String expertPlans = '/subscriptions/expert/plans'; // GET
  static const String expertSubscriptionMy = '/subscriptions/expert/my';
  static const String expertSubscriptionCreateOrder =
      '/subscriptions/expert/create-order'; // POST {plan_type}
  static const String expertSubscriptionVerify =
      '/subscriptions/expert/verify-payment'; // POST
  static const String expertSubscriptionWalletCheckout =
      '/subscriptions/expert/wallet-checkout'; // POST {plan_type}
  static const String companiesTop =
      '/companies/top'; // GET ?limit= public employers
  static const String networkAccept = '/network/accept';
  static const String networkIgnore = '/network/ignore';
  static const String networkPending = '/network/pending';
  static const String networkConnections = '/network/connections';
  static const String networkDelete = '/network/connections/';
  static const String networkStatus = '/network/status/';

  // --- Real-Time Chat & Messaging Endpoints ---
  static const String chats = '/chats';
  static const String chatMessages = '/chats/messages';
  static const String chatMessagesList = '/chats/';
  static const String wsChats = '/ws/chats';

  // --- Feed & Posts Endpoints ---
  static const String posts = '/posts';
  static const String feed = '/feed';

  // --- Help ---
  static const String faqQuestions = '/questions'; // GET (public FAQ)

  // --- Notifications Endpoints ---
  static const String notifications = '/notifications';

  // --- Events & Mentorship Endpoints ---
  static const String events = '/events';
  static const String eventsMyTickets = '/events/my/tickets'; // GET
  static const String mentorship = '/mentorships';
  static const String mentorships = '/mentorships';

  // --- Wallet Endpoints (live on backend main since 23 Sep 2026) ---
  static const String walletBalance = '/wallet/balance'; // GET summary
  static const String walletTransactions =
      '/wallet/transactions'; // GET ?page&limit&type
  static const String walletTopupCreateOrder =
      '/wallet/topup/create-order'; // POST {amount}
  static const String walletTopupVerify =
      '/wallet/topup/verify'; // POST razorpay ids + amount
  static const String walletWithdraw =
      '/wallet/withdraw'; // POST WithdrawalRequest (payout of earnings)
  // Not built on backend yet (screen shows "coming soon"):
  static const String walletTransfer = '/wallet/transfer';

  // --- Refund requests on wallet payments (backend F73) ---
  static const String walletDisputes = '/wallet/disputes'; // POST raise
  static const String walletMyDisputes =
      '/wallet/my/disputes'; // GET ?page&limit&status

  // --- Paid mentorship booking (backend F76) ---
  static const String mentorshipBookWallet = '/mentorships/book-wallet'; // POST
  static const String mentorshipCreateOrder =
      '/mentorships/create-order'; // POST
  static const String mentorshipVerifyPayment =
      '/mentorships/verify-payment'; // POST
  static const String mentorshipMyBookings =
      '/mentorships/bookings/my'; // GET sessions booked by the user
  // Expert side (user with the "expert" role)
  static const String mentorshipExpertBookings =
      '/mentorships/bookings/expert'; // GET sessions booked with me
  static const String mentorshipExpertMy =
      '/mentorships/expert/my'; // GET my offerings
  static const String mentorshipAvailability =
      '/mentorships/availability'; // GET / PUT my weekly hours
  static String mentorshipExpertAvailability(String expertId) =>
      '/mentorships/expert/$expertId/availability'; // GET (public)
  static const String mentorshipBookings =
      '/mentorships/bookings'; // POST /:id/review (completed sessions)

  // --- Company Hub Endpoints ---
  static const String adminCompanies = '/admin/companies';
}
