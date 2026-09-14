class GameMove {
  final String san;
  final String? eval_;
  final int? depth;
  final List<String>? pv;
  final bool? book;

  GameMove({
    required this.san,
    this.eval_,
    this.depth,
    this.pv,
    this.book,
  });

  factory GameMove.fromJson(Map<String, dynamic> json) {
    return GameMove(
      san: json['san'] ?? '',
      eval_: json['eval'],
      depth: json['depth'],
      pv: json['pv'] != null ? List<String>.from(json['pv']) : null,
      book: json['book'],
    );
  }
}

class Game {
  final String id;
  final String white;
  final String black;
  final int? whiteElo;
  final int? blackElo;
  final String result;
  final String winner;
  final String event;
  final String eco;
  final String opening;
  final List<GameMove> moves;

  Game({
    required this.id,
    required this.white,
    required this.black,
    this.whiteElo,
    this.blackElo,
    required this.result,
    required this.winner,
    required this.event,
    required this.eco,
    required this.opening,
    required this.moves,
  });

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'] ?? '',
      white: json['white'] ?? '',
      black: json['black'] ?? '',
      whiteElo: json['whiteElo'],
      blackElo: json['blackElo'],
      result: json['result'] ?? '',
      winner: json['winner'] ?? '',
      event: json['event'] ?? '',
      eco: json['eco'] ?? '',
      opening: json['opening'] ?? '',
      moves: (json['moves'] as List?)
              ?.map((m) => GameMove.fromJson(m))
              .toList() ??
          [],
    );
  }
}
