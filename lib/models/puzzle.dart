class Puzzle {
  final String id;
  final String fen;
  final List<String> moves;
  final int rating;
  final List<String> themes;
  final bool isReview;

  Puzzle({
    required this.id,
    required this.fen,
    required this.moves,
    required this.rating,
    required this.themes,
    this.isReview = false,
  });

  factory Puzzle.fromJson(Map<String, dynamic> json) {
    return Puzzle(
      id: json['id'] ?? '',
      fen: json['fen'] ?? '',
      moves: List<String>.from(json['moves'] ?? []),
      rating: json['rating'] ?? 0,
      themes: List<String>.from(json['themes'] ?? []),
    );
  }
}
