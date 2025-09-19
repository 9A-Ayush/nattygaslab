import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'user_service.dart';

class UserExportService {
  /// Export users to CSV format
  static Future<String> exportToCSV({
    String? roleFilter,
    String? statusFilter,
    String? searchQuery,
  }) async {
    try {
      final users = await _getFilteredUsers(
        roleFilter: roleFilter,
        statusFilter: statusFilter,
        searchQuery: searchQuery,
      );

      final csvContent = StringBuffer();
      
      // CSV Headers
      csvContent.writeln([
        'Name',
        'Email',
        'Role',
        'Status',
        'Department',
        'Phone',
        'Created Date',
        'Last Login',
      ].map((header) => '"$header"').join(','));

      // CSV Data
      for (final user in users) {
        final row = [
          user['name'] ?? 'Unknown',
          user['email'] ?? 'Unknown',
          user['role'] ?? 'Unknown',
          user['isActive'] == true ? 'Active' : 'Inactive',
          user['department'] ?? 'Not Set',
          user['phone'] ?? 'Not Set',
          user['createdAt'] != null ? _formatDateTime(user['createdAt'].toDate()) : 'Not Available',
          user['lastLogin'] != null ? _formatDateTime(user['lastLogin'].toDate()) : 'Never',
        ].map((field) => '"${field.toString().replaceAll('"', '""')}"').join(',');
        
        csvContent.writeln(row);
      }

      return csvContent.toString();
    } catch (e) {
      debugPrint('Error exporting users to CSV: $e');
      rethrow;
    }
  }

  /// Export users to JSON format
  static Future<String> exportToJSON({
    String? roleFilter,
    String? statusFilter,
    String? searchQuery,
  }) async {
    try {
      final users = await _getFilteredUsers(
        roleFilter: roleFilter,
        statusFilter: statusFilter,
        searchQuery: searchQuery,
      );

      final exportData = {
        'exportDate': DateTime.now().toIso8601String(),
        'totalUsers': users.length,
        'filters': {
          'role': roleFilter,
          'status': statusFilter,
          'search': searchQuery,
        },
        'users': users.map((user) => {
          'name': user['name'],
          'email': user['email'],
          'role': user['role'],
          'status': user['isActive'] == true ? 'Active' : 'Inactive',
          'department': user['department'],
          'phone': user['phone'],
          'createdAt': user['createdAt']?.toDate()?.toIso8601String(),
          'lastLogin': user['lastLogin']?.toDate()?.toIso8601String(),
        }).toList(),
      };

      return const JsonEncoder.withIndent('  ').convert(exportData);
    } catch (e) {
      debugPrint('Error exporting users to JSON: $e');
      rethrow;
    }
  }

  /// Share exported file
  static Future<void> shareExportedFile(String content, String filename, String mimeType) async {
    try {
      if (kIsWeb) {
        await _downloadForWeb(content, filename, mimeType);
      } else {
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsString(content);
        
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Exported users data',
        );
      }
    } catch (e) {
      debugPrint('Error sharing exported file: $e');
      rethrow;
    }
  }

  /// Get filtered users based on criteria
  static Future<List<Map<String, dynamic>>> _getFilteredUsers({
    String? roleFilter,
    String? statusFilter,
    String? searchQuery,
  }) async {
    try {
      final allUsers = await UserService.getAllUsers();
      
      return allUsers.where((user) {
        // Role filter
        if (roleFilter != null && roleFilter != 'All') {
          if (user['role'] != roleFilter) return false;
        }
        
        // Status filter
        if (statusFilter != null && statusFilter != 'All') {
          final isActive = user['isActive'] == true;
          if (statusFilter == 'Active' && !isActive) return false;
          if (statusFilter == 'Inactive' && isActive) return false;
        }
        
        // Search query
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final query = searchQuery.toLowerCase();
          final name = (user['name'] ?? '').toString().toLowerCase();
          final email = (user['email'] ?? '').toString().toLowerCase();
          final department = (user['department'] ?? '').toString().toLowerCase();
          
          if (!name.contains(query) && 
              !email.contains(query) && 
              !department.contains(query)) {
            return false;
          }
        }
        
        return true;
      }).toList();
    } catch (e) {
      debugPrint('Error filtering users: $e');
      return [];
    }
  }

  /// Download file for web platform
  static Future<void> _downloadForWeb(String content, String filename, String mimeType) async {
    throw UnimplementedError('Web download not implemented. Please use mobile app for export functionality.');
  }

  /// Format datetime for export
  static String _formatDateTime(DateTime date) {
    try {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid DateTime';
    }
  }
}

enum UserExportFormat {
  csv,
  json,
}