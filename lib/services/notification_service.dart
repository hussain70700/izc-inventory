import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';

class NotificationService {
  static const String _notificationsKey = 'app_notifications';

  // Get all notifications
  static Future<List<NotificationModel>> getNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getString(_notificationsKey);

      if (notificationsJson == null || notificationsJson.isEmpty) {
        return [];
      }

      final List<dynamic> decoded = json.decode(notificationsJson);
      return decoded.map((item) => NotificationModel.fromJson(item)).toList();
    } catch (e) {
      print('Error getting notifications: $e');
      return [];
    }
  }

  // Save notifications
  static Future<bool> _saveNotifications(List<NotificationModel> notifications) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = json.encode(
        notifications.map((n) => n.toJson()).toList(),
      );
      return await prefs.setString(_notificationsKey, notificationsJson);
    } catch (e) {
      print('Error saving notifications: $e');
      return false;
    }
  }

  // Create a new notification
  static Future<bool> createNotification({
    required String title,
    required String description,
    required String createdBy,
  }) async {
    try {
      final notifications = await getNotifications();

      final newNotification = NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: description,
        createdAt: DateTime.now(),
        createdBy: createdBy,
      );

      notifications.insert(0, newNotification); // Add to beginning
      return await _saveNotifications(notifications);
    } catch (e) {
      print('Error creating notification: $e');
      return false;
    }
  }

  // Delete a notification
  static Future<bool> deleteNotification(String notificationId) async {
    try {
      final notifications = await getNotifications();
      notifications.removeWhere((n) => n.id == notificationId);
      return await _saveNotifications(notifications);
    } catch (e) {
      print('Error deleting notification: $e');
      return false;
    }
  }

  // Get notification count
  static Future<int> getNotificationCount() async {
    final notifications = await getNotifications();
    return notifications.length;
  }

  // Clear all notifications (admin only)
  static Future<bool> clearAllNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_notificationsKey);
    } catch (e) {
      print('Error clearing notifications: $e');
      return false;
    }
  }
}