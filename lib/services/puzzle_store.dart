import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/puzzle.dart';
import '../services/srs_service.dart';
import '../utils/themes_es.dart';

class PuzzleStore {
  List<Puzzle> pool = [];
  Map<String, Puzzle> byId = {};
  SrsService srs = SrsService();
  static const int _initialWindow = 100;
  static const int _windowStep = 100;
  static const int _maxWindow = 1500;
  static const int _kFactor = 24;
  static const double _startEase = 2.5;
  static const double _minEase = 1.3;
  static const int _learnStep1Ms = 10 * 60 * 1000;
  static const int _learnStep2Ms = 24 * 60 * 60 * 1000;

  Future<void> init() async {
    await srs.load();
    await _loadPool();
  }

  Future<void> _loadPool() async {
    final raw = await rootBundle.loadString('assets/puzzles.jsonl');
    final lines = raw.split('\n');
    final list = <Puzzle>[];
    for (final line in lines) {
      if (line.isEmpty) continue;
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        final moves = (json['moves'] as List?)
                ?.map((m) => m is String
                    ? m
                    : (m as Map<String, dynamic>)['san']?.toString() ??
                        (m as Map<String, dynamic>).values.first.toString())
                .toList() ??
            [];
        list.add(Puzzle(
          id: json['id'] ?? '',
          fen: json['fen'] ?? '',
          moves: moves,
          rating: json['rating'] ?? 0,
          themes: List<String>.from(json['themes'] ?? []),
        ));
      } catch (_) {}
    }
    list.sort((a, b) => a.rating.compareTo(b.rating));
    pool = list;
    byId = {for (var p in pool) p.id: p};
  }

  int _lowerBound(int target) {
    int lo = 0, hi = pool.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (pool[mid].rating < target) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  double _weaknessWeight(Puzzle puzzle) {
    double worst = 0;
    for (final tag in trackableThemes(puzzle.themes)) {
      final s = srs.meta.themeStats[tag];
      if (s == null || s.attempts < 2) continue;
      final successRate = s.solved / s.attempts;
      final avgMs = s.solved > 0 ? s.totalMs / s.solved : 60000.0;
      final weak = (1 - successRate) * 2.5 + avgMs / 60000.0;
      if (weak > worst) worst = weak;
    }
    return 1 + worst;
  }

  Puzzle _weightedPick(List<Puzzle> candidates) {
    final weights = candidates.map(_weaknessWeight).toList();
    final total = weights.reduce((a, b) => a + b);
    final r = Random().nextDouble() * total;
    double acc = 0;
    for (int i = 0; i < candidates.length; i++) {
      acc += weights[i];
      if (r <= acc) return candidates[i];
    }
    return candidates.last;
  }

  Puzzle _pickNewPuzzle() {
    int window = _initialWindow;
    while (window <= _maxWindow) {
      final lo = _lowerBound((srs.meta.userRating - window).round());
      final hi = _lowerBound((srs.meta.userRating + window).round());
      final candidates = <Puzzle>[];
      for (int i = lo; i < hi && candidates.length < 500; i++) {
        final p = pool[i];
        if (srs.getState(p.id) == null) candidates.add(p);
      }
      if (candidates.isNotEmpty) return _weightedPick(candidates);
      window += _windowStep;
    }
    final unseen = pool.where((p) => srs.getState(p.id) == null).toList();
    if (unseen.isNotEmpty) return _weightedPick(unseen);
    return pool[Random().nextInt(pool.length)];
  }

  Puzzle? _getDueReview() {
    final now = DateTime.now().millisecondsSinceEpoch;
    String? bestId;
    for (final entry in srs.states.entries) {
      if (entry.value.dueAt <= now) {
        if (bestId == null || entry.value.dueAt < srs.states[bestId]!.dueAt) {
          bestId = entry.key;
        }
      }
    }
    return bestId != null ? byId[bestId] : null;
  }

  PuzzleResult getNextPuzzle() {
    final due = _getDueReview();
    final puzzle = due ?? _pickNewPuzzle();
    final isReview = srs.getState(puzzle.id) != null;
    return PuzzleResult(
      puzzle: puzzle,
      isReview: isReview,
      userRating: srs.meta.userRating.round(),
    );
  }

  ReportResult reportResult(String puzzleId, bool success, int timeMs) {
    final puzzle = byId[puzzleId];
    if (puzzle == null) return ReportResult(success: false);

    const fastMs = 15000;
    const normalMs = 40000;
    String speedTier = 'slow';
    if (timeMs < fastMs) {
      speedTier = 'fast';
    } else if (timeMs < normalMs) {
      speedTier = 'normal';
    }

    final ratingScore =
        !success ? 0.0 : (speedTier == 'slow' ? 0.8 : 1.0);
    final expected =
        1 / (1 + pow(10, (puzzle.rating - srs.meta.userRating) / 400));
    srs.meta.userRating += _kFactor * (ratingScore - expected);
    srs.meta.userRating =
        srs.meta.userRating.clamp(1600, 3200).toDouble();
    if (success) {
      srs.meta.solved++;
    } else {
      srs.meta.failed++;
    }

    _updateThemeStats(puzzle, success, timeMs);

    final prev = srs.getState(puzzle.id);
    final now = DateTime.now().millisecondsSinceEpoch;
    SrsState nextState;

    if (success) {
      final reps = (prev?.reps ?? 0) + 1;
      double easeDelta = 0;
      if (speedTier == 'fast') {
        easeDelta = 0.1;
      } else if (speedTier == 'normal') {
        easeDelta = 0.05;
      }
      final ease = (_startEase + easeDelta).clamp(0, 3.2);
      int intervalMs;
      if (reps == 1) {
        intervalMs = _learnStep1Ms;
      } else if (reps == 2) {
        intervalMs = _learnStep2Ms;
      } else {
        final growth = speedTier == 'slow' ? 1.2 : ease;
        intervalMs = ((prev?.intervalMs ?? _learnStep2Ms) * growth).round();
      }
      nextState = SrsState(
        puzzleId: puzzleId,
        ease: ease,
        reps: reps,
        lapses: prev?.lapses ?? 0,
        intervalMs: intervalMs,
        dueAt: now + intervalMs,
        seenAt: now,
      );
    } else {
      nextState = SrsState(
        puzzleId: puzzleId,
        ease: (_minEase).clamp(_minEase, prev?.ease ?? _startEase - 0.2),
        reps: 0,
        lapses: (prev?.lapses ?? 0) + 1,
        intervalMs: _learnStep1Ms,
        dueAt: now + _learnStep1Ms,
        seenAt: now,
      );
    }

    srs.setState(puzzleId, nextState);
    srs.save();

    final patternTag = primaryTrackedTheme(puzzle.themes);
    final patternStats =
        patternTag != null ? srs.meta.themeStats[patternTag] : null;

    return ReportResult(
      success: true,
      userRating: srs.meta.userRating.round(),
      nextDueInMs: nextState.intervalMs,
      reps: nextState.reps,
      speedTier: speedTier,
      patternTag: patternTag,
      patternLabel:
          patternTag != null ? THEMES_ES[patternTag] : null,
      patternAttempts: patternStats?.attempts,
      patternSolved: patternStats?.solved,
      patternAvgMs: patternStats != null && patternStats.solved > 0
          ? (patternStats.totalMs / patternStats.solved).round()
          : null,
    );
  }

  String? primaryTrackedTheme(List<String> themes) {
    final tags = trackableThemes(themes);
    return tags.isNotEmpty ? tags.first : null;
  }

  void _updateThemeStats(Puzzle puzzle, bool success, int timeMs) {
    for (final tag in trackableThemes(puzzle.themes)) {
      final s = srs.meta.themeStats[tag] ??
          ThemeStat(attempts: 0, solved: 0, totalMs: 0);
      s.attempts++;
      if (success) {
        s.solved++;
        s.totalMs += timeMs;
      }
      srs.meta.themeStats[tag] = s;
    }
  }

  Map<String, dynamic> getStats() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final dueCount =
        srs.states.values.where((s) => s.dueAt <= now).length;
    return {
      'totalPuzzles': pool.length,
      'seenCount': srs.states.length,
      'dueCount': dueCount,
      'userRating': srs.meta.userRating.round(),
      'solved': srs.meta.solved,
      'failed': srs.meta.failed,
    };
  }
}

class PuzzleResult {
  final Puzzle puzzle;
  final bool isReview;
  final int userRating;

  PuzzleResult({
    required this.puzzle,
    required this.isReview,
    required this.userRating,
  });
}

class ReportResult {
  final bool success;
  final int? userRating;
  final int? nextDueInMs;
  final int? reps;
  final String? speedTier;
  final String? patternTag;
  final String? patternLabel;
  final int? patternAttempts;
  final int? patternSolved;
  final int? patternAvgMs;

  ReportResult({
    required this.success,
    this.userRating,
    this.nextDueInMs,
    this.reps,
    this.speedTier,
    this.patternTag,
    this.patternLabel,
    this.patternAttempts,
    this.patternSolved,
    this.patternAvgMs,
  });
}
