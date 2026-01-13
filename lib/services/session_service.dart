import 'package:hive_flutter/hive_flutter.dart';

/// Service to manage user sessions without Supabase Auth using Hive
class SessionService {
  static const String _boxName = 'session';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';
  static const String _roleKey = 'role';
  static const String _fullNameKey = 'full_name';
  static const String _emailKey = 'email';
  static const String _imageUrlKey = 'image_url';
  static const String _loginTimeKey = 'login_time';

  /// Initialize Hive (call this in main.dart before runApp)
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  /// Get the session box
  static Box _getBox() {
    return Hive.box(_boxName);
  }

  /// Save user session after successful login
  static Future<void> saveSession(Map<String, dynamic> user) async {
    final box = _getBox();
    await box.put(_userIdKey, user['id'].toString());
    await box.put(_usernameKey, user['username']);
    await box.put(_roleKey, user['role']);
    await box.put(_fullNameKey, user['full_name']);
    await box.put(_emailKey, user['email'] ?? '');
    await box.put(_imageUrlKey, user['image_url'] ?? '');
    await box.put(_loginTimeKey, DateTime.now().toIso8601String());
  }

  /// Get current user ID
  static String? getUserId() {
    final box = _getBox();
    return box.get(_userIdKey);
  }

  /// Get current username
  static String? getUsername() {
    final box = _getBox();
    return box.get(_usernameKey);
  }

  /// Get current user role
  static String? getUserRole() {
    final box = _getBox();
    return box.get(_roleKey);
  }

  /// Get current user full name
  static String? getFullName() {
    final box = _getBox();
    return box.get(_fullNameKey);
  }

  /// Get current user email
  static String? getEmail() {
    final box = _getBox();
    return box.get(_emailKey);
  }

  /// Get current user image URL
  static String? getImageUrl() {
    final box = _getBox();
    return box.get(_imageUrlKey);
  }

  /// Get login time
  static DateTime? getLoginTime() {
    final box = _getBox();
    final timeStr = box.get(_loginTimeKey);
    if (timeStr != null) {
      return DateTime.parse(timeStr);
    }
    return null;
  }

  /// Check if user is admin
  static bool isAdmin() {
    final role = getUserRole();
    return role == 'admin';
  }

  /// Check if user is manager
  static bool isManager() {
    final role = getUserRole();
    return role == 'manager';
  }

  /// Check if user is logged in
  static bool isLoggedIn() {
    final box = _getBox();
    return box.containsKey(_userIdKey);
  }

  /// Clear session (logout)
  static Future<void> clearSession() async {
    final box = _getBox();
    await box.clear();
  }

  /// Get full user session data
  static Map<String, String?> getSession() {
    final box = _getBox();
    return {
      'id': box.get(_userIdKey),
      'username': box.get(_usernameKey),
      'role': box.get(_roleKey),
      'full_name': box.get(_fullNameKey),
      'email': box.get(_emailKey),
      'image_url': box.get(_imageUrlKey),
      'login_time': box.get(_loginTimeKey),
    };
  }

  /// Update specific user data (e.g., after profile edit)
  static Future<void> updateUserData({
    String? fullName,
    String? email,
    String? imageUrl,
  }) async {
    final box = _getBox();
    if (fullName != null) {
      await box.put(_fullNameKey, fullName);
    }
    if (email != null) {
      await box.put(_emailKey, email);
    }
    if (imageUrl != null) {
      await box.put(_imageUrlKey, imageUrl);
    }
  }

  /// Check if session is expired (optional - for auto-logout)
  static bool isSessionExpired({int maxHours = 24}) {
    final loginTime = getLoginTime();
    if (loginTime == null) return true;

    final difference = DateTime.now().difference(loginTime);
    return difference.inHours > maxHours;
  }

  /// Get session duration in hours
  static int getSessionDurationHours() {
    final loginTime = getLoginTime();
    if (loginTime == null) return 0;

    final difference = DateTime.now().difference(loginTime);
    return difference.inHours;
  }
}