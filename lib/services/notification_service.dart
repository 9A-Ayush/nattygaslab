import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chemical_service.dart';

class NotificationService {
  static const String _lowStockKey = 'low_stock_notifications';
  static const String _expiryKey = 'expiry_notifications';
  static const String _lowStockThresholdKey = 'low_stock_threshold';
  static const String _expiryDaysKey = 'expiry_notification_days';

  // Default settings
  static const double _defaultLowStockThreshold = 10.0;
  static const int _defaultExpiryDays = 30;

  /// Get notification settings
  static Future<NotificationSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    return NotificationSettings(
      lowStockEnabled: prefs.getBool(_lowStockKey) ?? true,
      expiryEnabled: prefs.getBool(_expiryKey) ?? true,
      lowStockThreshold: prefs.getDouble(_lowStockThresholdKey) ?? _defaultLowStockThreshold,
      expiryNotificationDays: prefs.getInt(_expiryDaysKey) ?? _defaultExpiryDays,
    );
  }

  /// Save notification settings
  static Future<void> saveSettings(NotificationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    
    await Future.wait([
      prefs.setBool(_lowStockKey, settings.lowStockEnabled),
      prefs.setBool(_expiryKey, settings.expiryEnabled),
      prefs.setDouble(_lowStockThresholdKey, settings.lowStockThreshold),
      prefs.setInt(_expiryDaysKey, settings.expiryNotificationDays),
    ]);
  }

  /// Get current notifications
  static Future<List<ChemicalNotification>> getNotifications() async {
    final settings = await getSettings();
    final notifications = <ChemicalNotification>[];

    if (settings.lowStockEnabled) {
      final lowStockChemicals = await ChemicalService.getLowStockChemicals(
        threshold: settings.lowStockThreshold,
      );
      
      for (final chemical in lowStockChemicals) {
        notifications.add(ChemicalNotification(
          id: '${chemical['id']}_low_stock',
          chemicalId: chemical['id'],
          chemicalName: chemical['name'],
          type: NotificationType.lowStock,
          message: 'Low stock: ${chemical['quantity']} ${chemical['unit']} remaining',
          severity: NotificationSeverity.warning,
          timestamp: DateTime.now(),
          data: chemical,
        ));
      }
    }

    if (settings.expiryEnabled) {
      final expiringChemicals = await ChemicalService.getChemicalsExpiringSoon();
      
      for (final chemical in expiringChemicals) {
        final expiryDate = (chemical['expiryDate'] as Timestamp?)?.toDate();
        if (expiryDate != null) {
          final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;
          
          notifications.add(ChemicalNotification(
            id: '${chemical['id']}_expiry',
            chemicalId: chemical['id'],
            chemicalName: chemical['name'],
            type: NotificationType.expiry,
            message: daysUntilExpiry > 0 
                ? 'Expires in $daysUntilExpiry days'
                : 'Expired ${daysUntilExpiry.abs()} days ago',
            severity: daysUntilExpiry <= 0 
                ? NotificationSeverity.critical 
                : daysUntilExpiry <= 7 
                    ? NotificationSeverity.high 
                    : NotificationSeverity.medium,
            timestamp: DateTime.now(),
            data: chemical,
          ));
        }
      }
    }

    // Sort by severity and timestamp
    notifications.sort((a, b) {
      final severityCompare = b.severity.index.compareTo(a.severity.index);
      if (severityCompare != 0) return severityCompare;
      return b.timestamp.compareTo(a.timestamp);
    });

    return notifications;
  }

  /// Get notification count
  static Future<int> getNotificationCount() async {
    final notifications = await getNotifications();
    return notifications.length;
  }

  /// Show notification badge
  static Widget buildNotificationBadge(int count) {
    if (count == 0) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      constraints: const BoxConstraints(
        minWidth: 16,
        minHeight: 16,
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class NotificationSettings {
  final bool lowStockEnabled;
  final bool expiryEnabled;
  final double lowStockThreshold;
  final int expiryNotificationDays;

  const NotificationSettings({
    required this.lowStockEnabled,
    required this.expiryEnabled,
    required this.lowStockThreshold,
    required this.expiryNotificationDays,
  });

  NotificationSettings copyWith({
    bool? lowStockEnabled,
    bool? expiryEnabled,
    double? lowStockThreshold,
    int? expiryNotificationDays,
  }) {
    return NotificationSettings(
      lowStockEnabled: lowStockEnabled ?? this.lowStockEnabled,
      expiryEnabled: expiryEnabled ?? this.expiryEnabled,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      expiryNotificationDays: expiryNotificationDays ?? this.expiryNotificationDays,
    );
  }
}

class ChemicalNotification {
  final String id;
  final String chemicalId;
  final String chemicalName;
  final NotificationType type;
  final String message;
  final NotificationSeverity severity;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  const ChemicalNotification({
    required this.id,
    required this.chemicalId,
    required this.chemicalName,
    required this.type,
    required this.message,
    required this.severity,
    required this.timestamp,
    required this.data,
  });
}

enum NotificationType {
  lowStock,
  expiry,
  general,
}

enum NotificationSeverity {
  low,
  medium,
  high,
  warning,
  critical,
}