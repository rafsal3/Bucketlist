class TMDBMovie {
  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final String releaseDate;

  TMDBMovie({
    required this.id,
    required this.title,
    required this.overview,
    this.posterPath,
    required this.releaseDate,
  });

  factory TMDBMovie.fromJson(Map<String, dynamic> json) {
    return TMDBMovie(
      id: json['id'],
      title: json['title'] ?? 'Unknown Title',
      overview: json['overview'] ?? '',
      posterPath: json['poster_path'],
      releaseDate: json['release_date'] ?? '',
    );
  }
}
