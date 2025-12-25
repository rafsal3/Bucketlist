import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  // Base URL configuration
  // Using Render cloud backend server
  static const String baseUrl = 'https://backendbucket.onrender.com/api/v1';

  String? _authToken;

  // Set authentication token
  void setToken(String? token) {
    _authToken = token;
  }

  // Get authentication token
  String? get token => _authToken;

  // Get headers with optional authentication
  Map<String, String> _getHeaders({bool needsAuth = true}) {
    final headers = {'Content-Type': 'application/json'};
    if (needsAuth && _authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  // Handle API response
  Map<String, dynamic> _handleResponse(http.Response response) {
    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw ApiException(
        message: data['error']?['message'] ?? 'An error occurred',
        code: data['error']?['code'] ?? 'UNKNOWN_ERROR',
        statusCode: response.statusCode,
      );
    }
  }

  // ==================== AUTHENTICATION ====================

  /// Register a new user
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: _getHeaders(needsAuth: false),
        body: jsonEncode({
          'email': email,
          'password': password,
          'name': name,
        }),
      );

      final data = _handleResponse(response);

      if (data['success'] && data['data']['token'] != null) {
        setToken(data['data']['token']);
        return AuthResponse.fromJson(data['data']);
      }

      throw ApiException(
          message: 'Registration failed', code: 'REGISTRATION_FAILED');
    } catch (e) {
      debugPrint('Register error: $e');
      rethrow;
    }
  }

  /// Login user
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _getHeaders(needsAuth: false),
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = _handleResponse(response);

      if (data['success'] && data['data']['token'] != null) {
        setToken(data['data']['token']);
        return AuthResponse.fromJson(data['data']);
      }

      throw ApiException(message: 'Login failed', code: 'LOGIN_FAILED');
    } catch (e) {
      debugPrint('Login error: $e');
      rethrow;
    }
  }

  /// Get user profile
  Future<UserProfile> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/profile'),
        headers: _getHeaders(),
      );

      final data = _handleResponse(response);
      return UserProfile.fromJson(data['data']);
    } catch (e) {
      debugPrint('Get profile error: $e');
      rethrow;
    }
  }

  /// Update user preferences
  Future<void> updatePreferences({
    required bool isDarkMode,
    required String themeColor,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/auth/preferences'),
        headers: _getHeaders(),
        body: jsonEncode({
          'isDarkMode': isDarkMode,
          'themeColor': themeColor,
        }),
      );

      _handleResponse(response);
    } catch (e) {
      debugPrint('Update preferences error: $e');
      rethrow;
    }
  }

  // ==================== SPACES ====================

  /// Get all spaces
  Future<List<dynamic>> getSpaces({bool includeHidden = false}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/spaces?includeHidden=$includeHidden'),
        headers: _getHeaders(),
      );

      final data = _handleResponse(response);
      return data['data'] as List;
    } catch (e) {
      debugPrint('Get spaces error: $e');
      rethrow;
    }
  }

  /// Get single space with categories and items
  Future<Map<String, dynamic>> getSpace(String spaceId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/spaces/$spaceId'),
        headers: _getHeaders(),
      );

      final data = _handleResponse(response);
      return data['data'];
    } catch (e) {
      debugPrint('Get space error: $e');
      rethrow;
    }
  }

  /// Create new space
  Future<Map<String, dynamic>> createSpace({
    required String name,
    required String icon,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/spaces'),
        headers: _getHeaders(),
        body: jsonEncode({
          'name': name,
          'icon': icon,
        }),
      );

      final data = _handleResponse(response);
      return data['data'];
    } catch (e) {
      debugPrint('Create space error: $e');
      rethrow;
    }
  }

  /// Update space
  Future<Map<String, dynamic>> updateSpace({
    required String spaceId,
    required String name,
    required String icon,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/spaces/$spaceId'),
        headers: _getHeaders(),
        body: jsonEncode({
          'name': name,
          'icon': icon,
        }),
      );

      final data = _handleResponse(response);
      return data['data'];
    } catch (e) {
      debugPrint('Update space error: $e');
      rethrow;
    }
  }

  /// Delete space
  Future<void> deleteSpace(String spaceId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/spaces/$spaceId'),
        headers: _getHeaders(),
      );

      _handleResponse(response);
    } catch (e) {
      debugPrint('Delete space error: $e');
      rethrow;
    }
  }

  // ==================== CATEGORIES ====================

  /// Get all categories for a space
  Future<List<dynamic>> getCategories(String spaceId,
      {bool includeHidden = false}) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/spaces/$spaceId/categories?includeHidden=$includeHidden'),
        headers: _getHeaders(),
      );

      final data = _handleResponse(response);
      return data['data'] as List;
    } catch (e) {
      debugPrint('Get categories error: $e');
      rethrow;
    }
  }

  /// Create category
  Future<Map<String, dynamic>> createCategory({
    required String spaceId,
    required String name,
    required String icon,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/spaces/$spaceId/categories'),
        headers: _getHeaders(),
        body: jsonEncode({
          'name': name,
          'icon': icon,
        }),
      );

      final data = _handleResponse(response);
      return data['data'];
    } catch (e) {
      debugPrint('Create category error: $e');
      rethrow;
    }
  }

  // ==================== ITEMS ====================

  /// Get all items in a space
  Future<Map<String, dynamic>> getItems(
    String spaceId, {
    String? categoryId,
    bool? isCompleted,
    bool uncategorized = false,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      if (categoryId != null) queryParams['categoryId'] = categoryId;
      if (isCompleted != null)
        queryParams['isCompleted'] = isCompleted.toString();
      if (uncategorized) queryParams['uncategorized'] = 'true';

      final uri = Uri.parse('$baseUrl/spaces/$spaceId/items')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: _getHeaders());
      final data = _handleResponse(response);
      return data['data'];
    } catch (e) {
      debugPrint('Get items error: $e');
      rethrow;
    }
  }

  /// Create item
  Future<Map<String, dynamic>> createItem({
    required String spaceId,
    required String text,
    String? categoryId,
    String? imageUrl,
    String? description,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/spaces/$spaceId/items'),
        headers: _getHeaders(),
        body: jsonEncode({
          'text': text,
          'categoryId': categoryId,
          'imageUrl': imageUrl,
          'description': description,
        }),
      );

      final data = _handleResponse(response);
      return data['data'];
    } catch (e) {
      debugPrint('Create item error: $e');
      rethrow;
    }
  }

  /// Toggle item completion
  Future<Map<String, dynamic>> toggleItem(String spaceId, String itemId) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/spaces/$spaceId/items/$itemId/toggle'),
        headers: _getHeaders(),
      );

      final data = _handleResponse(response);
      return data['data'];
    } catch (e) {
      debugPrint('Toggle item error: $e');
      rethrow;
    }
  }

  /// Delete item
  Future<void> deleteItem(String spaceId, String itemId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/spaces/$spaceId/items/$itemId'),
        headers: _getHeaders(),
      );

      _handleResponse(response);
    } catch (e) {
      debugPrint('Delete item error: $e');
      rethrow;
    }
  }

  // ==================== EXTERNAL APIs ====================

  /// Search movies using TMDB
  Future<Map<String, dynamic>> searchMovies(String query,
      {int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/external/movies/search?query=$query&page=$page'),
        headers: _getHeaders(),
      );

      final data = _handleResponse(response);
      return data['data'];
    } catch (e) {
      debugPrint('Search movies error: $e');
      rethrow;
    }
  }

  /// Search books using OpenLibrary
  Future<Map<String, dynamic>> searchBooks(String query,
      {int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/external/books/search?query=$query&limit=$limit'),
        headers: _getHeaders(),
      );

      final data = _handleResponse(response);
      return data['data'];
    } catch (e) {
      debugPrint('Search books error: $e');
      rethrow;
    }
  }
}

// ==================== MODELS ====================

class AuthResponse {
  final String userId;
  final String email;
  final String name;
  final String token;

  AuthResponse({
    required this.userId,
    required this.email,
    required this.name,
    required this.token,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      userId: json['userId'],
      email: json['email'],
      name: json['name'],
      token: json['token'],
    );
  }
}

class UserProfile {
  final String userId;
  final String email;
  final String name;
  final Map<String, dynamic>? preferences;

  UserProfile({
    required this.userId,
    required this.email,
    required this.name,
    this.preferences,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['userId'],
      email: json['email'],
      name: json['name'],
      preferences: json['preferences'],
    );
  }
}

class ApiException implements Exception {
  final String message;
  final String code;
  final int? statusCode;

  ApiException({
    required this.message,
    required this.code,
    this.statusCode,
  });

  @override
  String toString() => 'ApiException: $message (Code: $code)';
}
