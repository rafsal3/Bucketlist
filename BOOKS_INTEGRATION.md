# Books Integration - Open Library API

This document describes the integration with the Open Library API for searching and displaying books in the Bucket List application.

## Branch
- **Branch Name**: `feature/books-integration`
- **Created**: 2025-12-22

## Overview

The Open Library API integration allows users to search for books and add them to their bucket list. The integration uses the Open Library Search API, which is free and doesn't require an API key.

## API Documentation

- **Main API Docs**: https://openlibrary.org/developers/api
- **Search API Docs**: https://openlibrary.org/dev/docs/api/search
- **Covers API Docs**: https://openlibrary.org/dev/docs/api/covers

## Implementation

### Files Created

1. **`lib/models/open_library_book.dart`**
   - Model class representing a book from Open Library
   - Contains fields: title, authors, ISBN, cover ID, publish year, etc.
   - Includes helper methods for common operations

2. **`lib/services/open_library_service.dart`**
   - Service class for making API calls to Open Library
   - Provides search functionality with multiple parameters
   - Includes helper methods for getting cover images and author images

### Key Features

#### 1. Book Search
The service supports multiple search methods:

```dart
// General search
final books = await openLibraryService.searchBooks(query: 'Harry Potter');

// Search by title
final books = await openLibraryService.searchByTitle('The Lord of the Rings');

// Search by author
final books = await openLibraryService.searchByAuthor('J.K. Rowling');

// Search by ISBN
final books = await openLibraryService.searchByIsbn('9780439708180');

// Advanced search with pagination and sorting
final books = await openLibraryService.searchBooks(
  title: 'Harry Potter',
  author: 'Rowling',
  limit: 20,
  page: 2,
  sort: 'new',
);
```

#### 2. Cover Images
The service provides multiple ways to get book cover images:

```dart
// By cover ID (from search results)
final coverUrl = OpenLibraryService.getCoverUrl(book.coverId, size: 'M');

// By ISBN
final coverUrl = OpenLibraryService.getCoverUrlByIsbn('9780439708180', size: 'L');

// By Open Library ID
final coverUrl = OpenLibraryService.getCoverUrlByOlid('OL27448W', size: 'S');
```

**Cover Sizes:**
- `'S'` - Small (default)
- `'M'` - Medium
- `'L'` - Large

#### 3. Author Images
Get author profile images:

```dart
final authorImageUrl = OpenLibraryService.getAuthorImageUrl(
  book.authorKeys.first,
  size: 'M',
);
```

### API Response Format

The Search API returns results in this format:

```json
{
  "start": 0,
  "num_found": 629,
  "docs": [
    {
      "key": "/works/OL27448W",
      "title": "The Lord of the Rings",
      "author_name": ["J. R. R. Tolkien"],
      "author_key": ["OL26320A"],
      "first_publish_year": 1954,
      "cover_i": 258027,
      "edition_count": 120,
      "isbn": ["9780261102385", "0261102389"],
      "has_fulltext": true,
      "publisher": ["HarperCollins"],
      "language": ["eng"]
    }
  ]
}
```

### Book Model Properties

The `OpenLibraryBook` model includes:

- **`key`**: Work ID (e.g., "/works/OL27448W")
- **`title`**: Book title
- **`authorNames`**: List of author names
- **`authorKeys`**: List of author Open Library IDs
- **`firstPublishYear`**: Year of first publication
- **`coverId`**: Cover image ID
- **`editionCount`**: Number of editions available
- **`isbn`**: List of ISBNs
- **`hasFulltext`**: Whether full text is available
- **`publisher`**: Primary publisher name
- **`language`**: List of language codes

**Helper Properties:**
- **`primaryAuthor`**: First author name or "Unknown Author"
- **`primaryIsbn`**: First ISBN or null
- **`publishYearFormatted`**: Formatted publish year or "Unknown"

## Usage Examples

### Basic Search Implementation

```dart
import 'package:flutter_application_1/services/open_library_service.dart';
import 'package:flutter_application_1/models/open_library_book.dart';

class BookSearchWidget extends StatefulWidget {
  @override
  _BookSearchWidgetState createState() => _BookSearchWidgetState();
}

class _BookSearchWidgetState extends State<BookSearchWidget> {
  final OpenLibraryService _service = OpenLibraryService();
  List<OpenLibraryBook> _books = [];
  bool _isLoading = false;
  String _error = '';

  Future<void> _searchBooks(String query) async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final books = await _service.searchBooks(query: query, limit: 20);
      setState(() {
        _books = books;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build your UI here
    return Container();
  }
}
```

### Display Book with Cover

```dart
Widget buildBookCard(OpenLibraryBook book) {
  final coverUrl = OpenLibraryService.getCoverUrl(book.coverId, size: 'M');
  
  return Card(
    child: ListTile(
      leading: coverUrl != null
          ? Image.network(
              coverUrl,
              width: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.book);
              },
            )
          : Icon(Icons.book),
      title: Text(book.title),
      subtitle: Text(
        '${book.primaryAuthor} • ${book.publishYearFormatted}',
      ),
      trailing: Text('${book.editionCount} editions'),
    ),
  );
}
```

## Error Handling

The service includes comprehensive error handling:

- **Network Errors**: Catches `SocketException` and connection issues
- **Timeout Errors**: 10-second timeout with custom error messages
- **API Errors**: Handles various HTTP status codes
- **Validation**: Ensures at least one search parameter is provided

## Rate Limiting

Open Library requests that applications making frequent API calls include a User-Agent header. This is already implemented in the service:

```dart
static const Map<String, String> _headers = {
  'User-Agent': 'BucketListApp/1.0 (Flutter Application)',
};
```

For high-volume usage, consider:
- Implementing request caching
- Adding debouncing to search inputs
- Respecting rate limits (see: https://github.com/internetarchive/openlibrary/blob/master/docker/nginx.conf)

## Next Steps

To integrate books into the main app:

1. **Create a Books Category**: Add a "Books" category to the bucket list
2. **Add Search UI**: Create a search interface for finding books
3. **Book Details Screen**: Show detailed book information
4. **Add to Bucket List**: Allow users to add books to their reading list
5. **Track Progress**: Mark books as read/unread
6. **Additional Features**:
   - Save favorite books
   - Add reading notes
   - Track reading dates
   - Link to Open Library for full text (if available)

## Testing

Test the integration with these example searches:

```dart
// Popular books
await service.searchBooks(query: 'Harry Potter');
await service.searchBooks(query: 'The Lord of the Rings');
await service.searchBooks(query: '1984');

// By author
await service.searchByAuthor('Stephen King');
await service.searchByAuthor('Agatha Christie');

// By ISBN
await service.searchByIsbn('9780439708180'); // Harry Potter
```

## Additional Resources

- **Open Library Website**: https://openlibrary.org
- **Developer Center**: https://openlibrary.org/developers
- **OpenAPI Sandbox**: https://openlibrary.org/swagger/docs
- **GitHub Repository**: https://github.com/internetarchive/openlibrary

## Notes

- No API key required
- Free to use
- Covers millions of books
- Includes public domain full texts
- Community-driven data (like Wikipedia for books)
- Some books may have limited metadata
- Cover images may not be available for all books
