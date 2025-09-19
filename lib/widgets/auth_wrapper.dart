import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../screens/login_screen.dart';
import '../screens/admin_dashboard.dart';
import '../screens/splash_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isInitializing = true;
  int _retryCount = 0;
  static const int _maxRetries = 2;
  Map<String, dynamic>? _cachedUserData;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    // Reduced delay for faster initialization
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    });
  }

  @override
  void dispose() {
    // Clear cached data on dispose
    _cachedUserData = null;
    _lastUserId = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        // Show splash only during initial loading or if still initializing
        if (_isInitializing || snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // Handle errors - don't sign out immediately
        if (snapshot.hasError) {
          debugPrint('Auth stream error: ${snapshot.error}');
          return const LoginScreen();
        }

        // If user is logged in
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          
          // Check if we have cached data for this user
          if (_cachedUserData != null && _lastUserId == user.uid) {
            final role = _cachedUserData!['role'] as String?;
            return role == 'admin' ? const AdminDashboard() : const AdminDashboard();
          }
          
          return FutureBuilder<Map<String, dynamic>?>(
            future: _getUserDataWithRetry(user.uid),
            builder: (context, userSnapshot) {
              // Only show splash for the first load, not for retries
              if (userSnapshot.connectionState == ConnectionState.waiting && _cachedUserData == null) {
                return const SplashScreen();
              }

              if (userSnapshot.hasError) {
                debugPrint('User data error: ${userSnapshot.error}');
                // Show login on persistent errors
                return const LoginScreen();
              }

              if (userSnapshot.hasData && userSnapshot.data != null) {
                final userData = userSnapshot.data!;
                final role = userData['role'] as String?;

                // Cache the user data
                _cachedUserData = userData;
                _lastUserId = user.uid;
                _retryCount = 0;

                // Navigate based on role
                return role == 'admin' ? const AdminDashboard() : const AdminDashboard();
              } else {
                // User data not found - this might be a new user or timing issue
                if (_retryCount < _maxRetries) {
                  debugPrint('User data not found, retry count: $_retryCount');
                  // Show dashboard with loading indicator instead of full splash
                  return const AdminDashboard();
                } else {
                  // After max retries, create a basic user profile
                  debugPrint('Max retries reached, creating basic user profile');
                  _createBasicUserProfile(user);
                  return const AdminDashboard();
                }
              }
            },
          );
        }

        // User not logged in, show login screen
        return const LoginScreen();
      },
    );
  }

  Future<Map<String, dynamic>?> _getUserDataWithRetry(String uid) async {
    try {
      final userData = await AuthService.getCurrentUserData();
      if (userData != null) {
        return userData;
      } else {
        // Increment retry count and wait before next attempt
        _retryCount++;
        if (_retryCount < _maxRetries) {
          // Shorter delays for faster response
          await Future.delayed(Duration(milliseconds: 200 * _retryCount));
          return _getUserDataWithRetry(uid);
        }
        return null;
      }
    } catch (e) {
      debugPrint('Error getting user data: $e');
      _retryCount++;
      if (_retryCount < _maxRetries) {
        await Future.delayed(Duration(milliseconds: 200 * _retryCount));
        return _getUserDataWithRetry(uid);
      }
      rethrow;
    }
  }

  Future<void> _createBasicUserProfile(User user) async {
    try {
      // Create a basic user profile if it doesn't exist
      final userData = {
        'name': user.displayName ?? user.email?.split('@')[0] ?? 'User',
        'email': user.email ?? '',
        'role': 'admin', // Default to admin for now
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      await AuthService.updateUserProfile(uid: user.uid, data: userData);
      
      // Cache the created user data
      _cachedUserData = Map<String, dynamic>.from(userData);
      _cachedUserData!['uid'] = user.uid;
      _lastUserId = user.uid;
      _retryCount = 0;
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error creating user profile: $e');
      // If we can't create profile, sign out as last resort
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AuthService.signOut();
      });
    }
  }
}