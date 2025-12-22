import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/open_library_book.dart';

/// Service for interacting with the Open Library API
/// Documentation: https://openlibrary.org/developers/api
class OpenLibraryService {
  static const String _baseUrl = 'https://openlibrary.org';
  static const String _searchEndpoint = '/search.json';
  static const String _coverBaseUrl = 'https://covers.openlibrary.org/b';

  // User-Agent header to identify the application
  static const Map<String, String> _headers = {
    'User-Agent': 'BucketListApp/1.0 (Flutter Application)',
  };

  /// Search for books by query
  ///
  /// Parameters:
  /// - [query]: General search query
  /// - [title]: Search by title specifically
  /// - [author]: Search by author specifically
  /// - [limit]: Maximum number of results (default: 10, max: 100)
  /// - [page]: Page number for pagination (default: 1)
  /// - [sort]: Sort order ('new', 'old', 'random', or field name)
  ///
  /// Returns a list of [OpenLibraryBook] objects
  Future<List<OpenLibraryBook>> searchBooks({
    String? query,
    String? title,
    String? author,
    int limit = 10,
    int page = 1,
    String? sort,
  }) async {
    // Validate that at least one search parameter is provided
    if (query == null && title == null && author == null) {
      throw ArgumentError('At least one search parameter must be provided');
    }

    try {
      // Build query parameters
      final queryParams = <String, String>{};

      if (query != null && query.isNotEmpty) {
        queryParams['q'] = query;
      }
      if (title != null && title.isNotEmpty) {
        queryParams['title'] = title;
      }
      if (author != null && author.isNotEmpty) {
        queryParams['author'] = author;
      }

      queryParams['limit'] = limit.clamp(1, 100).toString();
      queryParams['page'] = page.toString();

      if (sort != null && sort.isNotEmpty) {
        queryParams['sort'] = sort;
      }

      // Add all available fields
      queryParams['fields'] =
          'key,title,author_name,author_key,first_publish_year,'
          'cover_i,edition_count,isbn,has_fulltext,publisher,language';

      final uri = Uri.parse('$_baseUrl$_searchEndpoint')
          .replace(queryParameters: queryParams);

      print('Fetching books from: $uri');

      final response = await http.get(uri, headers: _headers).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
              'Request timed out. Please check your internet connection.');
        },
      );

      print('Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data == null || data['docs'] == null) {
          print('Invalid response data: $data');
          return [];
        }

        final List<dynamic> docs = data['docs'] as List<dynamic>;
        final int numFound = data['num_found'] ?? 0;

        print('Found $numFound total books, returning ${docs.length} results');

        return docs.map((json) => OpenLibraryBook.fromJson(json)).toList();
      } else if (response.statusCode == 404) {
        throw Exception('API endpoint not found.');
      } else {
        print('API Error (${response.statusCode}): ${response.body}');
        throw Exception(
            'Failed to load books (Status: ${response.statusCode})');
      }
    } on SocketException catch (e) {
      print('Network error: $e');
      throw Exception(
          'Network error: Unable to connect to Open Library. Please check your internet connection and try again.');
    } on TimeoutException catch (e) {
      print('Timeout error: $e');
      throw Exception(
          'Request timed out. Please check your internet connection and try again.');
    } catch (e) {
      print('Error searching books: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('host lookup')) {
        throw Exception(
            'Network error: Unable to connect to Open Library. Please check your internet connection.');
      }
      rethrow;
    }
  }

  /// Get cover image URL by cover ID
  ///
  /// Parameters:
  /// - [coverId]: The cover ID from the book data
  /// - [size]: Size of the cover ('S' for small, 'M' for medium, 'L' for large)
  ///
  /// Returns the URL string or null if no cover ID is provided
  static String? getCoverUrl(int? coverId, {String size = 'M'}) {
    if (coverId == null) return null;
    return '$_coverBaseUrl/id/$coverId-$size.jpg';
  }

  /// Get cover image URL by ISBN
  ///
  /// Parameters:
  /// - [isbn]: The ISBN of the book
  /// - [size]: Size of the cover ('S' for small, 'M' for medium, 'L' for large)
  ///
  /// Returns the URL string or null if no ISBN is provided
  static String? getCoverUrlByIsbn(String? isbn, {String size = 'M'}) {
    if (isbn == null || isbn.isEmpty) return null;
    return '$_coverBaseUrl/isbn/$isbn-$size.jpg';
  }

  /// Get cover image URL by Open Library ID (OLID)
  ///
  /// Parameters:
  /// - [olid]: The Open Library ID (e.g., 'OL27448W')
  /// - [size]: Size of the cover ('S' for small, 'M' for medium, 'L' for large)
  ///
  /// Returns the URL string or null if no OLID is provided
  static String? getCoverUrlByOlid(String? olid, {String size = 'M'}) {
    if (olid == null || olid.isEmpty) return null;
    return '$_coverBaseUrl/olid/$olid-$size.jpg';
  }

  /// Get author image URL by author key
  ///
  /// Parameters:
  /// - [authorKey]: The author key (e.g., 'OL26320A')
  /// - [size]: Size of the image ('S' for small, 'M' for medium, 'L' for large)
  ///
  /// Returns the URL string or null if no author key is provided
  static String? getAuthorImageUrl(String? authorKey, {String size = 'M'}) {
    if (authorKey == null || authorKey.isEmpty) return null;
    return 'https://covers.openlibrary.org/a/olid/$authorKey-$size.jpg';
  }

  /// Get the Open Library work page URL
  ///
  /// Parameters:
  /// - [workKey]: The work key (e.g., 'OL27448W' or '/works/OL27448W')
  ///
  /// Returns the URL string
  static String getWorkUrl(String workKey) {
    // Remove '/works/' prefix if present
    final key = workKey.replaceFirst('/works/', '');
    return '$_baseUrl/works/$key';
  }

  /// Search for books by ISBN
  ///
  /// Parameters:
  /// - [isbn]: The ISBN to search for
  ///
  /// Returns a list of matching books
  Future<List<OpenLibraryBook>> searchByIsbn(String isbn) async {
    return searchBooks(query: isbn);
  }

  /// Search for books by title
  ///
  /// Parameters:
  /// - [title]: The title to search for
  /// - [limit]: Maximum number of results
  ///
  /// Returns a list of matching books
  Future<List<OpenLibraryBook>> searchByTitle(String title,
      {int limit = 10}) async {
    return searchBooks(title: title, limit: limit);
  }

  /// Search for books by author
  ///
  /// Parameters:
  /// - [author]: The author name to search for
  /// - [limit]: Maximum number of results
  ///
  /// Returns a list of matching books
  Future<List<OpenLibraryBook>> searchByAuthor(String author,
      {int limit = 10}) async {
    return searchBooks(author: author, limit: limit);
  }
}
