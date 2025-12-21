import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tmdb_movie.dart';

class TMDBService {
  static const String _apiKey = 'cb90429b2fa956590feb66a96a30b763';
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _imageBaseUrl = 'https://image.tmdb.org/t/p/w500';

  Future<List<TMDBMovie>> searchMovies(String query) async {
    if (query.isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/search/movie?api_key=$_apiKey&query=${Uri.encodeComponent(query)}&include_adult=false&language=en-US&page=1'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'];
        return results.map((json) => TMDBMovie.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load movies');
      }
    } catch (e) {
      throw Exception('Failed to search movies: $e');
    }
  }

  static String? getPosterUrl(String? posterPath) {
    if (posterPath == null) return null;
    return '$_imageBaseUrl$posterPath';
  }
}
