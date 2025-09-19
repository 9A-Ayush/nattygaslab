import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chemical_service.dart';

class ExportService {
  /// Export chemicals to CSV format
  static Future<String> exportToCSV({
    String? manufacturerFilter,
    String? statusFilter,
    String? searchQuery,
  }) async {
    try {
      // Get all chemicals based on filters
      final snapshot = await _getFilteredChemicals(
        manufacturerFilter: manufacturerFilter,
        statusFilter: statusFilter,
        searchQuery: searchQuery,
      );

      // Create CSV content
      final csvContent = StringBuffer();
      
      // CSV Headers
      csvContent.writeln([
        'Name',
        'Manufacturer',
        'Quantity',
        'Unit',
        'Batch Number',
        'Manufacturing Date',
        'Expiry Date',
        'Status',
        'Description',
        'Created Date',
        'Last Updated',
      ].map((header) => '"$header"').join(','));

      // CSV Data - Process documents directly to avoid Chemical.fromFirestore issues
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Safely extract and format data
        final name = data['name']?.toString() ?? 'Unknown';
        final manufacturer = data['manufacturer']?.toString() ?? 'Unknown';
        final quantity = (data['quantity'] ?? 0).toString();
        final unit = data['unit']?.toString() ?? '';
        final batchNo = data['batchNo']?.toString() ?? '';
        
        // Handle dates with proper error handling and multiple format support
        String mfgDateStr = 'Not Set';
        try {
          final mfgDate = data['mfgDate'];
          if (mfgDate != null) {
            mfgDateStr = _parseAndFormatDate(mfgDate);
          }
        } catch (e) {
          mfgDateStr = 'Invalid Date';
        }
        
        String expiryDateStr = 'Not Set';
        try {
          final expiryDate = data['expiryDate'];
          if (expiryDate != null) {
            expiryDateStr = _parseAndFormatDate(expiryDate);
          }
        } catch (e) {
          expiryDateStr = 'Invalid Date';
        }
        
        // Calculate status
        final expiryStatus = ChemicalService.getExpiryStatus(data['expiryDate']);
        final isLowStock = ChemicalService.isLowStock((data['quantity'] ?? 0).toDouble(), 10.0);
        final status = _getStatusText(expiryStatus, isLowStock);
        
        final description = data['description']?.toString() ?? '';
        
        String createdAtStr = 'Not Available';
        try {
          final createdAt = data['createdAt'];
          if (createdAt != null) {
            createdAtStr = _parseAndFormatDateTime(createdAt);
          }
        } catch (e) {
          createdAtStr = 'Invalid Date';
        }
        
        String updatedAtStr = 'Not Available';
        try {
          final updatedAt = data['updatedAt'];
          if (updatedAt != null) {
            updatedAtStr = _parseAndFormatDateTime(updatedAt);
          }
        } catch (e) {
          updatedAtStr = 'Invalid Date';
        }
        
        final row = [
          name,
          manufacturer,
          quantity,
          unit,
          batchNo,
          mfgDateStr,
          expiryDateStr,
          status,
          description,
          createdAtStr,
          updatedAtStr,
        ].map((field) => '"${field.toString().replaceAll('"', '""')}"').join(',');
        
        csvContent.writeln(row);
      }

      return csvContent.toString();
    } catch (e) {
      debugPrint('Error exporting to CSV: $e');
      rethrow;
    }
  }

  /// Export chemicals to JSON format
  static Future<String> exportToJSON({
    String? manufacturerFilter,
    String? statusFilter,
    String? searchQuery,
  }) async {
    try {
      final snapshot = await _getFilteredChemicals(
        manufacturerFilter: manufacturerFilter,
        statusFilter: statusFilter,
        searchQuery: searchQuery,
      );

      final chemicals = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        
        // Clean all Timestamp objects recursively
        final cleanedData = _cleanTimestampsFromMap(data);
        
        // Ensure all required fields have default values
        cleanedData['name'] = cleanedData['name'] ?? 'Unknown';
        cleanedData['manufacturer'] = cleanedData['manufacturer'] ?? 'Unknown';
        cleanedData['quantity'] = cleanedData['quantity'] ?? 0;
        cleanedData['unit'] = cleanedData['unit'] ?? '';
        cleanedData['batchNo'] = cleanedData['batchNo'] ?? '';
        cleanedData['description'] = cleanedData['description'] ?? '';
        cleanedData['audit'] = cleanedData['audit'] ?? [];
        
        return cleanedData;
      }).toList();

      final exportData = {
        'exportDate': DateTime.now().toIso8601String(),
        'totalRecords': chemicals.length,
        'filters': {
          'manufacturer': manufacturerFilter,
          'status': statusFilter,
          'search': searchQuery,
        },
        'chemicals': chemicals,
      };

      return const JsonEncoder.withIndent('  ').convert(exportData);
    } catch (e) {
      debugPrint('Error exporting to JSON: $e');
      rethrow;
    }
  }

  /// Save and share export file
  static Future<void> saveAndShareExport({
    required String content,
    required String filename,
    required String mimeType,
  }) async {
    try {
      if (kIsWeb) {
        // For web, use download
        await _downloadForWeb(content, filename, mimeType);
      } else {
        // For mobile, save to temp directory and share
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsString(content);
        
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Chemical inventory export - $filename',
        );
      }
    } catch (e) {
      debugPrint('Error saving and sharing export: $e');
      rethrow;
    }
  }

  /// Generate export filename
  static String generateFilename(String format, {String? prefix}) {
    final timestamp = DateTime.now();
    final dateStr = '${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}';
    final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}';
    
    final prefixStr = prefix != null ? '${prefix}_' : '';
    return '${prefixStr}chemicals_export_${dateStr}_$timeStr.$format';
  }

  /// Get filtered chemicals query
  static Future<QuerySnapshot> _getFilteredChemicals({
    String? manufacturerFilter,
    String? statusFilter,
    String? searchQuery,
  }) async {
    Query query = FirebaseFirestore.instance.collection('chemicals');

    // Apply manufacturer filter
    if (manufacturerFilter != null && manufacturerFilter != 'All') {
      query = query.where('manufacturer', isEqualTo: manufacturerFilter);
    }

    // Apply search filter
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query
          .where('nameLowercase', isGreaterThanOrEqualTo: searchQuery.toLowerCase())
          .where('nameLowercase', isLessThanOrEqualTo: '${searchQuery.toLowerCase()}\uf8ff');
    }

    // Order by name for consistent results
    query = query.orderBy('name');

    return await query.get();
  }

  /// Download file for web platform
  static Future<void> _downloadForWeb(String content, String filename, String mimeType) async {
    // This would require additional web-specific implementation
    // For now, we'll throw an error to indicate web support is needed
    throw UnimplementedError('Web download not implemented. Please use mobile app for export functionality.');
  }





  /// Parse and format date from various input types (Timestamp, int, String, DateTime)
  static String _parseAndFormatDate(dynamic dateValue) {
    try {
      DateTime? date;
      
      if (dateValue is Timestamp) {
        date = dateValue.toDate();
      } else if (dateValue is int) {
        // Handle milliseconds since epoch
        date = DateTime.fromMillisecondsSinceEpoch(dateValue);
      } else if (dateValue is double) {
        // Handle seconds since epoch (convert to milliseconds)
        date = DateTime.fromMillisecondsSinceEpoch((dateValue * 1000).round());
      } else if (dateValue is String) {
        date = DateTime.tryParse(dateValue);
      } else if (dateValue is DateTime) {
        date = dateValue;
      }
      
      if (date != null) {
        // Use a simple, readable format that Excel handles well
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
      
      return 'Invalid Date';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  /// Parse and format datetime from various input types
  static String _parseAndFormatDateTime(dynamic dateValue) {
    try {
      DateTime? date;
      
      if (dateValue is Timestamp) {
        date = dateValue.toDate();
      } else if (dateValue is int) {
        // Handle milliseconds since epoch
        date = DateTime.fromMillisecondsSinceEpoch(dateValue);
      } else if (dateValue is double) {
        // Handle seconds since epoch (convert to milliseconds)
        date = DateTime.fromMillisecondsSinceEpoch((dateValue * 1000).round());
      } else if (dateValue is String) {
        date = DateTime.tryParse(dateValue);
      } else if (dateValue is DateTime) {
        date = dateValue;
      }
      
      if (date != null) {
        // Use a simple, readable format that Excel handles well
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
      
      return 'Invalid DateTime';
    } catch (e) {
      return 'Invalid DateTime';
    }
  }





  /// Recursively clean Timestamp objects from a Map for JSON serialization
  static Map<String, dynamic> _cleanTimestampsFromMap(Map<String, dynamic> data) {
    final cleanedData = <String, dynamic>{};
    
    for (final entry in data.entries) {
      cleanedData[entry.key] = _cleanTimestampsFromValue(entry.value);
    }
    
    return cleanedData;
  }
  
  /// Clean Timestamp objects from any value (recursive for nested structures)
  static dynamic _cleanTimestampsFromValue(dynamic value) {
    if (value == null) {
      return null;
    } else if (value is Timestamp) {
      try {
        return value.toDate().toIso8601String();
      } catch (e) {
        return null;
      }
    } else if (value is Map<String, dynamic>) {
      return _cleanTimestampsFromMap(value);
    } else if (value is List) {
      return value.map((item) => _cleanTimestampsFromValue(item)).toList();
    } else {
      return value;
    }
  }

  /// Get status text for export
  static String _getStatusText(ExpiryStatus expiryStatus, bool isLowStock) {
    if (isLowStock) return 'Low Stock';
    
    switch (expiryStatus) {
      case ExpiryStatus.expired:
        return 'Expired';
      case ExpiryStatus.nearExpiry:
        return 'Expires Soon';
      case ExpiryStatus.good:
        return 'Good';
      default:
        return 'Unknown';
    }
  }
}

enum ExportFormat {
  csv,
  json,
}

class ExportOptions {
  final ExportFormat format;
  final String? manufacturerFilter;
  final String? statusFilter;
  final String? searchQuery;
  final String? customPrefix;

  const ExportOptions({
    required this.format,
    this.manufacturerFilter,
    this.statusFilter,
    this.searchQuery,
    this.customPrefix,
  });
}