import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Auth state stream
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get user role
  static Future<String?> getUserRole(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['role'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user role: $e');
      return null;
    }
  }

  // Sign in with email and password
  static Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      debugPrint('Error signing in: $e');
      rethrow;
    }
  }

  // Create user with email and password
  static Future<UserCredential?> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Store user profile in Firestore
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'name': name,
          'email': email,
          'role': role,
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return credential;
    } catch (e) {
      debugPrint('Error creating user: $e');
      rethrow;
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }

  // Check if user is authenticated and get their role
  static Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final user = _auth.currentUser;
      debugPrint('AuthService: Getting user data for user: ${user?.uid}');
      
      if (user == null) {
        debugPrint('AuthService: No current user found');
        return null;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      debugPrint('AuthService: User document exists: ${userDoc.exists}');
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        userData['uid'] = user.uid;
        debugPrint('AuthService: User data retrieved successfully for role: ${userData['role']}');
        return userData;
      }
      
      debugPrint('AuthService: User document does not exist for uid: ${user.uid}');
      return null;
    } catch (e) {
      debugPrint('AuthService: Error getting current user data: $e');
      return null;
    }
  }

  // Reset password
  static Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Error resetting password: $e');
      rethrow;
    }
  }

  // Send password reset email (alias for resetPassword)
  static Future<void> sendPasswordResetEmail(String email) async {
    return resetPassword(email);
  }

  // Update user profile
  static Future<void> updateUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      
      // Use set with merge to create document if it doesn't exist
      await _firestore.collection('users').doc(uid).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      rethrow;
    }
  }

  // Delete user account
  static Future<void> deleteUserAccount(String uid) async {
    try {
      // Delete user document from Firestore
      await _firestore.collection('users').doc(uid).delete();
      
      // Delete Firebase Auth user
      final user = _auth.currentUser;
      if (user != null && user.uid == uid) {
        await user.delete();
      }
    } catch (e) {
      debugPrint('Error deleting user account: $e');
      rethrow;
    }
  }
}