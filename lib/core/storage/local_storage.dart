import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Helper service for persisting Auth tokens and user state in SharedPreferences
class LocalStorage {
  static const String _tokenKey = 'km_auth_token';
  static const String _userKey = 'km_user_data';
  static const String _selectedCityKey = 'km_selected_city';

  static SharedPreferences? _prefs;

  /// Initialize SharedPreferences instance
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
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

  /// Save user profile json
  static Future<bool> saveUser(Map<String, dynamic> userMap) async {
    await init();
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

  /// Clear all user auth data
  static Future<void> clearSession() async {
    await init();
    await _prefs!.remove(_tokenKey);
    await _prefs!.remove(_userKey);
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

  static const String _savedJobsKey = 'km_saved_job_ids';

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
}
