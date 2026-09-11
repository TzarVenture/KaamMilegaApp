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
  static const String userProfile = '/user/profile';
  static const String userRegister = '/user/register';

  // --- Jobs Endpoints ---
  static const String jobs = '/jobs';
  static const String jobDetail = '/jobs/'; // append :id
  static const String myJobs = '/jobs/my';

  // --- Cities Endpoints ---
  static const String cities = '/cities';

  // --- Applications Endpoints ---
  static const String applications = '/applications';
  static const String myApplications = '/applications/my';
}
