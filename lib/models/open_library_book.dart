class OpenLibraryBook {
  final String key; // Work ID (e.g., "OL27448W")
  final String title;
  final List<String> authorNames;
  final List<String> authorKeys;
  final int? firstPublishYear;
  final int? coverId;
  final int editionCount;
  final List<String> isbn;
  final bool hasFulltext;
  final String? publisher;
  final List<String> language;

  OpenLibraryBook({
    required this.key,
    required this.title,
    required this.authorNames,
    required this.authorKeys,
    this.firstPublishYear,
    this.coverId,
    required this.editionCount,
    required this.isbn,
    required this.hasFulltext,
    this.publisher,
    required this.language,
  });

  factory OpenLibraryBook.fromJson(Map<String, dynamic> json) {
    return OpenLibraryBook(
      key: json['key'] ?? '',
      title: json['title'] ?? 'Unknown Title',
      authorNames: json['author_name'] != null
          ? List<String>.from(json['author_name'])
          : [],
      authorKeys: json['author_key'] != null
          ? List<String>.from(json['author_key'])
          : [],
      firstPublishYear: json['first_publish_year'],
      coverId: json['cover_i'],
      editionCount: json['edition_count'] ?? 0,
      isbn: json['isbn'] != null ? List<String>.from(json['isbn']) : [],
      hasFulltext: json['has_fulltext'] ?? false,
      publisher: json['publisher'] != null && json['publisher'].isNotEmpty
          ? json['publisher'][0]
          : null,
      language:
          json['language'] != null ? List<String>.from(json['language']) : [],
    );
  }

  // Get the primary author name
  String get primaryAuthor =>
      authorNames.isNotEmpty ? authorNames.first : 'Unknown Author';

  // Get the primary ISBN
  String? get primaryIsbn => isbn.isNotEmpty ? isbn.first : null;

  // Get formatted publish year
  String get publishYearFormatted =>
      firstPublishYear != null ? firstPublishYear.toString() : 'Unknown';

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'title': title,
      'author_name': authorNames,
      'author_key': authorKeys,
      'first_publish_year': firstPublishYear,
      'cover_i': coverId,
      'edition_count': editionCount,
      'isbn': isbn,
      'has_fulltext': hasFulltext,
      'publisher': publisher != null ? [publisher] : null,
      'language': language,
    };
  }
}
