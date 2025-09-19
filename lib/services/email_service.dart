import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EmailConfig {
  // Always use production URL since we don't have a local backend running
  static const String backendUrl = 'https://nattygaslab-email-api.onrender.com/api/send-email';
}

class EmailService {
  /// Send welcome email to new user using Nodemailer backend
  static Future<void> sendWelcomeEmail({
    required String toEmail,
    required String userName,
    required String password,
    required String role,
  }) async {
    try {
      await _sendWelcomeEmailViaNodemailer(
        toEmail: toEmail,
        userName: userName,
        password: password,
        role: role,
      );
    } catch (e) {
      debugPrint('Error sending welcome email: $e');
      
      // Fallback to email client in development
      if (kDebugMode) {
        try {
          await _openEmailClient(
            toEmail: toEmail,
            subject: 'Welcome to NattyGas Lab - Your Account Details',
            body: _generateWelcomeEmailBody(
              userName: userName,
              email: toEmail,
              password: password,
              role: role,
            ),
          );
        } catch (fallbackError) {
          debugPrint('Fallback email client also failed: $fallbackError');
        }
      }
      
      rethrow;
    }
  }

  /// Generate welcome email body
  static String _generateWelcomeEmailBody({
    required String userName,
    required String email,
    required String password,
    required String role,
  }) {
    return '''
Dear $userName,

Welcome to NattyGas Lab - Laboratory Information Management System!

Your account has been successfully created with the following details:

📧 Email: $email
🔑 Temporary Password: $password
👤 Role: ${role.toUpperCase()}

🔐 IMPORTANT SECURITY NOTICE:
For your security, please log in and change your password immediately after your first login.

🚀 Getting Started:
1. Visit the NattyGas Lab application
2. Log in using the credentials above
3. Change your password in your profile settings
4. Explore the features available for your role

📱 Need Help?
If you have any questions or need assistance, please contact your system administrator.

Best regards,
NattyGas Lab Team

---
This is an automated message. Please do not reply to this email.
''';
  }

  /// Open default email client (for development/web)
  static Future<void> _openEmailClient({
    required String toEmail,
    required String subject,
    required String body,
  }) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: toEmail,
      query: _encodeQueryParameters({
        'subject': subject,
        'body': body,
      }),
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        debugPrint('Email client opened successfully');
      } else {
        throw Exception('Could not launch email client');
      }
    } catch (e) {
      debugPrint('Error opening email client: $e');
      // Fallback: show the email content in debug console
      debugPrint('Email Content:\nTo: $toEmail\nSubject: $subject\nBody: $body');
      rethrow;
    }
  }

  /// Send welcome email via Node.js backend with Nodemailer
  static Future<void> _sendWelcomeEmailViaNodemailer({
    required String toEmail,
    required String userName,
    required String password,
    required String role,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(EmailConfig.backendUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'to': toEmail,
          'subject': 'Welcome to NattyGas Lab - Your Account Details',
          'type': 'welcome',
          'userData': {
            'userName': userName,
            'email': toEmail,
            'password': password,
            'role': role,
          },
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          debugPrint('Welcome email sent successfully via Nodemailer to: $toEmail');
          debugPrint('Message ID: ${responseData['messageId']}');
        } else {
          throw Exception('Email service returned error: ${responseData['message']}');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Failed to send email: ${errorData['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      debugPrint('Error sending welcome email via Nodemailer: $e');
      rethrow;
    }
  }

  /// Send generic email via Node.js backend with Nodemailer
  static Future<void> _sendEmailViaService({
    required String toEmail,
    required String subject,
    required String body,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(EmailConfig.backendUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'to': toEmail,
          'subject': subject,
          'text': body,
          'html': _convertTextToHtml(body),
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          debugPrint('Email sent successfully via Nodemailer to: $toEmail');
        } else {
          throw Exception('Email service returned error: ${responseData['message']}');
        }
      } else {
        throw Exception('Failed to send email. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error sending email via Nodemailer: $e');
      rethrow;
    }
  }

  /// Convert plain text to basic HTML format
  static String _convertTextToHtml(String text) {
    return text
        .replaceAll('\n\n', '</p><p>')
        .replaceAll('\n', '<br>')
        .replaceAll('📧', '<span style="color: #0072BC;">📧</span>')
        .replaceAll('🔑', '<span style="color: #0072BC;">🔑</span>')
        .replaceAll('👤', '<span style="color: #0072BC;">👤</span>')
        .replaceAll('🔐', '<span style="color: #e74c3c;">🔐</span>')
        .replaceAll('🚀', '<span style="color: #27ae60;">🚀</span>')
        .replaceAll('📱', '<span style="color: #0072BC;">📱</span>');
  }

  /// Encode query parameters for mailto URL
  static String _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  /// Send password reset notification (optional)
  static Future<void> sendPasswordResetNotification({
    required String toEmail,
    required String userName,
  }) async {
    try {
      if (kIsWeb || kDebugMode) {
        await _openEmailClient(
          toEmail: toEmail,
          subject: 'Password Reset Request - NattyGas Lab',
          body: '''
Dear $userName,

You have requested a password reset for your NattyGas Lab account.

If you did not request this password reset, please ignore this email or contact your system administrator.

If you did request this reset, please check your email for the password reset link from Firebase Authentication.

Best regards,
NattyGas Lab Team

---
This is an automated message. Please do not reply to this email.
''',
        );
      } else {
        await _sendEmailViaService(
          toEmail: toEmail,
          subject: 'Password Reset Request - NattyGas Lab',
          body: 'Password reset notification body...',
        );
      }
    } catch (e) {
      debugPrint('Error sending password reset notification: $e');
      // Don't rethrow for notifications - they're not critical
    }
  }
}