import 'dart:convert';
import 'package:http/http.dart' as http;

/// API Service for cloud sync operations
class SyncApiService {
  // TODO: Replace with your actual backend URL
  static const String baseUrl =
      'https://offline-first-sync-backend.onrender.com';

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

  /// Register with optional backup data
  Future<RegisterResponse> registerWithBackup({
    required String email,
    required String password,
    Map<String, dynamic>? data, // Optional backup data
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          if (data != null) 'data': data, // Include data if provided
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        return RegisterResponse(
          token: json['token'],
          userId: json['userId'] ?? json['email'],
          version: json['version'] as int? ?? 1, // Default to 1 if not provided
        );
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Registration failed');
      }
    } catch (e) {
      throw Exception('Registration error: $e');
    }
  }

  /// Restore backup from server
  Future<RestoreResponse> restore(String authToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/restore'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return RestoreResponse(
          data: json['data'] ?? {},
          version: json['version'] ?? 0,
          hasBackup: json['hasBackup'] ?? false,
          message: json['message'] ?? 'Restore complete',
        );
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Restore failed');
      }
    } catch (e) {
      throw Exception('Restore error: $e');
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
      } else if (response.statusCode == 409) {
        // Conflict detected - Server has newer data
        final body = jsonDecode(response.body);
        throw SyncConflictException(
          serverVersion: body['serverVersion'],
          serverData: body['serverData'],
        );
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Push failed');
      }
    } on SyncConflictException {
      rethrow;
    } catch (e) {
      if (e is SyncConflictException)
        rethrow; // Should be redundant due to 'on' clause but safe
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

class RegisterResponse {
  final String token;
  final String userId;
  final int version;

  RegisterResponse({
    required this.token,
    required this.userId,
    this.version = 1,
  });
}

class RestoreResponse {
  final Map<String, dynamic> data;
  final int version;
  final bool hasBackup;
  final String message;

  RestoreResponse({
    required this.data,
    required this.version,
    required this.hasBackup,
    required this.message,
  });
}

class SyncConflictException implements Exception {
  final int serverVersion;
  final Map<String, dynamic> serverData;

  SyncConflictException({
    required this.serverVersion,
    required this.serverData,
  });

  @override
  String toString() => 'SyncConflictException(serverVersion: $serverVersion)';
}
