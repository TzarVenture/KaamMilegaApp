/// API Constants matching km-backend Fiber routes
class ApiConstants {
  ApiConstants._();

  /// Default production Base API URL
  /// If running locally with Docker/Go server, can change to http://10.0.2.2:8000/api (emulator)
  /// or http://localhost:8000/api (desktop / web)
  static const String baseUrl = 'https://api.kaammilega.com/api';

  /// KaamMilega website (km-frontend). Same domain the website itself uses.
  static const String websiteUrl = 'https://kaammilega.com';

  /// Public profile page on the website: `/profile/{userId}`, the same link
  /// the website builds for a user's profile (it loads GET /user/:id).
  static String publicProfileUrl(String userId) =>
      '$websiteUrl/profile/$userId';

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
  static const String applicationCheck =
      '/applications/check/'; // GET, append :jobId

  // --- File Upload ---
  static const String fileUpload = '/files/upload';

  // --- Network / Connections Endpoints ---
  static const String networkConnect = '/network/connect';
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

  // --- Notifications Endpoints ---
  static const String notifications = '/notifications';

  // --- Events & Mentorship Endpoints ---
  static const String events = '/events';
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

  // --- Paid mentorship booking (backend F76) ---
  static const String mentorshipBookWallet = '/mentorships/book-wallet'; // POST
  static const String mentorshipCreateOrder =
      '/mentorships/create-order'; // POST
  static const String mentorshipVerifyPayment =
      '/mentorships/verify-payment'; // POST
  static const String mentorshipMyBookings =
      '/mentorships/bookings/my'; // GET sessions booked by the user

  // --- Company Hub Endpoints ---
  static const String adminCompanies = '/admin/companies';
}
