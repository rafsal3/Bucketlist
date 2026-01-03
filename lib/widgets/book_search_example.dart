import 'package:flutter/material.dart';
import '../models/open_library_book.dart';
import '../services/open_library_service.dart';
import '../utils/toast_helper.dart';

/// Example widget demonstrating how to search for books using Open Library API
/// This is a reference implementation that can be integrated into the main app
class BookSearchExample extends StatefulWidget {
  const BookSearchExample({super.key});

  @override
  State<BookSearchExample> createState() => _BookSearchExampleState();
}

class _BookSearchExampleState extends State<BookSearchExample> {
  final OpenLibraryService _service = OpenLibraryService();
  final TextEditingController _searchController = TextEditingController();

  List<OpenLibraryBook> _books = [];
  bool _isLoading = false;
  String _error = '';
  String _searchType = 'general'; // general, title, author, isbn

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchBooks() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = '';
      _books = [];
    });

    try {
      List<OpenLibraryBook> results;

      switch (_searchType) {
        case 'title':
          results = await _service.searchByTitle(query, limit: 20);
          break;
        case 'author':
          results = await _service.searchByAuthor(query, limit: 20);
          break;
        case 'isbn':
          results = await _service.searchByIsbn(query);
          break;
        default:
          results = await _service.searchBooks(query: query, limit: 20);
      }

      setState(() {
        _books = results;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Search Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Search controls
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Search type selector
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'general',
                      label: Text('General'),
                      icon: Icon(Icons.search),
                    ),
                    ButtonSegment(
                      value: 'title',
                      label: Text('Title'),
                      icon: Icon(Icons.book),
                    ),
                    ButtonSegment(
                      value: 'author',
                      label: Text('Author'),
                      icon: Icon(Icons.person),
                    ),
                    ButtonSegment(
                      value: 'isbn',
                      label: Text('ISBN'),
                      icon: Icon(Icons.numbers),
                    ),
                  ],
                  selected: {_searchType},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _searchType = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Search field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: _getHintText(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _books = [];
                                _error = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: (_) => _searchBooks(),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),

                // Search button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _searchBooks,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isLoading ? 'Searching...' : 'Search Books'),
                  ),
                ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  String _getHintText() {
    switch (_searchType) {
      case 'title':
        return 'Enter book title...';
      case 'author':
        return 'Enter author name...';
      case 'isbn':
        return 'Enter ISBN...';
      default:
        return 'Search for books...';
    }
  }

  Widget _buildResults() {
    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _error,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _searchBooks,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_books.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No books found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching for a book, author, or ISBN',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _books.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        final book = _books[index];
        return _buildBookCard(book);
      },
    );
  }

  Widget _buildBookCard(OpenLibraryBook book) {
    final coverUrl = OpenLibraryService.getCoverUrl(book.coverId, size: 'M');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showBookDetails(book),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: coverUrl != null
                    ? Image.network(
                        coverUrl,
                        width: 60,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholderCover();
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _buildPlaceholderCover();
                        },
                      )
                    : _buildPlaceholderCover(),
              ),
              const SizedBox(width: 12),

              // Book info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.primaryAuthor,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[700],
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (book.firstPublishYear != null)
                          Chip(
                            label: Text(
                              book.publishYearFormatted,
                              style: const TextStyle(fontSize: 12),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        Chip(
                          label: Text(
                            '${book.editionCount} edition${book.editionCount != 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        if (book.hasFulltext)
                          const Chip(
                            label: Text(
                              'Full text',
                              style: TextStyle(fontSize: 12),
                            ),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Colors.green,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      width: 60,
      height: 90,
      color: Colors.grey[300],
      child: const Icon(Icons.book, size: 32, color: Colors.grey),
    );
  }

  void _showBookDetails(OpenLibraryBook book) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          final coverUrl =
              OpenLibraryService.getCoverUrl(book.coverId, size: 'L');

          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover image
                if (coverUrl != null)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        coverUrl,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.book, size: 100);
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // Title
                Text(
                  book.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),

                // Authors
                Text(
                  'by ${book.authorNames.join(', ')}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                ),
                const SizedBox(height: 24),

                // Details
                _buildDetailRow('First Published', book.publishYearFormatted),
                _buildDetailRow('Editions', book.editionCount.toString()),
                if (book.publisher != null)
                  _buildDetailRow('Publisher', book.publisher!),
                if (book.primaryIsbn != null)
                  _buildDetailRow('ISBN', book.primaryIsbn!),
                if (book.language.isNotEmpty)
                  _buildDetailRow('Languages', book.language.join(', ')),

                const SizedBox(height: 24),

                // Actions
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Add to bucket list
                      Navigator.pop(context);
                      ToastHelper.showSuccess(context, 'Book added');
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add to Bucket List'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
