import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class InvoiceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'invoices';
  
  /// Get invoices with pagination and optional filters
  /// Firestore Index Required: invoices (status, createdAt), (customerId, status)
  static Stream<QuerySnapshot> getInvoices({
    int limit = 20,
    DocumentSnapshot? startAfter,
    String? statusFilter,
    String? customerFilter,
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
  
  /// Get single invoice by ID
  static Future<DocumentSnapshot> getInvoice(String id) {
    return _firestore.collection(_collection).doc(id).get();
  }
  
  /// Generate invoice for customer and samples
  /// TODO: In production, use Cloud Function for rate calculation and PDF generation
  static Future<String> generateInvoice(String customerId, List<String> sampleIds, {
    String? generatedBy,
    Map<String, double>? customRates,
  }) async {
    try {
      // Get customer information for billing rates
      final customerDoc = await _firestore.collection('customers').doc(customerId).get();
      final customerData = customerDoc.data() ?? {};
      final billingRates = Map<String, double>.from(customerData['billingRate'] ?? {'GPA2261': 2000.0});
      
      // Calculate total amount based on samples
      double totalAmount = 0.0;
      final lineItems = <Map<String, dynamic>>[];
      
      for (final sampleId in sampleIds) {
        final sampleDoc = await _firestore.collection('samples').doc(sampleId).get();
        final sampleData = sampleDoc.data() ?? {};
        final analysisType = sampleData['analysisType'] as String? ?? 'GPA2261';
        final rate = customRates?[analysisType] ?? billingRates[analysisType] ?? 2000.0;
        
        lineItems.add({
          'sampleId': sampleId,
          'reportNo': sampleData['reportNo'] ?? '',
          'analysisType': analysisType,
          'description': sampleData['sampleDescription'] ?? '',
          'rate': rate,
          'quantity': 1,
          'amount': rate,
        });
        
        totalAmount += rate;
      }
      
      // Generate invoice number
      final invoiceNo = await _generateInvoiceNumber();
      
      final invoiceData = {
        'invoiceNo': invoiceNo,
        'customerId': customerId,
        'sampleIds': sampleIds,
        'lineItems': lineItems,
        'subtotal': totalAmount,
        'tax': 0.0, // Add tax calculation if needed
        'totalAmount': totalAmount,
        'status': 'draft',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'generatedBy': generatedBy ?? 'system',
        'audit': [
          {
            'action': 'generated',
            'timestamp': FieldValue.serverTimestamp(),
            'userId': generatedBy ?? 'system',
            'details': 'Invoice generated for ${sampleIds.length} samples',
          }
        ],
      };
      
      final docRef = await _firestore.collection(_collection).add(invoiceData);
      return docRef.id;
    } catch (e) {
      debugPrint('Error generating invoice: $e');
      rethrow;
    }
  }
  
  /// Send invoice to customer
  /// TODO: In production, use Cloud Function for PDF generation and email delivery
  static Future<void> sendInvoice(String invoiceId, {
    String? sentBy,
    String? customerEmail,
  }) async {
    try {
      // In production, this would call a Cloud Function:
      // await FirebaseFunctions.instance
      //     .httpsCallable('sendInvoice')
      //     .call({'invoiceId': invoiceId, 'customerEmail': customerEmail});
      
      final auditEntry = {
        'action': 'sent',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': sentBy ?? 'system',
        'details': 'Invoice sent to customer',
        'customerEmail': customerEmail,
      };
      
      // Mock PDF URL for demo
      final pdfUrl = 'https://storage.googleapis.com/invoices/invoice_$invoiceId.pdf';
      
      await _firestore.collection(_collection).doc(invoiceId).update({
        'status': 'sent',
        'pdfUrl': pdfUrl,
        'sentAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'audit': FieldValue.arrayUnion([auditEntry]),
      });
    } catch (e) {
      debugPrint('Error sending invoice: $e');
      rethrow;
    }
  }
  
  /// Mark invoice as paid
  static Future<void> markAsPaid(String invoiceId, Map<String, dynamic> paymentDetails, {
    String? recordedBy,
  }) async {
    try {
      final auditEntry = {
        'action': 'payment_recorded',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': recordedBy ?? 'system',
        'details': 'Payment recorded',
        'paymentMethod': paymentDetails['method'],
        'amount': paymentDetails['amount'],
      };
      
      await _firestore.collection(_collection).doc(invoiceId).update({
        'status': 'paid',
        'paymentDetails': paymentDetails,
        'paidAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'audit': FieldValue.arrayUnion([auditEntry]),
      });
    } catch (e) {
      debugPrint('Error marking invoice as paid: $e');
      rethrow;
    }
  }
  
  /// Mark invoice as overdue
  static Future<void> markAsOverdue(String invoiceId, {
    String? markedBy,
  }) async {
    try {
      final auditEntry = {
        'action': 'marked_overdue',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': markedBy ?? 'system',
        'details': 'Invoice marked as overdue',
      };
      
      await _firestore.collection(_collection).doc(invoiceId).update({
        'status': 'overdue',
        'overdueAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'audit': FieldValue.arrayUnion([auditEntry]),
      });
    } catch (e) {
      debugPrint('Error marking invoice as overdue: $e');
      rethrow;
    }
  }
  
  /// Apply discount to invoice
  static Future<void> applyDiscount(String invoiceId, double discountAmount, String reason, {
    String? appliedBy,
  }) async {
    try {
      final invoiceDoc = await _firestore.collection(_collection).doc(invoiceId).get();
      final invoiceData = invoiceDoc.data() ?? {};
      final subtotal = (invoiceData['subtotal'] as num?)?.toDouble() ?? 0.0;
      final newTotal = subtotal - discountAmount;
      
      final auditEntry = {
        'action': 'discount_applied',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': appliedBy ?? 'system',
        'details': 'Discount applied',
        'discountAmount': discountAmount,
        'reason': reason,
      };
      
      await _firestore.collection(_collection).doc(invoiceId).update({
        'discountAmount': discountAmount,
        'discountReason': reason,
        'totalAmount': newTotal,
        'updatedAt': FieldValue.serverTimestamp(),
        'audit': FieldValue.arrayUnion([auditEntry]),
      });
    } catch (e) {
      debugPrint('Error applying discount: $e');
      rethrow;
    }
  }
  
  /// Run monthly invoicing automation
  /// TODO: In production, this would be a Cloud Function triggered by Cloud Scheduler
  static Future<void> runMonthlyInvoicing() async {
    try {
      // Get all completed samples from previous month that haven't been invoiced
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      final endOfLastMonth = DateTime(now.year, now.month, 0);
      
      final samplesSnapshot = await _firestore
          .collection('samples')
          .where('status', isEqualTo: 'reported')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(lastMonth))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfLastMonth))
          .get();
      
      // Group samples by customer
      final customerSamples = <String, List<String>>{};
      for (final doc in samplesSnapshot.docs) {
        final customerId = doc.data()['customerId'] as String;
        customerSamples.putIfAbsent(customerId, () => []).add(doc.id);
      }
      
      // Generate invoices for each customer
      for (final entry in customerSamples.entries) {
        await generateInvoice(entry.key, entry.value, generatedBy: 'monthly_automation');
      }
      
      debugPrint('Monthly invoicing completed: ${customerSamples.length} invoices generated');
    } catch (e) {
      debugPrint('Error running monthly invoicing: $e');
      rethrow;
    }
  }
  
  /// Get overdue invoices
  static Future<List<Map<String, dynamic>>> getOverdueInvoices() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'sent')
          .where('sentAt', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting overdue invoices: $e');
      return [];
    }
  }
  
  /// Get invoice status counts for dashboard
  static Future<Map<String, int>> getInvoiceStatusCounts() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();
      final statusCounts = <String, int>{};
      
      for (final doc in snapshot.docs) {
        final status = doc.data()['status'] as String? ?? 'unknown';
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }
      
      return statusCounts;
    } catch (e) {
      debugPrint('Error getting invoice status counts: $e');
      return {};
    }
  }
  
  /// Get monthly revenue
  static Future<double> getMonthlyRevenue({DateTime? month}) async {
    try {
      final targetMonth = month ?? DateTime.now();
      final startOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);
      final endOfMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0);
      
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'paid')
          .where('paidAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('paidAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();
      
      double totalRevenue = 0.0;
      for (final doc in snapshot.docs) {
        final amount = (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0.0;
        totalRevenue += amount;
      }
      
      return totalRevenue;
    } catch (e) {
      debugPrint('Error getting monthly revenue: $e');
      return 0.0;
    }
  }
  
  /// Generate unique invoice number
  static Future<String> _generateInvoiceNumber() async {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    
    // Get count of invoices this month for sequential numbering
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    
    final snapshot = await _firestore
        .collection(_collection)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .get();
    
    final count = snapshot.docs.length + 1;
    final sequence = count.toString().padLeft(3, '0');
    
    return 'INV-$year$month-$sequence';
  }
  
  /// Get available invoice statuses
  static List<String> getInvoiceStatuses() {
    return [
      'draft',
      'sent',
      'paid',
      'overdue',
      'cancelled'
    ];
  }
  
  /// Update invoice
  static Future<void> updateInvoice(String invoiceId, Map<String, dynamic> updates, {
    String? updatedBy,
  }) async {
    try {
      final auditEntry = {
        'action': 'updated',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': updatedBy ?? 'system',
        'details': 'Invoice information updated',
      };
      
      updates['updatedAt'] = FieldValue.serverTimestamp();
      updates['audit'] = FieldValue.arrayUnion([auditEntry]);
      
      await _firestore.collection(_collection).doc(invoiceId).update(updates);
    } catch (e) {
      debugPrint('Error updating invoice: $e');
      rethrow;
    }
  }
}

/// Invoice model class
class Invoice {
  final String id;
  final String invoiceNo;
  final String customerId;
  final List<String> sampleIds;
  final List<Map<String, dynamic>> lineItems;
  final double subtotal;
  final double tax;
  final double totalAmount;
  final double? discountAmount;
  final String? discountReason;
  final String status;
  final String? pdfUrl;
  final Map<String, dynamic>? paymentDetails;
  final List<Map<String, dynamic>> audit;
  final Timestamp createdAt;
  final Timestamp? sentAt;
  final Timestamp? paidAt;
  final Timestamp updatedAt;
  
  Invoice({
    required this.id,
    required this.invoiceNo,
    required this.customerId,
    required this.sampleIds,
    required this.lineItems,
    required this.subtotal,
    required this.tax,
    required this.totalAmount,
    this.discountAmount,
    this.discountReason,
    required this.status,
    this.pdfUrl,
    this.paymentDetails,
    required this.audit,
    required this.createdAt,
    this.sentAt,
    this.paidAt,
    required this.updatedAt,
  });
  
  factory Invoice.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Invoice(
      id: doc.id,
      invoiceNo: data['invoiceNo'] ?? '',
      customerId: data['customerId'] ?? '',
      sampleIds: List<String>.from(data['sampleIds'] ?? []),
      lineItems: List<Map<String, dynamic>>.from(data['lineItems'] ?? []),
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
      tax: (data['tax'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (data['discountAmount'] as num?)?.toDouble(),
      discountReason: data['discountReason'],
      status: data['status'] ?? 'draft',
      pdfUrl: data['pdfUrl'],
      paymentDetails: data['paymentDetails'],
      audit: List<Map<String, dynamic>>.from(data['audit'] ?? []),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      sentAt: data['sentAt'],
      paidAt: data['paidAt'],
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'invoiceNo': invoiceNo,
      'customerId': customerId,
      'sampleIds': sampleIds,
      'lineItems': lineItems,
      'subtotal': subtotal,
      'tax': tax,
      'totalAmount': totalAmount,
      'discountAmount': discountAmount,
      'discountReason': discountReason,
      'status': status,
      'pdfUrl': pdfUrl,
      'paymentDetails': paymentDetails,
      'audit': audit,
    };
  }
}