import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class CylinderService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'cylinders';
  
  /// Get cylinders with pagination and optional filters
  /// Firestore Index Required: cylinders (status, lastCheckedOutAt), (currentHolder, status)
  static Stream<QuerySnapshot> getCylinders({
    int limit = 20,
    DocumentSnapshot? startAfter,
    String? statusFilter,
    String? customerFilter,
    String? searchQuery,
  }) {
    Query query = _firestore.collection(_collection);
    
    // Apply filters
    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.where('status', isEqualTo: statusFilter);
    }
    
    if (customerFilter != null && customerFilter.isNotEmpty) {
      query = query.where('currentHolder', isEqualTo: customerFilter);
    }
    
    // Order by last activity (most recent first)
    query = query.orderBy('lastCheckedOutAt', descending: true);
    
    // Pagination
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    
    return query.limit(limit).snapshots();
  }
  
  /// Search cylinders by barcode or serial number
  static Future<List<Map<String, dynamic>>> searchCylinders(String searchQuery) async {
    try {
      final snapshot = await _firestore.collection(_collection).get();
      
      final cylinders = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      if (searchQuery.isEmpty) return cylinders;
      
      return cylinders.where((cylinder) {
        final barcode = (cylinder['barcode'] as String? ?? '').toLowerCase();
        final serial = (cylinder['serial'] as String? ?? '').toLowerCase();
        final query = searchQuery.toLowerCase();
        
        return barcode.contains(query) || serial.contains(query);
      }).toList();
    } catch (e) {
      debugPrint('Error searching cylinders: $e');
      rethrow;
    }
  }
  
  /// Get single cylinder by ID
  static Future<DocumentSnapshot> getCylinder(String id) {
    return _firestore.collection(_collection).doc(id).get();
  }
  
  /// Get cylinder by barcode
  static Future<DocumentSnapshot?> getCylinderByBarcode(String barcode) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('barcode', isEqualTo: barcode)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting cylinder by barcode: $e');
      rethrow;
    }
  }
  
  /// Check out cylinder to customer
  static Future<void> checkOutCylinder(String cylinderId, String customerId, {
    String? checkedOutBy,
    String? notes,
  }) async {
    try {
      final auditEntry = {
        'action': 'checked_out',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': checkedOutBy ?? 'system',
        'customerId': customerId,
        'notes': notes,
      };
      
      await _firestore.collection(_collection).doc(cylinderId).update({
        'status': 'checked_out',
        'currentHolder': customerId,
        'lastCheckedOutAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'audit': FieldValue.arrayUnion([auditEntry]),
      });
    } catch (e) {
      debugPrint('Error checking out cylinder: $e');
      rethrow;
    }
  }
  
  /// Check in cylinder from customer
  static Future<void> checkInCylinder(String cylinderId, {
    String? checkedInBy,
    String? notes,
    String? condition,
  }) async {
    try {
      final auditEntry = {
        'action': 'checked_in',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': checkedInBy ?? 'system',
        'condition': condition,
        'notes': notes,
      };
      
      final updateData = {
        'status': condition == 'needs_cleaning' ? 'pending_cleaning' : 'clean',
        'currentHolder': null,
        'lastCheckedInAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'audit': FieldValue.arrayUnion([auditEntry]),
      };
      
      if (notes != null) {
        updateData['notes'] = notes;
      }
      
      await _firestore.collection(_collection).doc(cylinderId).update(updateData);
    } catch (e) {
      debugPrint('Error checking in cylinder: $e');
      rethrow;
    }
  }
  
  /// Mark cylinder for cleaning
  static Future<void> markForCleaning(String cylinderId, {
    String? markedBy,
    String? reason,
  }) async {
    try {
      final auditEntry = {
        'action': 'marked_for_cleaning',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': markedBy ?? 'system',
        'reason': reason,
      };
      
      await _firestore.collection(_collection).doc(cylinderId).update({
        'status': 'pending_cleaning',
        'updatedAt': FieldValue.serverTimestamp(),
        'audit': FieldValue.arrayUnion([auditEntry]),
      });
    } catch (e) {
      debugPrint('Error marking cylinder for cleaning: $e');
      rethrow;
    }
  }
  
  /// Mark cylinder as cleaned
  static Future<void> markAsCleaned(String cylinderId, {
    String? cleanedBy,
    String? notes,
  }) async {
    try {
      final auditEntry = {
        'action': 'cleaned',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': cleanedBy ?? 'system',
        'notes': notes,
      };
      
      await _firestore.collection(_collection).doc(cylinderId).update({
        'status': 'clean',
        'updatedAt': FieldValue.serverTimestamp(),
        'audit': FieldValue.arrayUnion([auditEntry]),
      });
    } catch (e) {
      debugPrint('Error marking cylinder as cleaned: $e');
      rethrow;
    }
  }
  
  /// Create new cylinder
  static Future<String> createCylinder(Map<String, dynamic> cylinderData) async {
    try {
      // Add metadata
      cylinderData['status'] = 'clean';
      cylinderData['createdAt'] = FieldValue.serverTimestamp();
      cylinderData['updatedAt'] = FieldValue.serverTimestamp();
      cylinderData['audit'] = [
        {
          'action': 'created',
          'timestamp': FieldValue.serverTimestamp(),
          'userId': cylinderData['createdBy'] ?? 'system',
          'details': 'Cylinder added to inventory',
        }
      ];
      
      final docRef = await _firestore.collection(_collection).add(cylinderData);
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating cylinder: $e');
      rethrow;
    }
  }
  
  /// Update cylinder information
  static Future<void> updateCylinder(String cylinderId, Map<String, dynamic> updates, {
    String? updatedBy,
  }) async {
    try {
      final auditEntry = {
        'action': 'updated',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': updatedBy ?? 'system',
        'details': 'Cylinder information updated',
      };
      
      updates['updatedAt'] = FieldValue.serverTimestamp();
      updates['audit'] = FieldValue.arrayUnion([auditEntry]);
      
      await _firestore.collection(_collection).doc(cylinderId).update(updates);
    } catch (e) {
      debugPrint('Error updating cylinder: $e');
      rethrow;
    }
  }
  
  /// Get overdue cylinders (checked out for more than 30 days)
  static Future<List<Map<String, dynamic>>> getOverdueCylinders() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'checked_out')
          .where('lastCheckedOutAt', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting overdue cylinders: $e');
      return [];
    }
  }
  
  /// Get cylinder status counts for dashboard
  static Future<Map<String, int>> getCylinderStatusCounts() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();
      final statusCounts = <String, int>{};
      
      for (final doc in snapshot.docs) {
        final status = doc.data()['status'] as String? ?? 'unknown';
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }
      
      return statusCounts;
    } catch (e) {
      debugPrint('Error getting cylinder status counts: $e');
      return {};
    }
  }
  
  /// Get cylinders needing cleaning
  static Future<List<Map<String, dynamic>>> getCylindersNeedingCleaning() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'pending_cleaning')
          .orderBy('lastCheckedInAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting cylinders needing cleaning: $e');
      return [];
    }
  }
  
  /// Get available cylinder statuses
  static List<String> getCylinderStatuses() {
    return [
      'clean',
      'in_use',
      'checked_out',
      'pending_cleaning',
      'lost'
    ];
  }
  
  /// Check if cylinder is overdue
  static bool isCylinderOverdue(Timestamp? lastCheckedOutAt) {
    if (lastCheckedOutAt == null) return false;
    
    final checkoutDate = lastCheckedOutAt.toDate();
    final now = DateTime.now();
    final daysSinceCheckout = now.difference(checkoutDate).inDays;
    
    return daysSinceCheckout > 30;
  }
}

/// Cylinder model class
class Cylinder {
  final String id;
  final String barcode;
  final String serial;
  final String status;
  final String? currentHolder;
  final Timestamp? lastCheckedOutAt;
  final Timestamp? lastCheckedInAt;
  final String? notes;
  final List<Map<String, dynamic>> audit;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  
  Cylinder({
    required this.id,
    required this.barcode,
    required this.serial,
    required this.status,
    this.currentHolder,
    this.lastCheckedOutAt,
    this.lastCheckedInAt,
    this.notes,
    required this.audit,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory Cylinder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Cylinder(
      id: doc.id,
      barcode: data['barcode'] ?? '',
      serial: data['serial'] ?? '',
      status: data['status'] ?? 'clean',
      currentHolder: data['currentHolder'],
      lastCheckedOutAt: data['lastCheckedOutAt'],
      lastCheckedInAt: data['lastCheckedInAt'],
      notes: data['notes'],
      audit: List<Map<String, dynamic>>.from(data['audit'] ?? []),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'barcode': barcode,
      'serial': serial,
      'status': status,
      'currentHolder': currentHolder,
      'lastCheckedOutAt': lastCheckedOutAt,
      'lastCheckedInAt': lastCheckedInAt,
      'notes': notes,
      'audit': audit,
    };
  }
  
  bool get isOverdue => CylinderService.isCylinderOverdue(lastCheckedOutAt);
}