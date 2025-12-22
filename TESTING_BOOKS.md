# Testing the Books Integration

This guide explains how to test the Open Library API integration.

## Quick Start

The app is currently configured to show the Book Search Example screen for testing.

### Running the Test

1. Make sure you're on the `feature/books-integration` branch:
   ```bash
   git branch
   ```

2. Run the Flutter app:
   ```bash
   flutter run
   ```

3. The app will open directly to the Book Search screen.

## Testing Scenarios

### 1. General Search
- Select "General" search type
- Try these searches:
  - `Harry Potter`
  - `The Lord of the Rings`
  - `1984`
  - `To Kill a Mockingbird`

### 2. Title Search
- Select "Title" search type
- Search for specific book titles:
  - `Pride and Prejudice`
  - `The Great Gatsby`
  - `Moby Dick`

### 3. Author Search
- Select "Author" search type
- Search for authors:
  - `J.K. Rowling`
  - `Stephen King`
  - `Agatha Christie`
  - `Ernest Hemingway`

### 4. ISBN Search
- Select "ISBN" search type
- Try these ISBNs:
  - `9780439708180` (Harry Potter and the Sorcerer's Stone)
  - `9780061120084` (To Kill a Mockingbird)
  - `9780451524935` (1984)

## Expected Behavior

### Search Results
- Results should appear within 1-2 seconds
- Each book card should show:
  - Cover image (if available)
  - Book title
  - Primary author
  - Publication year
  - Number of editions
  - "Full text" badge (if available)

### Book Details
- Tap any book card to see detailed information
- Details should include:
  - Large cover image
  - Full title
  - All authors
  - First publication year
  - Number of editions
  - Publisher (if available)
  - ISBN (if available)
  - Languages

### Error Handling
Test error scenarios:
1. **No Internet**: Turn off internet and search - should show network error
2. **Empty Search**: Try searching with empty text - nothing should happen
3. **No Results**: Search for gibberish - should show "No books found"

## Switching Back to Main App

To switch back to the normal bucket list app:

1. Open `lib/main.dart`
2. Change line 18 from:
   ```dart
   home: const BookSearchExample(), // Testing books integration
   ```
   to:
   ```dart
   home: const HomeScreen(), // Original home screen
   ```

## Files to Review

### Core Implementation
- **Model**: `lib/models/open_library_book.dart`
- **Service**: `lib/services/open_library_service.dart`
- **Example Widget**: `lib/widgets/book_search_example.dart`

### Documentation
- **Integration Guide**: `BOOKS_INTEGRATION.md`

## API Endpoints Being Used

The integration uses these Open Library endpoints:

1. **Search API**:
   - URL: `https://openlibrary.org/search.json`
   - Parameters: `q`, `title`, `author`, `limit`, `page`, `sort`, `fields`

2. **Covers API**:
   - URL: `https://covers.openlibrary.org/b/id/{cover_id}-{size}.jpg`
   - Sizes: S (small), M (medium), L (large)

## Network Monitoring

To see API calls in action, check the debug console for:
- `Fetching books from: ...` - Shows the API URL being called
- `Response status code: ...` - Shows HTTP response status
- `Found X total books, returning Y results` - Shows search results count

## Next Steps

After testing, you can:

1. **Integrate into Main App**:
   - Add a "Books" category
   - Create a dedicated books screen
   - Add book search to the add item flow

2. **Enhance Features**:
   - Add book to bucket list functionality
   - Mark books as read/unread
   - Add reading notes
   - Track reading dates
   - Link to Open Library for full text

3. **Improve UI**:
   - Add loading skeletons
   - Implement infinite scroll
   - Add search history
   - Add favorites/bookmarks

## Troubleshooting

### Issue: No cover images showing
- **Cause**: Some books don't have cover images in Open Library
- **Solution**: This is expected; the app shows a placeholder icon

### Issue: Network error
- **Cause**: No internet connection or Open Library is down
- **Solution**: Check internet connection; Open Library is usually very reliable

### Issue: Slow search results
- **Cause**: Network latency or large result sets
- **Solution**: The API has a 10-second timeout; results typically arrive in 1-2 seconds

### Issue: App crashes on search
- **Cause**: Likely a parsing error with unexpected API response
- **Solution**: Check the debug console for error messages and report the search query

## Feedback

When testing, note:
- Search performance
- UI responsiveness
- Cover image loading
- Error message clarity
- Overall user experience

## Reverting Changes

To revert all changes and go back to the previous branch:

```bash
git checkout feature/confetti-ui-test
```

Or to keep the changes but switch branches:

```bash
git stash
git checkout feature/confetti-ui-test
```
