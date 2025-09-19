import 'dart:convert';
import 'dart:io' show File; // only used on mobile
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List, debugPrint;
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = 'dqkdxxbqy';
  static const String uploadPreset = 'nattygaslab_chemicals';

  /// Upload image (works for Web and Mobile).
  static Future<String?> uploadImage(
    dynamic image, { // File (mobile) OR Uint8List (web)
    Function(double)? onProgress,
  }) async {
    try {
      if (onProgress != null) {
        // Simulated progress for UX
        for (int i = 0; i <= 100; i += 20) {
          await Future.delayed(const Duration(milliseconds: 80));
          onProgress(i / 100.0);
        }
      }

      // --- REAL UPLOAD ---
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = 'chemicals';

      if (kIsWeb) {
        // Web → use bytes
        final bytes = image as Uint8List;
        request.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: 'upload.jpg'),
        );
      } else {
        // Mobile → use File
        final file = image as File;
        request.files.add(await http.MultipartFile.fromPath('file', file.path));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['secure_url'] as String?;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          'Upload failed: ${errorData['error']?['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      debugPrint('Error uploading to Cloudinary: $e');
      return null;
    }
  }

  /// Generate thumbnail URL
  static String getThumbnailUrl(
    String originalUrl, {
    int width = 200,
    int height = 200,
  }) {
    if (!originalUrl.contains('cloudinary.com')) {
      if (originalUrl.contains('placeholder.com')) {
        return originalUrl.replaceAll('400x300', '${width}x$height');
      }
      return originalUrl;
    }
    final parts = originalUrl.split('/upload/');
    if (parts.length == 2) {
      return '${parts[0]}/upload/c_fill,w_$width,h_$height,q_auto,f_auto/${parts[1]}';
    }
    return originalUrl;
  }

  static Future<bool> deleteImage(String imageUrl) async {
    debugPrint(
      'TODO: Implement image deletion via Cloud Function for: $imageUrl',
    );
    return true;
  }
}
