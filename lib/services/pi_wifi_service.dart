import 'dart:convert';
import 'package:http/http.dart' as http;

class PiTestResponse {
  final String timestamp;
  final double intensity;
  final String result;
  final String imageUrl;
  final String imagePath;

  PiTestResponse({
    required this.timestamp,
    required this.intensity,
    required this.result,
    required this.imageUrl,
    required this.imagePath,
  });

  factory PiTestResponse.fromJson(Map<String, dynamic> json, String baseUrl) {
    final rawImageUrl = (json['imageUrl'] ?? '').toString();

    String fullImageUrl = rawImageUrl;
    if (rawImageUrl.startsWith('/')) {
      fullImageUrl = '$baseUrl$rawImageUrl';
    }

    return PiTestResponse(
      timestamp: (json['timestamp'] ?? '').toString(),
      intensity: (json['intensity'] as num).toDouble(),
      result: (json['result'] ?? '').toString(),
      imageUrl: fullImageUrl,
      imagePath: (json['imagePath'] ?? '').toString(),
    );
  }
}

class PiWifiService {
  final String baseUrl;

  PiWifiService({required this.baseUrl});

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<bool> checkHealth() async {
    final response = await http.get(_uri('/health')).timeout(
      const Duration(seconds: 5),
    );

    if (response.statusCode != 200) return false;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['status'] == 'ok';
  }

  Future<PiTestResponse> runTest() async {
    final response = await http.post(_uri('/run-test')).timeout(
      const Duration(seconds: 30),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to run test on Raspberry Pi');
    }

    return PiTestResponse.fromJson(data, baseUrl);
  }

  Future<PiTestResponse> getLatestResult() async {
    final response = await http.get(_uri('/latest-result')).timeout(
      const Duration(seconds: 10),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No latest result available');
    }

    return PiTestResponse.fromJson(data, baseUrl);
  }
}