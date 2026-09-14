import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SrsState {
  String puzzleId;
  double ease;
  int reps;
  int lapses;
  int intervalMs;
  int dueAt;
  int seenAt;

  SrsState({
    required this.puzzleId,
    this.ease = 2.5,
    this.reps = 0,
    this.lapses = 0,
    this.intervalMs = 0,
    this.dueAt = 0,
    this.seenAt = 0,
  });

  Map<String, dynamic> toJson() => {
        'ease': ease,
        'reps': reps,
        'lapses': lapses,
        'intervalMs': intervalMs,
        'dueAt': dueAt,
        'seenAt': seenAt,
      };

  factory SrsState.fromJson(String puzzleId, Map<String, dynamic> json) {
    return SrsState(
      puzzleId: puzzleId,
      ease: (json['ease'] ?? 2.5).toDouble(),
      reps: json['reps'] ?? 0,
      lapses: json['lapses'] ?? 0,
      intervalMs: json['intervalMs'] ?? 0,
      dueAt: json['dueAt'] ?? 0,
      seenAt: json['seenAt'] ?? 0,
    );
  }
}

class UserMeta {
  double userRating;
  int solved;
  int failed;
  Map<String, ThemeStat> themeStats;

  UserMeta({
    this.userRating = 2100,
    this.solved = 0,
    this.failed = 0,
    Map<String, ThemeStat>? themeStats,
  }) : themeStats = themeStats ?? {};

  Map<String, dynamic> toJson() => {
        'userRating': userRating,
        'solved': solved,
        'failed': failed,
        'themeStats':
            themeStats.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory UserMeta.fromJson(Map<String, dynamic> json) {
    final ts = <String, ThemeStat>{};
    if (json['themeStats'] != null) {
      (json['themeStats'] as Map<String, dynamic>).forEach((k, v) {
        ts[k] = ThemeStat.fromJson(v);
      });
    }
    return UserMeta(
      userRating: (json['userRating'] ?? 2100).toDouble(),
      solved: json['solved'] ?? 0,
      failed: json['failed'] ?? 0,
      themeStats: ts,
    );
  }
}

class ThemeStat {
  int attempts;
  int solved;
  int totalMs;

  ThemeStat({
    this.attempts = 0,
    this.solved = 0,
    this.totalMs = 0,
  });

  Map<String, dynamic> toJson() => {
        'attempts': attempts,
        'solved': solved,
        'totalMs': totalMs,
      };

  factory ThemeStat.fromJson(Map<String, dynamic> json) {
    return ThemeStat(
      attempts: json['attempts'] ?? 0,
      solved: json['solved'] ?? 0,
      totalMs: json['totalMs'] ?? 0,
    );
  }
}

class SrsService {
  static const _key = 'srs_state';
  Map<String, SrsState> states = {};
  UserMeta meta = UserMeta();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final parsed = jsonDecode(raw);
      final srs = parsed['srsState'] as Map<String, dynamic>? ?? {};
      srs.forEach((k, v) {
        states[k] = SrsState.fromJson(k, v);
      });
      meta = UserMeta.fromJson(parsed['meta'] ?? {});
    } catch (_) {}
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'srsState': states.map((k, v) => MapEntry(k, v.toJson())),
      'meta': meta.toJson(),
    };
    await prefs.setString(_key, jsonEncode(data));
  }

  SrsState? getState(String puzzleId) => states[puzzleId];

  void setState(String puzzleId, SrsState state) {
    states[puzzleId] = state;
  }
}
