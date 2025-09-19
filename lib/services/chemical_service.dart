import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ChemicalService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'chemicals';
  
  /// Get chemicals with pagination and optional filters
  /// Firestore Index Required: chemicals (manufacturer, name) for manufacturer filter
  static Stream<QuerySnapshot> getChemicals({
    int limit = 20,
    DocumentSnapshot? startAfter,
    String? searchQuery,
    String? manufacturerFilter,
    bool? isExpired,
    bool? isLowStock,
  }) {
    Query query = _firestore.collection(_collection);
    
    // Apply filters - be careful with compound queries to avoid index requirements
    if (manufacturerFilter != null && manufacturerFilter.isNotEmpty) {
      query = query.where('manufacturer', isEqualTo: manufacturerFilter);
    }
    
    // For expired filter, we'll handle this differently to avoid complex index requirements
    if (isExpired == true) {
      query = query.where('expiryDate', isLessThan: Timestamp.now());
      // When filtering by expiry, order by expiryDate first
      query = query.orderBy('expiryDate');
    } else if (searchQuery == null || searchQuery.isEmpty) {
      // Default ordering by name only when not searching
      query = query.orderBy('name');
    }
    
    // Search by name (case-insensitive) - only if no other range filters
    if (searchQuery != null && searchQuery.isNotEmpty && isExpired != true) {
      // For better search, consider using Algolia or similar service
      // This is a basic implementation
      query = query
          .where('nameLowercase', isGreaterThanOrEqualTo: searchQuery.toLowerCase())
          .where('nameLowercase', isLessThanOrEqualTo: '${searchQuery.toLowerCase()}\uf8ff')
          .orderBy('nameLowercase'); // Order by the field we're filtering on
    }
    
    // Pagination
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    
    return query.limit(limit).snapshots();
  }
  
  /// Get single chemical by ID
  static Future<DocumentSnapshot> getChemical(String id) {
    return _firestore.collection(_collection).doc(id).get();
  }
  
  /// Add new chemical
  /// TODO: In production, consider using Cloud Function for data validation and audit logging
  static Future<String> addChemical(Map<String, dynamic> chemicalData) async {
    try {
      final now = Timestamp.now();
      
      // Add metadata
      chemicalData['createdAt'] = FieldValue.serverTimestamp();
      chemicalData['updatedAt'] = FieldValue.serverTimestamp();
      chemicalData['nameLowercase'] = chemicalData['name']?.toString().toLowerCase();
      chemicalData['audit'] = [
        {
          'action': 'created',
          'timestamp': now,
          'userId': chemicalData['createdBy'] ?? 'system',
          'details': 'Chemical added to inventory',
        }
      ];
      
      final docRef = await _firestore.collection(_collection).add(chemicalData);
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding chemical: $e');
      rethrow;
    }
  }
  
  /// Update existing chemical
  /// TODO: In production, consider using Cloud Function for data validation and audit logging
  static Future<void> updateChemical(String id, Map<String, dynamic> chemicalData, {
    String? updatedBy,
  }) async {
    try {
      final auditEntry = {
        'action': 'updated',
        'timestamp': Timestamp.now(),
        'userId': updatedBy ?? 'system',
        'details': 'Chemical information updated',
      };
      
      chemicalData['updatedAt'] = FieldValue.serverTimestamp();
      chemicalData['nameLowercase'] = chemicalData['name']?.toString().toLowerCase();
      chemicalData['audit'] = FieldValue.arrayUnion([auditEntry]);
      
      await _firestore.collection(_collection).doc(id).update(chemicalData);
    } catch (e) {
      debugPrint('Error updating chemical: $e');
      rethrow;
    }
  }
  
  /// Delete chemical
  /// TODO: In production, use Cloud Function to handle image cleanup and audit logging
  static Future<void> deleteChemical(String id, {String? deletedBy}) async {
    try {
      // In production, this should be a soft delete with audit trail
      final auditEntry = {
        'action': 'deleted',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': deletedBy ?? 'system',
        'details': 'Chemical removed from inventory',
      };
      
      // For now, we'll do a hard delete, but in production consider soft delete
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting chemical: $e');
      rethrow;
    }
  }
  
  /// Get unique manufacturers for filter dropdown
  /// Firestore Index Required: chemicals (manufacturer)
  static Future<List<String>> getManufacturers() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('manufacturer')
          .get();
      
      final manufacturers = <String>{};
      for (final doc in snapshot.docs) {
        final manufacturer = doc.data()['manufacturer'] as String?;
        if (manufacturer != null && manufacturer.isNotEmpty) {
          manufacturers.add(manufacturer);
        }
      }
      
      return manufacturers.toList();
    } catch (e) {
      debugPrint('Error getting manufacturers: $e');
      return [];
    }
  }
  
  /// Check if chemical is expired
  static bool isExpired(Timestamp? expiryDate) {
    if (expiryDate == null) return false;
    return expiryDate.toDate().isBefore(DateTime.now());
  }
  
  /// Check if chemical is near expiry (within 30 days)
  static bool isNearExpiry(Timestamp? expiryDate) {
    if (expiryDate == null) return false;
    final now = DateTime.now();
    final expiry = expiryDate.toDate();
    final daysUntilExpiry = expiry.difference(now).inDays;
    return daysUntilExpiry <= 30 && daysUntilExpiry > 0;
  }
  
  /// Check if chemical is low stock
  static bool isLowStock(double? quantity, double threshold) {
    if (quantity == null) return false;
    return quantity <= threshold;
  }
  
  /// Get expiry status for UI display
  static ExpiryStatus getExpiryStatus(Timestamp? expiryDate) {
    if (expiryDate == null) return ExpiryStatus.unknown;
    
    if (isExpired(expiryDate)) {
      return ExpiryStatus.expired;
    } else if (isNearExpiry(expiryDate)) {
      return ExpiryStatus.nearExpiry;
    } else {
      return ExpiryStatus.good;
    }
  }
  
  /// Update chemical stock quantity
  static Future<void> updateStock(String id, double newQuantity, String reason, {
    String? updatedBy,
  }) async {
    try {
      final auditEntry = {
        'action': 'stock_updated',
        'timestamp': Timestamp.now(),
        'userId': updatedBy ?? 'system',
        'details': 'Stock quantity updated',
        'newQuantity': newQuantity,
        'reason': reason,
      };
      
      await _firestore.collection(_collection).doc(id).update({
        'quantity': newQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
        'audit': FieldValue.arrayUnion([auditEntry]),
      });
    } catch (e) {
      debugPrint('Error updating stock: $e');
      rethrow;
    }
  }
  
  /// Get chemicals with low stock
  static Future<List<Map<String, dynamic>>> getLowStockChemicals({double threshold = 10.0}) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('quantity', isLessThanOrEqualTo: threshold)
          .orderBy('quantity')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting low stock chemicals: $e');
      return [];
    }
  }
  
  /// Get expired chemicals as stream for real-time updates
  static Stream<QuerySnapshot> getExpiredChemicalsStream({int limit = 20}) {
    return _firestore
        .collection(_collection)
        .where('expiryDate', isLessThan: Timestamp.now())
        .orderBy('expiryDate')
        .limit(limit)
        .snapshots();
  }
  
  /// Get expired chemicals
  static Future<List<Map<String, dynamic>>> getExpiredChemicals() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('expiryDate', isLessThan: Timestamp.now())
          .orderBy('expiryDate')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting expired chemicals: $e');
      return [];
    }
  }
  
  /// Get chemicals expiring soon
  static Future<List<Map<String, dynamic>>> getChemicalsExpiringSoon() async {
    try {
      final now = DateTime.now();
      final thirtyDaysFromNow = now.add(const Duration(days: 30));
      
      final snapshot = await _firestore
          .collection(_collection)
          .where('expiryDate', isGreaterThan: Timestamp.now())
          .where('expiryDate', isLessThanOrEqualTo: Timestamp.fromDate(thirtyDaysFromNow))
          .orderBy('expiryDate')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting chemicals expiring soon: $e');
      return [];
    }
  }
}

enum ExpiryStatus {
  good,
  nearExpiry,
  expired,
  unknown,
}

class Chemical {
  final String id;
  final String name;
  final String manufacturer;
  final double quantity;
  final String unit;
  final String? batchNo;
  final Timestamp? mfgDate;
  final Timestamp? expiryDate;
  final String? description;
  final String? imageUrl;
  final List<Map<String, dynamic>> audit;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  
  Chemical({
    required this.id,
    required this.name,
    required this.manufacturer,
    required this.quantity,
    required this.unit,
    this.batchNo,
    this.mfgDate,
    this.expiryDate,
    this.description,
    this.imageUrl,
    required this.audit,
    this.createdAt,
    this.updatedAt,
  });
  
  factory Chemical.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Chemical(
      id: doc.id,
      name: data['name'] ?? '',
      manufacturer: data['manufacturer'] ?? '',
      quantity: (data['quantity'] ?? 0).toDouble(),
      unit: data['unit'] ?? '',
      batchNo: data['batchNo'],
      mfgDate: data['mfgDate'],
      expiryDate: data['expiryDate'],
      description: data['description'],
      imageUrl: data['imageUrl'],
      audit: List<Map<String, dynamic>>.from(data['audit'] ?? []),
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'manufacturer': manufacturer,
      'quantity': quantity,
      'unit': unit,
      'batchNo': batchNo,
      'mfgDate': mfgDate,
      'expiryDate': expiryDate,
      'description': description,
      'imageUrl': imageUrl,
      'audit': audit,
    };
  }
  
  ExpiryStatus get expiryStatus => ChemicalService.getExpiryStatus(expiryDate);
  bool get isExpired => ChemicalService.isExpired(expiryDate);
  bool get isNearExpiry => ChemicalService.isNearExpiry(expiryDate);
  bool isLowStock(double threshold) => ChemicalService.isLowStock(quantity, threshold);
}