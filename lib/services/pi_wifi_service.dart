import 'dart:convert';
import 'package:http/http.dart' as http;

class PiTestResponse {
  final String timestamp;
  final double intensity;
  final String result;
  final String imageUrl;
  final String imagePath;
  final bool changeDetected;
  final bool valid;
  final int detectedBandCount;
  final double changeScore;

  PiTestResponse({
    required this.timestamp,
    required this.intensity,
    required this.result,
    required this.imageUrl,
    required this.imagePath,
    required this.changeDetected,
    required this.valid,
    required this.detectedBandCount,
    required this.changeScore,
  });

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static String _extractFilename(String path) {
    if (path.isEmpty) return '';
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isNotEmpty ? parts.last : '';
  }

  factory PiTestResponse.fromJson(Map<String, dynamic> json, String baseUrl) {
    final analysis = (json['analysis'] is Map<String, dynamic>)
        ? json['analysis'] as Map<String, dynamic>
        : <String, dynamic>{};

    final rawImagePath = (json['image_path'] ?? '').toString();
    final rawImageUrl = (json['image_url'] ?? '').toString();
    final rawTimestamp = (json['timestamp'] ?? '').toString();
    final filename = (json['filename'] ?? _extractFilename(rawImagePath)).toString();

    // Always rebuild image URL from the CURRENT baseUrl.
    // This avoids stale hardcoded IPs coming from the backend.
    String rebuiltImageUrl = '';
    if (filename.isNotEmpty) {
      rebuiltImageUrl = '$baseUrl/image/$filename';
    } else if (rawImageUrl.isNotEmpty) {
      final uri = Uri.tryParse(rawImageUrl);
      final path = uri?.path ?? rawImageUrl;
      if (path.startsWith('/')) {
        rebuiltImageUrl = '$baseUrl$path';
      } else {
        rebuiltImageUrl = '$baseUrl/$path';
      }
    }

    return PiTestResponse(
      timestamp: rawTimestamp,
      intensity: _toDouble(
        analysis['realistic_intensity'] ??
            analysis['primary_band_mean_darkness'] ??
            analysis['change_score'] ??
            0,
      ),
      result: (analysis['diagnosis'] ?? '').toString(),
      imageUrl: rebuiltImageUrl,
      imagePath: rawImagePath,
      changeDetected: analysis['change_detected'] == true,
      valid: analysis['valid'] == true,
      detectedBandCount: _toInt(analysis['detected_band_count']),
      changeScore: _toDouble(analysis['change_score']),
    );
  }
}

class PiWifiService {
  final String baseUrl;

  PiWifiService({required this.baseUrl});

 // static Future<String?> discoverPi() async {
    // Change this when needed, or replace later with auto-discovery.
   // return 'http://10.0.0.119:8000';
 // }
    static Future<String?> discoverPi() async {
      return null;
}

  Future<bool> checkHealth() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/health'));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<PiTestResponse> runTest() async {
    final res = await http.get(Uri.parse('$baseUrl/capture-analyze'));

    if (res.statusCode != 200) {
      throw Exception('Failed to run test (${res.statusCode}): ${res.body}');
    }

    final jsonData = json.decode(res.body);

    if (jsonData is! Map<String, dynamic>) {
      throw Exception('Unexpected response format from Raspberry Pi');
    }

    return PiTestResponse.fromJson(jsonData, baseUrl);
  }
}