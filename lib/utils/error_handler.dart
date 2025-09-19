import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ErrorHandler {
  static VoidCallback? _lastAction;
  
  /// Show error message with retry option
  static void showError(BuildContext context, dynamic error, {VoidCallback? onRetry}) {
    _lastAction = onRetry;
    
    final message = _getErrorMessage(error);
    final isRetryable = _isRetryableError(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 4),
        action: isRetryable && onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
  
  /// Show success message
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
  
  /// Show warning message
  static void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.warning_outlined,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange[600],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
  
  /// Show info message
  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue[600],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
  
  /// Get user-friendly error message
  static String _getErrorMessage(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You don\'t have permission to perform this action';
        case 'unavailable':
          return 'Service temporarily unavailable. Please try again.';
        case 'unauthenticated':
          return 'Please sign in to continue';
        case 'not-found':
          return 'The requested item was not found';
        case 'already-exists':
          return 'This item already exists';
        case 'invalid-argument':
          return 'Invalid data provided. Please check your input.';
        case 'deadline-exceeded':
          return 'Request timed out. Please try again.';
        case 'resource-exhausted':
          return 'Too many requests. Please wait and try again.';
        case 'failed-precondition':
          return 'Operation cannot be completed at this time';
        case 'aborted':
          return 'Operation was cancelled. Please try again.';
        case 'out-of-range':
          return 'Invalid range specified';
        case 'unimplemented':
          return 'This feature is not yet available';
        case 'internal':
          return 'Internal server error. Please try again later.';
        case 'data-loss':
          return 'Data corruption detected. Please contact support.';
        default:
          return 'An error occurred: ${error.message ?? error.code}';
      }
    }
    
    if (error is Exception) {
      final message = error.toString();
      if (message.contains('network')) {
        return 'Network error. Please check your connection.';
      }
      if (message.contains('timeout')) {
        return 'Request timed out. Please try again.';
      }
      return 'An error occurred. Please try again.';
    }
    
    return error.toString().isNotEmpty 
        ? error.toString() 
        : 'An unexpected error occurred';
  }
  
  /// Check if error is retryable
  static bool _isRetryableError(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'unavailable':
        case 'deadline-exceeded':
        case 'resource-exhausted':
        case 'aborted':
        case 'internal':
          return true;
        default:
          return false;
      }
    }
    
    if (error is Exception) {
      final message = error.toString().toLowerCase();
      return message.contains('network') || 
             message.contains('timeout') ||
             message.contains('connection');
    }
    
    return false;
  }
  
  /// Retry last action
  static void _retryLastAction() {
    if (_lastAction != null) {
      _lastAction!();
    }
  }
  
  /// Show confirmation dialog
  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: confirmColor),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              cancelText,
              style: GoogleFonts.poppins(),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor ?? Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(
              confirmText,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }
  
  /// Show loading dialog
  static void showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message,
                style: GoogleFonts.poppins(),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  /// Hide loading dialog
  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }
  
  /// Handle async operation with error handling
  static Future<T?> handleAsync<T>(
    BuildContext context,
    Future<T> operation, {
    String? loadingMessage,
    String? successMessage,
    VoidCallback? onSuccess,
    VoidCallback? onError,
  }) async {
    try {
      if (loadingMessage != null) {
        showLoadingDialog(context, message: loadingMessage);
      }
      
      final result = await operation;
      
      if (loadingMessage != null) {
        hideLoadingDialog(context);
      }
      
      if (successMessage != null) {
        showSuccess(context, successMessage);
      }
      
      onSuccess?.call();
      return result;
    } catch (error) {
      if (loadingMessage != null) {
        hideLoadingDialog(context);
      }
      
      showError(context, error);
      onError?.call();
      return null;
    }
  }
}

/// Custom exception classes
class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
  
  @override
  String toString() => message;
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  
  @override
  String toString() => message;
}

class AuthenticationException implements Exception {
  final String message;
  AuthenticationException(this.message);
  
  @override
  String toString() => message;
}