import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'email_service.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get users with pagination and filtering
  // Required Firestore index: users collection on (role, active, name)
  static Future<QuerySnapshot> getUsers({
    int limit = 20,
    DocumentSnapshot? startAfter,
    String? roleFilter,
    bool? activeFilter,
    String? searchQuery,
  }) async {
    Query query = _firestore.collection('users');

    // Apply filters
    if (roleFilter != null && roleFilter != 'All') {
      query = query.where('role', isEqualTo: roleFilter);
    }

    if (activeFilter != null) {
      query = query.where('active', isEqualTo: activeFilter);
    }

    // Firestore doesn't support full-text search natively
    query = query.orderBy('name').limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return await query.get();
  }

  // Get all users
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    final snapshot = await _firestore.collection('users').get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // Get users stream for real-time updates
  static Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // Search users by name or email (client-side filtering for now)
  // In production, consider using Algolia or similar for full-text search
  static Future<List<Map<String, dynamic>>> searchUsers(String searchQuery) async {
    final users = await getAllUsers();

    if (searchQuery.isEmpty) return users;

    return users.where((user) {
      final name = (user['name'] as String? ?? '').toLowerCase();
      final email = (user['email'] as String? ?? '').toLowerCase();
      final query = searchQuery.toLowerCase();
      
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  // Create new user
  // PRODUCTION NOTE: This should be handled by a Cloud Function for security
  // Client apps should not have admin privileges to create users directly
  static Future<String> createUser({
    required String name,
    required String email,
    required String role,
    required String password,
    bool sendWelcomeEmail = false,
  }) async {
    try {
      // In production, this should call a Cloud Function instead
      // Example: await functions.httpsCallable('createUser').call({...})
      
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Store user profile in Firestore
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'name': name,
          'email': email,
          'role': role,
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Send welcome email if requested
        if (sendWelcomeEmail) {
          try {
            debugPrint('Attempting to send welcome email to: $email');
            debugPrint('Using backend URL: ${kDebugMode ? 'http://localhost:3001/api/send-email' : 'https://nattygaslab-email-api.onrender.com/api/send-email'}');
            
            await EmailService.sendWelcomeEmail(
              toEmail: email,
              userName: name,
              password: password,
              role: role,
            );
            debugPrint('✅ Welcome email sent successfully to $email');
          } catch (e) {
            debugPrint('❌ Failed to send welcome email: $e');
            debugPrint('Email details - To: $email, Name: $name, Role: $role');
            
            // Don't fail user creation if email fails
          }
        }

        return userCredential.user!.uid;
      } else {
        throw Exception('Failed to create user');
      }
    } catch (e) {
      debugPrint('Error creating user: $e');
      rethrow;
    }
  }

  // Update user profile
  // PRODUCTION NOTE: Consider using Cloud Function for validation and audit logging
  static Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('users').doc(userId).update(updates);
    } catch (e) {
      debugPrint('Error updating user: $e');
      rethrow;
    }
  }

  // Send password reset email
  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Error sending password reset email: $e');
      rethrow;
    }
  }

  // Send password reset (alias for sendPasswordResetEmail)
  static Future<void> sendPasswordReset(String email) async {
    return sendPasswordResetEmail(email);
  }

  // Deactivate user (soft delete)
  static Future<void> deactivateUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'active': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error deactivating user: $e');
      rethrow;
    }
  }

  // Reactivate user
  static Future<void> reactivateUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'active': true,
        'reactivatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error reactivating user: $e');
      rethrow;
    }
  }

  // Delete user permanently (hard delete)
  // PRODUCTION NOTE: This should be handled by a Cloud Function for security
  // Consider soft delete instead for audit purposes
  static Future<void> deleteUser(String userId) async {
    try {
      // Delete user document from Firestore
      await _firestore.collection('users').doc(userId).delete();
      
      // Note: Firebase Auth user deletion should be handled by Cloud Function
      // as client apps don't have permission to delete other users' auth accounts
      debugPrint('User document deleted from Firestore: $userId');
    } catch (e) {
      debugPrint('Error deleting user: $e');
      rethrow;
    }
  }

  // Get available roles
  static List<String> getAvailableRoles() {
    return ['admin', 'supervisor', 'clerk', 'technician', 'assistant', 'customer'];
  }
  
  // Generate random password with improved strength
  static String generateRandomPassword({int length = 12}) {
    // Define character sets for strong password
    const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lowercase = 'abcdefghijklmnopqrstuvwxyz';
    const numbers = '0123456789';
    const symbols = '!@#\$%^&*()_+-=[]{}|;:,.<>?';
    
    // Ensure minimum requirements
    final random = DateTime.now().millisecondsSinceEpoch;
    final seed = random % 1000000;
    
    // Build password with guaranteed character types
    String password = '';
    
    // Add at least one character from each category
    password += uppercase[seed % uppercase.length];
    password += lowercase[(seed * 2) % lowercase.length];
    password += numbers[(seed * 3) % numbers.length];
    password += symbols[(seed * 4) % symbols.length];
    
    // Fill remaining length with random characters from all sets
    const allChars = uppercase + lowercase + numbers + symbols;
    for (int i = 4; i < length; i++) {
      final index = (seed * (i + 1) * 7) % allChars.length;
      password += allChars[index];
    }
    
    // Shuffle the password to avoid predictable patterns
    final passwordList = password.split('');
    for (int i = passwordList.length - 1; i > 0; i--) {
      final j = (seed * (i + 1)) % (i + 1);
      final temp = passwordList[i];
      passwordList[i] = passwordList[j];
      passwordList[j] = temp;
    }
    
    return passwordList.join('');
  }
  
  // Check password strength
  static PasswordStrength checkPasswordStrength(String password) {
    if (password.isEmpty) return PasswordStrength.veryWeak;
    
    int score = 0;
    
    // Length check
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (password.length >= 16) score++;
    
    // Character variety checks
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*()_+\-=\[\]{}|;:,.<>?]').hasMatch(password)) score++;
    
    // Complexity checks
    if (password.length >= 10 && RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#\$%^&*])').hasMatch(password)) {
      score++;
    }
    
    // Return strength based on score
    if (score <= 2) return PasswordStrength.veryWeak;
    if (score <= 4) return PasswordStrength.weak;
    if (score <= 6) return PasswordStrength.medium;
    if (score <= 7) return PasswordStrength.strong;
    return PasswordStrength.veryStrong;
  }
}

enum PasswordStrength {
  veryWeak,
  weak,
  medium,
  strong,
  veryStrong,
}