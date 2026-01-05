import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/open_library_service.dart';
import '../models/open_library_book.dart';
import '../utils/toast_helper.dart';

class AddBookModal extends StatefulWidget {
  final String? categoryId;

  const AddBookModal({
    super.key,
    this.categoryId,
  });

  @override
  State<AddBookModal> createState() => _AddBookModalState();
}

class _AddBookModalState extends State<AddBookModal> {
  final TextEditingController _searchController = TextEditingController();
  final OpenLibraryService _service = OpenLibraryService();
  List<OpenLibraryBook> _searchResults = [];
  bool _isLoading = false;
  String? _error;

  Future<void> _searchBooks() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _service.searchBooks(query: query, limit: 20);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _addBook(OpenLibraryBook book) {
    final appState = Provider.of<AppState>(context, listen: false);
    String title = book.title;
    // Add author to title for clarity in the list
    if (book.primaryAuthor.isNotEmpty) {
      title += ' by ${book.primaryAuthor}';
    }

    appState.addItem(
      widget.categoryId,
      title,
      imageUrl: OpenLibraryService.getCoverUrl(book.coverId, size: 'M'),
      description: 'Published: ${book.publishYearFormatted}',
    );
    Navigator.pop(context);

    ToastHelper.showSuccess(context, 'Book added');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 24),

          Text(
            'Search Books',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 24),

          // Search Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Enter book title or author...',
                    prefixIcon: Icon(Icons.menu_book_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchBooks(),
                ),
              ),
              SizedBox(width: 12),
              IconButton(
                onPressed: _searchBooks,
                icon: Icon(Icons.send,
                    color: Theme.of(context).colorScheme.primary),
                style: IconButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          SizedBox(height: 24),

          // Results
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red,
                            ),
                            SizedBox(height: 16),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                _error!,
                                style: TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _searchBooks,
                              child: Text('Try Again'),
                            ),
                          ],
                        ),
                      )
                    : _searchResults.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.menu_book_rounded,
                                    size: 64,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color),
                                SizedBox(height: 16),
                                Text('Search for your favorite books',
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final book = _searchResults[index];
                              final coverUrl = OpenLibraryService.getCoverUrl(
                                  book.coverId,
                                  size: 'S');

                              return ListTile(
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 8),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: coverUrl != null
                                      ? Image.network(
                                          coverUrl,
                                          width: 50,
                                          height: 75,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                                      width: 50,
                                                      height: 75,
                                                      color: Colors.grey[300],
                                                      child: Icon(Icons.book)),
                                        )
                                      : Container(
                                          width: 50,
                                          height: 75,
                                          color: Colors.grey[300],
                                          child: Icon(Icons.book,
                                              color: Colors.grey[600]),
                                        ),
                                ),
                                title: Text(
                                  book.title,
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (book.primaryAuthor.isNotEmpty)
                                      Text(
                                        book.primaryAuthor,
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    Text(
                                      book.publishYearFormatted,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.add_circle_outline,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  onPressed: () => _addBook(book),
                                ),
                                onTap: () => _addBook(book),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
