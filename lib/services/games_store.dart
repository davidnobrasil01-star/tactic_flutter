import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/game.dart';

class GamesStore {
  List<Game> games = [];
  String? lastId;

  Future<void> init() async {
    const partFiles = [
      'assets/games_part0.jsonl',
      'assets/games_part1.jsonl',
      'assets/games_part2.jsonl',
    ];
    for (final file in partFiles) {
      try {
        final raw = await rootBundle.loadString(file);
        final lines = raw.split('\n');
        for (final line in lines) {
          if (line.isEmpty) continue;
          try {
            final json = jsonDecode(line) as Map<String, dynamic>;
            games.add(Game.fromJson(json));
          } catch (_) {}
        }
      } catch (_) {}
    }
  }

  Game? getRandomGame() {
    if (games.isEmpty) return null;
    Game game;
    do {
      game = games[Random().nextInt(games.length)];
    } while (games.length > 1 && game.id == lastId);
    lastId = game.id;
    return game;
  }

  int get totalGames => games.length;
}
