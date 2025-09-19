import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class SampleService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'samples';
  
  /// Get samples with pagination and optional filters
  /// Firestore Index Required: samples (status, createdAt), (customerId, createdAt), (assignedTo, status)
  static Stream<QuerySnapshot> getSamples({
    int limit = 20,
    DocumentSnapshot? startAfter,
    String? statusFilter,
    String? customerFilter,
    String? assignedToFilter,
    String? analysisTypeFilter,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query = _firestore.collection(_collection);
    
    // Apply filters
    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.where('status', isEqualTo: statusFilter);
    }
    
    if (customerFilter != null && customerFilter.isNotEmpty) {
      query = query.where('customerId', isEqualTo: customerFilter);
    }
    
    if (assignedToFilter != null && assignedToFilter.isNotEmpty) {
      query = query.where('assignedTo', isEqualTo: assignedToFilter);
    }
    
    if (analysisTypeFilter != null && analysisTypeFilter.isNotEmpty) {
      query = query.where('analysisType', isEqualTo: analysisTypeFilter);
    }
    
    // Date range filter
    if (startDate != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    
    if (endDate != null) {
      query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }
    
    // Order by creation date (newest first)
    query = query.orderBy('createdAt', descending: true);
    
    // Pagination
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    
    return query.limit(limit).snapshots();
  }
  
  /// Search samples by report number or description
  static Future<List<Map<String, dynamic>>> searchSamples(String searchQuery) async {
    try {
      final snapshot = await _firestore.collection(_collection).get();
      
      final samples = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      if (searchQuery.isEmpty) return samples;
      
      return samples.where((sample) {
        final reportNo = (sample['reportNo'] as String? ?? '').toLowerCase();
        final description = (sample['sampleDescription'] as String? ?? '').toLowerCase();
        final query = searchQuery.toLowerCase();
        
        return reportNo.contains(query) || description.contains(query);
      }).toList();
    } catch (e) {
      debugPrint('Error searching samples: $e');
      rethrow;
    }
  }
  
  /// Get single sample by ID
  static Future<DocumentSnapshot> getSample(String id) {
    return _firestore.collection(_collection).doc(id).get();
  }
  
  /// Create new sample
  /// TODO: In production, use Cloud Function for report number generation and validation
  static Future<String> createSample(Map<String, dynamic> sampleData) async {
    try {
      // Generate unique report number
      final reportNo = await _generateReportNumber();
      
      // Add metadata
      sampleData['reportNo'] = reportNo;
      sampleData['status'] = 'received';
      sampleData['createdAt'] = FieldValue.serverTimestamp();
      sampleData['updatedAt'] = FieldValue.serverTimestamp();
      sampleData['audit'] = [
        {
          'action': 'created',
          'timestamp': FieldValue.serverTimestamp(),
          'userId': sampleData['createdBy'] ?? 'system',
          'details': 'Sample created',
        }
      ];
      
      final docRef = await _firestore.collection(_collection).add(sampleData);
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating sample: $e');
      rethrow;
    }
  }
  
  /// Update sample status with audit trail
  static Future<void> updateSampleStatus(String sampleId, String newStatus, {
    String? userId,
    String? comments,
  }) async {
    try {
      final auditEntry = {
        'action': 'status_changed',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': userId ?? 'system',
        'details': 'Status changed to $newStatus',
        'comments': comments,
      };
      
      await _firestore.collection(_collection).doc(sampleId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'audit': FieldValue.arrayUnion([auditEntry]),
      });
    } catch (e) {
      debugPrint('Error updating sample status: $e');
      rethrow;
    }
  }
  
  /// Assign sample to technician
  static Future<void> assignSample(String sampleId, String technicianId, {
    String? assignedBy,
    String? comments,
  }) async {
    try {
      final auditEntry = {
        'action': 'assigned',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': assignedBy ?? 'system',
        'details': 'Sample assigned to technician',
        'assignedTo': technicianId,
        'comments': comments,
      };
      
      await _firestore.collection(_collection).doc(sampleId).update({
        'assignedTo': technicianId,
        'status': 'queued',
        'updatedAt': FieldValue.serverTimestamp(),
        'audit': FieldValue.arrayUnion([auditEntry]),
      });
    } catch (e) {
      debugPrint('Error assigning sample: $e');
      rethrow;
    }
  }
  
  /// Upload analysis results
  /// TODO: In production, use Cloud Function for Excel parsing and validation
  static Future<void> uploadResults(String sampleId, File excelFile, {
    String? uploadedBy,
    Map<String, dynamic>? analysisResults,
  }) async {
    try {
      // In production, this would upload to Cloud Storage and call Cloud Function for parsing
      final auditEntry = {
        'action': 'results_uploaded',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': uploadedBy ?? 'system',
        'details': 'Analysis results uploaded',
        'fileName': excelFile.path.split('/').last,
      };
      
      final updateData = {
        'status': 'analyzed',
        'updatedAt': FieldValue.serverTimestamp(),
        'audit': FieldValue.arrayUnion([auditEntry]),
      };
      
      if (analysisResults != null) {
        updateData['analysisResults'] = analysisResults;
      }
      
      await _firestore.collection(_collection).doc(sampleId).update(updateData);
    } catch (e) {
      debugPrint('Error uploading results: $e');
      rethrow;
    }
  }
  
  /// Update sample data
  static Future<void> updateSample(String sampleId, Map<String, dynamic> updates, {
    String? updatedBy,
  }) async {
    try {
      final auditEntry = {
        'action': 'updated',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': updatedBy ?? 'system',
        'details': 'Sample information updated',
      };
      
      updates['updatedAt'] = FieldValue.serverTimestamp();
      updates['audit'] = FieldValue.arrayUnion([auditEntry]);
      
      await _firestore.collection(_collection).doc(sampleId).update(updates);
    } catch (e) {
      debugPrint('Error updating sample: $e');
      rethrow;
    }
  }
  
  /// Get samples by status for dashboard metrics
  static Future<Map<String, int>> getSampleStatusCounts() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();
      final statusCounts = <String, int>{};
      
      for (final doc in snapshot.docs) {
        final status = doc.data()['status'] as String? ?? 'unknown';
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }
      
      return statusCounts;
    } catch (e) {
      debugPrint('Error getting sample status counts: $e');
      return {};
    }
  }
  
  /// Get overdue samples (in analysis for more than 7 days)
  static Future<List<Map<String, dynamic>>> getOverdueSamples() async {
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', whereIn: ['queued', 'in_analysis'])
          .where('createdAt', isLessThan: Timestamp.fromDate(sevenDaysAgo))
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting overdue samples: $e');
      return [];
    }
  }
  
  /// Generate unique report number
  static Future<String> _generateReportNumber() async {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    
    // Get count of samples this month for sequential numbering
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    
    final snapshot = await _firestore
        .collection(_collection)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .get();
    
    final count = snapshot.docs.length + 1;
    final sequence = count.toString().padLeft(3, '0');
    
    return 'NGL-$year$month-$sequence';
  }
  
  /// Get available analysis types
  static List<String> getAnalysisTypes() {
    return ['GPA2261', 'Custom Analysis', 'Extended Analysis'];
  }
  
  /// Get available sample statuses
  static List<String> getSampleStatuses() {
    return [
      'received',
      'queued',
      'in_analysis',
      'analyzed',
      'review_pending',
      'reported',
      'invoiced'
    ];
  }
}

/// Sample model class
class Sample {
  final String id;
  final String reportNo;
  final String customerId;
  final String? cylinderId;
  final String analysisType;
  final String sampleDescription;
  final String? sampledBy;
  final Timestamp? sampleDate;
  final Timestamp dateReceived;
  final String status;
  final String? tagImageUrl;
  final String? gcResultsFileUrl;
  final Map<String, dynamic>? analysisResults;
  final String? assignedTo;
  final List<Map<String, dynamic>> audit;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  
  Sample({
    required this.id,
    required this.reportNo,
    required this.customerId,
    this.cylinderId,
    required this.analysisType,
    required this.sampleDescription,
    this.sampledBy,
    this.sampleDate,
    required this.dateReceived,
    required this.status,
    this.tagImageUrl,
    this.gcResultsFileUrl,
    this.analysisResults,
    this.assignedTo,
    required this.audit,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory Sample.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Sample(
      id: doc.id,
      reportNo: data['reportNo'] ?? '',
      customerId: data['customerId'] ?? '',
      cylinderId: data['cylinderId'],
      analysisType: data['analysisType'] ?? '',
      sampleDescription: data['sampleDescription'] ?? '',
      sampledBy: data['sampledBy'],
      sampleDate: data['sampleDate'],
      dateReceived: data['dateReceived'] ?? Timestamp.now(),
      status: data['status'] ?? 'received',
      tagImageUrl: data['tagImageUrl'],
      gcResultsFileUrl: data['gcResultsFileUrl'],
      analysisResults: data['analysisResults'],
      assignedTo: data['assignedTo'],
      audit: List<Map<String, dynamic>>.from(data['audit'] ?? []),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'reportNo': reportNo,
      'customerId': customerId,
      'cylinderId': cylinderId,
      'analysisType': analysisType,
      'sampleDescription': sampleDescription,
      'sampledBy': sampledBy,
      'sampleDate': sampleDate,
      'dateReceived': dateReceived,
      'status': status,
      'tagImageUrl': tagImageUrl,
      'gcResultsFileUrl': gcResultsFileUrl,
      'analysisResults': analysisResults,
      'assignedTo': assignedTo,
      'audit': audit,
    };
  }
}