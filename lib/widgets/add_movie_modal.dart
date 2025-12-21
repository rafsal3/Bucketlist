import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/tmdb_service.dart';
import '../models/tmdb_movie.dart';
import '../theme/app_theme.dart';

class AddMovieModal extends StatefulWidget {
  final String categoryId;

  const AddMovieModal({
    super.key,
    required this.categoryId,
  });

  @override
  State<AddMovieModal> createState() => _AddMovieModalState();
}

class _AddMovieModalState extends State<AddMovieModal> {
  final TextEditingController _searchController = TextEditingController();
  final TMDBService _tmdbService = TMDBService();
  List<TMDBMovie> _searchResults = [];
  bool _isLoading = false;
  String? _error;

  Future<void> _searchMovies() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _tmdbService.searchMovies(query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to search movies. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _addMovie(TMDBMovie movie) {
    final appState = Provider.of<AppState>(context, listen: false);
    String title = movie.title;
    if (movie.releaseDate.isNotEmpty) {
      title += ' (${movie.releaseDate.split('-').first})';
    }
    appState.addItem(
      widget.categoryId,
      title,
      imageUrl: TMDBService.getPosterUrl(movie.posterPath),
      description: movie.overview,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppTheme.surface,
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
              color: AppTheme.textSecondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 24),

          Text(
            'Search Movies',
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
                    hintText: 'Enter movie title...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchMovies(),
                ),
              ),
              SizedBox(width: 12),
              IconButton(
                onPressed: _searchMovies,
                icon: Icon(Icons.send, color: AppTheme.accent),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.accent.withOpacity(0.1),
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
                        child:
                            Text(_error!, style: TextStyle(color: Colors.red)))
                    : _searchResults.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.movie_creation_outlined,
                                    size: 64, color: AppTheme.textSecondary),
                                SizedBox(height: 16),
                                Text('Search for your favorite movies',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final movie = _searchResults[index];
                              final posterUrl =
                                  TMDBService.getPosterUrl(movie.posterPath);

                              return ListTile(
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 8),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: posterUrl != null
                                      ? Image.network(
                                          posterUrl,
                                          width: 50,
                                          height: 75,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                                      width: 50,
                                                      height: 75,
                                                      color: Colors.grey[300],
                                                      child: Icon(Icons.movie)),
                                        )
                                      : Container(
                                          width: 50,
                                          height: 75,
                                          color: Colors.grey[300],
                                          child: Icon(Icons.movie,
                                              color: Colors.grey[600]),
                                        ),
                                ),
                                title: Text(
                                  movie.title,
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  movie.overview,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.add_circle_outline,
                                      color: AppTheme.accent),
                                  onPressed: () => _addMovie(movie),
                                ),
                                onTap: () => _addMovie(movie),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
