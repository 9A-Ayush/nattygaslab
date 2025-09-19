import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ReportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'reports';
  
  /// Get reports with pagination and optional filters
  /// Firestore Index Required: reports (status, createdAt), (reviewedBy, status)
  static Stream<QuerySnapshot> getReports({
    int limit = 20,
    DocumentSnapshot? startAfter,
    String? statusFilter,
    String? reviewerFilter,
    String? customerFilter,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query = _firestore.collection(_collection);
    
    // Apply filters
    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.where('status', isEqualTo: statusFilter);
    }
    
    if (reviewerFilter != null && reviewerFilter.isNotEmpty) {
      query = query.where('reviewedBy', isEqualTo: reviewerFilter);
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
  
  /// Get single report by ID
  static Future<DocumentSnapshot> getReport(String id) {
    return _firestore.collection(_collection).doc(id).get();
  }
  
  /// Get report by sample ID
  static Future<DocumentSnapshot?> getReportBySampleId(String sampleId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('sampleId', isEqualTo: sampleId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting report by sample ID: $e');
      rethrow;
    }
  }
  
  /// Create new report from sample
  static Future<String> createReport(String sampleId, Map<String, dynamic> reportData) async {
    try {
      // Add metadata
      reportData['sampleId'] = sampleId;
      reportData['status'] = 'draft';
      reportData['createdAt'] = FieldValue.serverTimestamp();
      reportData['updatedAt'] = FieldValue.serverTimestamp();
      reportData['revisions'] = [];
      reportData['audit'] = [
        {
          'action': 'created',
          'timestamp': FieldValue.serverTimestamp(),
          'userId': reportData['createdBy'] ?? 'system',
          'details': 'Report created from sample analysis',
        }
      ];
      
      final docRef = await _firestore.collection(_collection).add(reportData);
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating report: $e');
      rethrow;
    }
  }
  
  /// Submit report for review
  static Future<void> submitForReview(String reportId, {
    String? submittedBy,
    String? comments,
  }) async {
    try {
      final auditEntry = {
        'action': 'submitted_for_review',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': submittedBy ?? 'system',
        'details': 'Report submitted for supervisor review',
        'comments': comments,
      };
      
      await _firestore.collection(_collection).doc(reportId).update({
        'status': 'pending_review',
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'audit': FieldValue.arrayUnion([auditEntry]),
      });
    } catch (e) {
      debugPrint('Error submitting report for review: $e');
      rethrow;
    }
  }
  
  /// Approve report
  static Future<void> approveReport(String reportId, String reviewerId, {
    String? comments,
  }) async {
    try {
      final auditEntry = {
        'action': 'approved',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': reviewerId,
        'details': 'Report approved by supervisor',
        'comments': comments,
      };
      
      await _firestore.collection(_collection).doc(reportId).update({
        'status': 'approved',
        'reviewedBy': reviewerId,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'reviewComments': comments,
        'audit': FieldValue.arrayUnion([auditEntry]),
      });
      
      // TODO: Trigger PDF generation Cloud Function
      // await _generatePDF(reportId);
      
    } catch (e) {
      debugPrint('Error approving report: $e');
      rethrow;
    }
  }
  
  /// Reject report with reason
  static Future<void> rejectReport(String reportId, String reviewerId, String reason, {
    String? comments,
  }) async {
    try {
      final auditEntry = {
        'action': 'rejected',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': reviewerId,
        'details': 'Report rejected by supervisor',
        'reason': reason,
        'comments': comments,
      };
      
      await _firestore.collection(_collection).doc(reportId).update({
        'status': 'rejected',
        'reviewedBy': reviewerId,
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason,
        'reviewComments': comments,
        'audit': FieldValue.arrayUnion([auditEntry]),
      });
    } catch (e) {
      debugPrint('Error rejecting report: $e');
      rethrow;
    }
  }
  
  /// Generate PDF report
  /// TODO: In production, this calls a Cloud Function
  static Future<String> generatePDF(String reportId) async {
    try {
      // In production, this would call a Cloud Function:
      // final result = await FirebaseFunctions.instance
      //     .httpsCallable('generateReportPDF')
      //     .call({'reportId': reportId});
      
      final auditEntry = {
        'action': 'pdf_generated',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': 'system',
        'details': 'PDF report generated',
      };
      
      // Mock PDF URL for demo
      final pdfUrl = 'https://storage.googleapis.com/reports/report_$reportId.pdf';
      
      await _firestore.collection(_collection).doc(reportId).update({
        'pdfUrl': pdfUrl,
        'pdfGeneratedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'audit': FieldValue.arrayUnion([auditEntry]),
      });
      
      return pdfUrl;
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      rethrow;
    }
  }
  
  /// Send report to customer
  /// TODO: In production, this calls a Cloud Function for email delivery
  static Future<void> sendToCustomer(String reportId, {
    String? sentBy,
    String? customerEmail,
  }) async {
    try {
      // In production, this would call a Cloud Function:
      // await FirebaseFunctions.instance
      //     .httpsCallable('sendReportToCustomer')
      //     .call({'reportId': reportId, 'customerEmail': customerEmail});
      
      final auditEntry = {
        'action': 'sent_to_customer',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': sentBy ?? 'system',
        'details': 'Report sent to customer',
        'customerEmail': customerEmail,
      };
      
      await _firestore.collection(_collection).doc(reportId).update({
        'status': 'delivered',
        'sentToCustomerAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'audit': FieldValue.arrayUnion([auditEntry]),
      });
    } catch (e) {
      debugPrint('Error sending report to customer: $e');
      rethrow;
    }
  }
  
  /// Create report revision
  static Future<void> createRevision(String reportId, Map<String, dynamic> revisionData, {
    String? revisedBy,
  }) async {
    try {
      final revision = {
        'revisionNumber': revisionData['revisionNumber'] ?? 1,
        'changes': revisionData['changes'],
        'reason': revisionData['reason'],
        'revisedBy': revisedBy ?? 'system',
        'revisedAt': FieldValue.serverTimestamp(),
      };
      
      final auditEntry = {
        'action': 'revision_created',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': revisedBy ?? 'system',
        'details': 'Report revision created',
        'revisionNumber': revision['revisionNumber'],
      };
      
      await _firestore.collection(_collection).doc(reportId).update({
        'status': 'draft',
        'currentRevision': revision['revisionNumber'],
        'updatedAt': FieldValue.serverTimestamp(),
        'revisions': FieldValue.arrayUnion([revision]),
        'audit': FieldValue.arrayUnion([auditEntry]),
      });
    } catch (e) {
      debugPrint('Error creating revision: $e');
      rethrow;
    }
  }
  
  /// Get reports pending review
  static Future<List<Map<String, dynamic>>> getReportsPendingReview() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'pending_review')
          .orderBy('submittedAt', descending: false) // Oldest first
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting reports pending review: $e');
      return [];
    }
  }
  
  /// Get report status counts for dashboard
  static Future<Map<String, int>> getReportStatusCounts() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();
      final statusCounts = <String, int>{};
      
      for (final doc in snapshot.docs) {
        final status = doc.data()['status'] as String? ?? 'unknown';
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }
      
      return statusCounts;
    } catch (e) {
      debugPrint('Error getting report status counts: $e');
      return {};
    }
  }
  
  /// Get available report statuses
  static List<String> getReportStatuses() {
    return [
      'draft',
      'pending_review',
      'approved',
      'rejected',
      'delivered'
    ];
  }
  
  /// Update report data
  static Future<void> updateReport(String reportId, Map<String, dynamic> updates, {
    String? updatedBy,
  }) async {
    try {
      final auditEntry = {
        'action': 'updated',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': updatedBy ?? 'system',
        'details': 'Report information updated',
      };
      
      updates['updatedAt'] = FieldValue.serverTimestamp();
      updates['audit'] = FieldValue.arrayUnion([auditEntry]);
      
      await _firestore.collection(_collection).doc(reportId).update(updates);
    } catch (e) {
      debugPrint('Error updating report: $e');
      rethrow;
    }
  }
}

/// Report model class
class Report {
  final String id;
  final String sampleId;
  final String status;
  final String? reviewedBy;
  final String? comments;
  final String? pdfUrl;
  final String? rejectionReason;
  final List<Map<String, dynamic>> revisions;
  final List<Map<String, dynamic>> audit;
  final Timestamp createdAt;
  final Timestamp? approvedAt;
  final Timestamp? rejectedAt;
  final Timestamp updatedAt;
  
  Report({
    required this.id,
    required this.sampleId,
    required this.status,
    this.reviewedBy,
    this.comments,
    this.pdfUrl,
    this.rejectionReason,
    required this.revisions,
    required this.audit,
    required this.createdAt,
    this.approvedAt,
    this.rejectedAt,
    required this.updatedAt,
  });
  
  factory Report.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Report(
      id: doc.id,
      sampleId: data['sampleId'] ?? '',
      status: data['status'] ?? 'draft',
      reviewedBy: data['reviewedBy'],
      comments: data['reviewComments'],
      pdfUrl: data['pdfUrl'],
      rejectionReason: data['rejectionReason'],
      revisions: List<Map<String, dynamic>>.from(data['revisions'] ?? []),
      audit: List<Map<String, dynamic>>.from(data['audit'] ?? []),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      approvedAt: data['approvedAt'],
      rejectedAt: data['rejectedAt'],
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'sampleId': sampleId,
      'status': status,
      'reviewedBy': reviewedBy,
      'reviewComments': comments,
      'pdfUrl': pdfUrl,
      'rejectionReason': rejectionReason,
      'revisions': revisions,
      'audit': audit,
    };
  }
}