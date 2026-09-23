import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Helper service for persisting Auth tokens, user state, and selective offline cache in SharedPreferences
class LocalStorage {
  static const String _tokenKey = 'km_auth_token';
  static const String _userKey = 'km_user_data';
  static const String _userCacheTimeKey = 'km_user_cache_time';
  static const String _selectedCityKey = 'km_selected_city';
  static const String _savedJobsKey = 'km_saved_job_ids';
  // Backend has no resume field on the user profile yet, so the uploaded
  // resume URL is kept on the device and attached to job applications.
  static const String _resumeUrlKey = 'km_resume_url';
  // Profile fields the backend does not store yet (open_to_work, etc.)
  static const String _deviceProfilePrefsKey = 'km_device_profile_prefs';

  static const String _jobsCacheKey = 'km_cache_jobs';
  static const String _jobsCacheTimeKey = 'km_cache_jobs_time';

  static const String _appsCacheKey = 'km_cache_applications';
  static const String _appsCacheTimeKey = 'km_cache_applications_time';

  static const String _walletCacheKey = 'km_cache_wallet';
  static const String _walletCacheTimeKey = 'km_cache_wallet_time';

  static SharedPreferences? _prefs;

  /// Initialize SharedPreferences instance
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// For testing
  static void setMockInstance(SharedPreferences prefs) {
    _prefs = prefs;
  }

  /// Save JWT auth token
  static Future<bool> saveToken(String token) async {
    await init();
    return _prefs!.setString(_tokenKey, token);
  }

  /// Retrieve JWT auth token
  static String? getToken() {
    return _prefs?.getString(_tokenKey);
  }

  /// Remove auth token (on logout)
  static Future<bool> removeToken() async {
    await init();
    return _prefs!.remove(_tokenKey);
  }

  /// Save user profile json with timestamp
  static Future<bool> saveUser(Map<String, dynamic> userMap) async {
    await init();
    await _prefs!.setString(
      _userCacheTimeKey,
      DateTime.now().toIso8601String(),
    );
    return _prefs!.setString(_userKey, jsonEncode(userMap));
  }

  /// Retrieve cached user profile
  static Map<String, dynamic>? getUser() {
    final str = _prefs?.getString(_userKey);
    if (str == null || str.isEmpty) return null;
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Retrieve cached user profile with timestamp
  static ({Map<String, dynamic>? user, DateTime? timestamp})
  getUserWithTimestamp() {
    final user = getUser();
    final timeStr = _prefs?.getString(_userCacheTimeKey);
    final time = timeStr != null ? DateTime.tryParse(timeStr) : null;
    return (user: user, timestamp: time);
  }

  /// Clear all user auth data
  static Future<void> clearSession() async {
    await init();
    await _prefs!.remove(_tokenKey);
    await _prefs!.remove(_userKey);
    await _prefs!.remove(_userCacheTimeKey);
    await _prefs!.remove(_resumeUrlKey);
    await _prefs!.remove(_deviceProfilePrefsKey);
    // Per-user caches must not be shown to the next person who logs in
    await _prefs!.remove(_walletCacheKey);
    await _prefs!.remove(_walletCacheTimeKey);
    await _prefs!.remove(_appsCacheKey);
    await _prefs!.remove(_appsCacheTimeKey);
  }

  /// Save profile fields that the backend cannot store yet
  static Future<bool> saveDeviceProfilePrefs(Map<String, dynamic> prefs) async {
    await init();
    final merged = {...getDeviceProfilePrefs(), ...prefs};
    return _prefs!.setString(_deviceProfilePrefsKey, jsonEncode(merged));
  }

  /// Read profile fields kept on this device
  static Map<String, dynamic> getDeviceProfilePrefs() {
    final str = _prefs?.getString(_deviceProfilePrefsKey);
    if (str == null || str.isEmpty) return {};
    try {
      final decoded = jsonDecode(str);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  /// Save uploaded resume URL (kept on device until backend supports it)
  static Future<bool> saveResumeUrl(String url) async {
    await init();
    return _prefs!.setString(_resumeUrlKey, url);
  }

  /// Get uploaded resume URL saved on this device
  static String? getResumeUrl() {
    return _prefs?.getString(_resumeUrlKey);
  }

  /// Save preferred city name
  static Future<bool> saveSelectedCity(String cityName) async {
    await init();
    return _prefs!.setString(_selectedCityKey, cityName);
  }

  /// Get preferred city name
  static String getSelectedCity() {
    return _prefs?.getString(_selectedCityKey) ?? 'All';
  }

  /// Persist saved job IDs locally
  static Future<bool> saveSavedJobIds(Set<String> ids) async {
    await init();
    return _prefs!.setStringList(_savedJobsKey, ids.toList());
  }

  /// Retrieve persisted saved job IDs
  static Set<String> getSavedJobIds() {
    final list = _prefs?.getStringList(_savedJobsKey);
    return list != null ? list.toSet() : {};
  }

  // ==========================================
  // SELECTIVE READ-ONLY OFFLINE CACHE
  // ==========================================

  /// Save Jobs feed to offline cache
  static Future<bool> saveCachedJobs(List<Map<String, dynamic>> jobs) async {
    await init();
    await _prefs!.setString(
      _jobsCacheTimeKey,
      DateTime.now().toIso8601String(),
    );
    return _prefs!.setString(_jobsCacheKey, jsonEncode(jobs));
  }

  /// Retrieve Jobs from offline cache with timestamp
  static ({List<Map<String, dynamic>> jobs, DateTime? timestamp})
  getCachedJobs() {
    final str = _prefs?.getString(_jobsCacheKey);
    final timeStr = _prefs?.getString(_jobsCacheTimeKey);
    final time = timeStr != null ? DateTime.tryParse(timeStr) : null;

    if (str == null || str.isEmpty) {
      return (jobs: <Map<String, dynamic>>[], timestamp: null);
    }

    try {
      final decoded = jsonDecode(str);
      if (decoded is List) {
        final list = decoded.whereType<Map<String, dynamic>>().toList();
        return (jobs: list, timestamp: time);
      }
    } catch (_) {}

    return (jobs: <Map<String, dynamic>>[], timestamp: null);
  }

  /// Save Applications list to offline cache
  static Future<bool> saveCachedApplications(
    List<Map<String, dynamic>> apps,
  ) async {
    await init();
    await _prefs!.setString(
      _appsCacheTimeKey,
      DateTime.now().toIso8601String(),
    );
    return _prefs!.setString(_appsCacheKey, jsonEncode(apps));
  }

  /// Retrieve Applications from offline cache with timestamp
  static ({List<Map<String, dynamic>> apps, DateTime? timestamp})
  getCachedApplications() {
    final str = _prefs?.getString(_appsCacheKey);
    final timeStr = _prefs?.getString(_appsCacheTimeKey);
    final time = timeStr != null ? DateTime.tryParse(timeStr) : null;

    if (str == null || str.isEmpty) {
      return (apps: <Map<String, dynamic>>[], timestamp: null);
    }

    try {
      final decoded = jsonDecode(str);
      if (decoded is List) {
        final list = decoded.whereType<Map<String, dynamic>>().toList();
        return (apps: list, timestamp: time);
      }
    } catch (_) {}

    return (apps: <Map<String, dynamic>>[], timestamp: null);
  }

  /// Save Wallet Summary to offline cache (read-only snapshot)
  static Future<bool> saveCachedWallet(Map<String, dynamic> wallet) async {
    await init();
    await _prefs!.setString(
      _walletCacheTimeKey,
      DateTime.now().toIso8601String(),
    );
    return _prefs!.setString(_walletCacheKey, jsonEncode(wallet));
  }

  /// Retrieve Wallet Summary from offline cache with timestamp
  static ({Map<String, dynamic>? data, DateTime? timestamp}) getCachedWallet() {
    final str = _prefs?.getString(_walletCacheKey);
    final timeStr = _prefs?.getString(_walletCacheTimeKey);
    final time = timeStr != null ? DateTime.tryParse(timeStr) : null;

    if (str == null || str.isEmpty) {
      return (data: null, timestamp: null);
    }

    try {
      final decoded = jsonDecode(str);
      if (decoded is Map<String, dynamic>) {
        return (data: decoded, timestamp: time);
      }
    } catch (_) {}

    return (data: null, timestamp: null);
  }

  /// Generic key-value cache
  static Future<bool> setGenericCache(String key, dynamic data) async {
    await init();
    await _prefs!.setString('${key}_time', DateTime.now().toIso8601String());
    return _prefs!.setString(key, jsonEncode(data));
  }

  /// Retrieve generic key-value cache
  static ({dynamic data, DateTime? timestamp}) getGenericCache(String key) {
    final str = _prefs?.getString(key);
    final timeStr = _prefs?.getString('${key}_time');
    final time = timeStr != null ? DateTime.tryParse(timeStr) : null;

    if (str == null || str.isEmpty) {
      return (data: null, timestamp: null);
    }

    try {
      final decoded = jsonDecode(str);
      return (data: decoded, timestamp: time);
    } catch (_) {
      return (data: null, timestamp: null);
    }
  }
}
