import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/tmdb_movie.dart';

class TMDBService {
  static const String _apiKey = 'cb90429b2fa956590feb66a96a30b763';
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _imageBaseUrl = 'https://image.tmdb.org/t/p/w500';

  Future<List<TMDBMovie>> searchMovies(String query) async {
    if (query.isEmpty) return [];

    try {
      final url =
          '$_baseUrl/search/movie?api_key=$_apiKey&query=${Uri.encodeComponent(query)}&include_adult=false&language=en-US&page=1';
      print(
          'Fetching movies from: ${url.replaceAll(_apiKey, 'API_KEY_HIDDEN')}');

      final response = await http
          .get(
        Uri.parse(url),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception(
              'Request timed out. Please check your internet connection.');
        },
      );

      print('Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data == null || data['results'] == null) {
          print('Invalid response data: $data');
          return [];
        }

        final List<dynamic> results = data['results'] as List<dynamic>;
        print('Found ${results.length} movies');

        return results.map((json) => TMDBMovie.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        print('API Error: ${response.body}');
        throw Exception('Invalid API key. Please check your TMDB API key.');
      } else if (response.statusCode == 404) {
        throw Exception('API endpoint not found.');
      } else {
        print('API Error (${response.statusCode}): ${response.body}');
        throw Exception(
            'Failed to load movies (Status: ${response.statusCode})');
      }
    } on SocketException catch (e) {
      print('Network error: $e');
      throw Exception(
          'Network error: Unable to connect to TMDB. Please check your internet connection and try again.');
    } on TimeoutException catch (e) {
      print('Timeout error: $e');
      throw Exception(
          'Request timed out. Please check your internet connection and try again.');
    } catch (e) {
      print('Error searching movies: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('host lookup')) {
        throw Exception(
            'Network error: Unable to connect to TMDB. Please check your internet connection.');
      }
      rethrow;
    }
  }

  static String? getPosterUrl(String? posterPath) {
    if (posterPath == null) return null;
    return '$_imageBaseUrl$posterPath';
  }
}
