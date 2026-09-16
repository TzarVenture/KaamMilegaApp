/// API Constants matching km-backend Fiber routes
class ApiConstants {
  ApiConstants._();

  /// Default production Base API URL
  /// If running locally with Docker/Go server, can change to http://10.0.2.2:8000/api (emulator)
  /// or http://localhost:8000/api (desktop / web)
  static const String baseUrl = 'https://api.kaammilega.com/api';

  // --- Auth Endpoints ---
  static const String sendOtp = '/auth/otp/send';
  static const String verifyOtp = '/auth/otp/verify';
  static const String loginPassword = '/auth/login';
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
  static const String userSkill = '/user/skill';
  static const String userEducation = '/user/education';
  static const String userExperience = '/user/experience';

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
  static const String mentorship = '/mentorship';

  // --- Company Hub Endpoints ---
  static const String adminCompanies = '/admin/companies';
}
