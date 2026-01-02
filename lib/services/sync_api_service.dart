import 'dart:convert';
import 'package:http/http.dart' as http;

/// API Service for cloud sync operations
class SyncApiService {
  // TODO: Replace with your actual backend URL
  static const String baseUrl = 'http://YOUR_BACKEND_URL';

  /// Register a new user
  Future<Map<String, dynamic>> register(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Registration failed');
      }
    } catch (e) {
      throw Exception('Registration error: $e');
    }
  }

  /// Login user
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Login failed');
      }
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }

  /// Push data to cloud
  /// Returns the new version number from server
  Future<Map<String, dynamic>> pushToCloud({
    required String authToken,
    required int version,
    required int lastModifiedAt,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sync/push'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'version': version,
          'lastModifiedAt': lastModifiedAt,
          'data': data,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Push failed');
      }
    } catch (e) {
      throw Exception('Push error: $e');
    }
  }

  /// Pull data from cloud
  Future<Map<String, dynamic>> pullFromCloud({
    required String authToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sync/pull'),
        headers: {
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Pull failed');
      }
    } catch (e) {
      throw Exception('Pull error: $e');
    }
  }
}
