import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class CustomerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'customers';
  
  /// Get customers with pagination and optional filters
  static Stream<QuerySnapshot> getCustomers({
    int limit = 20,
    DocumentSnapshot? startAfter,
    String? searchQuery,
  }) {
    Query query = _firestore.collection(_collection);
    
    // Order by company name for consistent pagination
    query = query.orderBy('companyName');
    
    // Pagination
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    
    return query.limit(limit).snapshots();
  }
  
  /// Search customers by company name or contact name
  static Future<List<Map<String, dynamic>>> searchCustomers(String searchQuery) async {
    try {
      final snapshot = await _firestore.collection(_collection).get();
      
      final customers = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      if (searchQuery.isEmpty) return customers;
      
      return customers.where((customer) {
        final companyName = (customer['companyName'] as String? ?? '').toLowerCase();
        final contactName = (customer['contactName'] as String? ?? '').toLowerCase();
        final query = searchQuery.toLowerCase();
        
        return companyName.contains(query) || contactName.contains(query);
      }).toList();
    } catch (e) {
      debugPrint('Error searching customers: $e');
      rethrow;
    }
  }
  
  /// Get single customer by ID
  static Future<DocumentSnapshot> getCustomer(String id) {
    return _firestore.collection(_collection).doc(id).get();
  }
  
  /// Create new customer
  static Future<String> createCustomer(Map<String, dynamic> customerData) async {
    try {
      // Add metadata
      customerData['createdAt'] = FieldValue.serverTimestamp();
      customerData['updatedAt'] = FieldValue.serverTimestamp();
      customerData['portalAccess'] = customerData['portalAccess'] ?? true;
      customerData['billingRate'] = customerData['billingRate'] ?? {'GPA2261': 2000.0};
      customerData['audit'] = [
        {
          'action': 'created',
          'timestamp': FieldValue.serverTimestamp(),
          'userId': customerData['createdBy'] ?? 'system',
          'details': 'Customer created',
        }
      ];
      
      final docRef = await _firestore.collection(_collection).add(customerData);
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating customer: $e');
      rethrow;
    }
  }
  
  /// Update customer information
  static Future<void> updateCustomer(String customerId, Map<String, dynamic> updates, {
    String? updatedBy,
  }) async {
    try {
      final auditEntry = {
        'action': 'updated',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': updatedBy ?? 'system',
        'details': 'Customer information updated',
      };
      
      updates['updatedAt'] = FieldValue.serverTimestamp();
      updates['audit'] = FieldValue.arrayUnion([auditEntry]);
      
      await _firestore.collection(_collection).doc(customerId).update(updates);
    } catch (e) {
      debugPrint('Error updating customer: $e');
      rethrow;
    }
  }
  
  /// Update customer billing rates
  static Future<void> updateBillingRates(String customerId, Map<String, double> billingRates, {
    String? updatedBy,
  }) async {
    try {
      final auditEntry = {
        'action': 'billing_rates_updated',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': updatedBy ?? 'system',
        'details': 'Customer billing rates updated',
        'newRates': billingRates,
      };
      
      await _firestore.collection(_collection).doc(customerId).update({
        'billingRate': billingRates,
        'updatedAt': FieldValue.serverTimestamp(),
        'audit': FieldValue.arrayUnion([auditEntry]),
      });
    } catch (e) {
      debugPrint('Error updating billing rates: $e');
      rethrow;
    }
  }
  
  /// Get all customers for dropdown/selection
  static Future<List<Map<String, dynamic>>> getAllCustomers() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('companyName')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting all customers: $e');
      return [];
    }
  }
  
  /// Get customer statistics
  static Future<Map<String, dynamic>> getCustomerStats(String customerId) async {
    try {
      // Get sample count
      final samplesSnapshot = await _firestore
          .collection('samples')
          .where('customerId', isEqualTo: customerId)
          .get();
      
      // Get invoice count and total amount
      final invoicesSnapshot = await _firestore
          .collection('invoices')
          .where('customerId', isEqualTo: customerId)
          .get();
      
      double totalBilled = 0.0;
      double totalPaid = 0.0;
      int paidInvoices = 0;
      
      for (final doc in invoicesSnapshot.docs) {
        final data = doc.data();
        final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        totalBilled += amount;
        
        if (data['status'] == 'paid') {
          totalPaid += amount;
          paidInvoices++;
        }
      }
      
      return {
        'totalSamples': samplesSnapshot.docs.length,
        'totalInvoices': invoicesSnapshot.docs.length,
        'paidInvoices': paidInvoices,
        'totalBilled': totalBilled,
        'totalPaid': totalPaid,
        'outstandingAmount': totalBilled - totalPaid,
      };
    } catch (e) {
      debugPrint('Error getting customer stats: $e');
      return {};
    }
  }
}

/// Customer model class
class Customer {
  final String id;
  final String companyName;
  final String contactName;
  final String email;
  final String? phone;
  final Map<String, double> billingRate;
  final String preferredInvoiceFormat;
  final bool portalAccess;
  final List<Map<String, dynamic>> audit;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  
  Customer({
    required this.id,
    required this.companyName,
    required this.contactName,
    required this.email,
    this.phone,
    required this.billingRate,
    required this.preferredInvoiceFormat,
    required this.portalAccess,
    required this.audit,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory Customer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Customer(
      id: doc.id,
      companyName: data['companyName'] ?? '',
      contactName: data['contactName'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'],
      billingRate: Map<String, double>.from(data['billingRate'] ?? {'GPA2261': 2000.0}),
      preferredInvoiceFormat: data['preferredInvoiceFormat'] ?? 'pdf',
      portalAccess: data['portalAccess'] ?? true,
      audit: List<Map<String, dynamic>>.from(data['audit'] ?? []),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'companyName': companyName,
      'contactName': contactName,
      'email': email,
      'phone': phone,
      'billingRate': billingRate,
      'preferredInvoiceFormat': preferredInvoiceFormat,
      'portalAccess': portalAccess,
      'audit': audit,
    };
  }
}