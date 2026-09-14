import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess;
import '../widgets/chess_board.dart';
import '../services/puzzle_store.dart';

String _squareName(int row, int col) {
  return String.fromCharCode(97 + col) + (8 - row).toString();
}

class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key});

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  final PuzzleStore _store = PuzzleStore();
  chess.Chess _engine = chess.Chess();
  PuzzleResult? _currentPuzzle;
  List<String> _solutionMoves = [];
  List<String> _solutionSan = [];
  int _moveIndex = 0;
  bool _ended = false;
  bool _solved = false;
  bool _isBusy = false;
  String _orientation = 'white';
  DateTime? _startedAt;
  Timer? _timer;
  int _timeLeft = 60;
  String _hint = '';
  ReportResult? _lastResult;
  double _squareSize = 40;
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _store.init();
    _loadNextPuzzle();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Map<String, String> _getPieces() {
    final pieces = <String, String>{};
    final board = _engine.board;
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final piece = board[r][c];
        if (piece != null) {
          final square = _squareName(r, c);
          final color = piece.color == chess.Color.WHITE ? 'w' : 'b';
          final type = piece.type.name.toUpperCase();
          pieces[square] = '$color$type';
        }
      }
    }
    return pieces;
  }

  String? _getCheckSquare() {
    if (!_engine.in_check) return null;
    final board = _engine.board;
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final piece = board[r][c];
        if (piece != null &&
            piece.type == chess.PieceType.KING &&
            piece.color == _engine.turn) {
          return _squareName(r, c);
        }
      }
    }
    return null;
  }

  String? _lastMoveFrom;
  String? _lastMoveTo;

  void _loadNextPuzzle() {
    _timer?.cancel();
    setState(() {
      _ended = false;
      _solved = false;
      _isBusy = false;
      _lastResult = null;
      _hint = '';
      _lastMoveFrom = null;
      _lastMoveTo = null;
    });

    final result = _store.getNextPuzzle();
    _currentPuzzle = result;
    _orientation = result.puzzle.fen.split(' ')[1] == 'w' ? 'white' : 'black';

    _engine = chess.Chess();
    _engine.load(result.puzzle.fen);

    // Pre-calculate SAN solution
    _solutionSan = [];
    final tempEngine = chess.Chess();
    tempEngine.load(result.puzzle.fen);
    for (final uci in result.puzzle.moves) {
      final from = uci.substring(0, 2);
      final to = uci.substring(2, 4);
      final promo = uci.length > 4 ? uci[4] : null;
      try {
        final mv = tempEngine.move({
          'from': from,
          'to': to,
          'promotion': promo,
        });
        if (mv != null) _solutionSan.add(mv.san);
      } catch (_) {}
    }

    // Play opening move
    _engine = chess.Chess();
    _engine.load(result.puzzle.fen);
    _solutionMoves = result.puzzle.moves;
    _moveIndex = 0;
    _applyUciMove(_solutionMoves[0]);
    _moveIndex = 1;

    _startTimer();
  }

  bool _applyUciMove(String uci) {
    final from = uci.substring(0, 2);
    final to = uci.substring(2, 4);
    final promo = uci.length > 4 ? uci[4] : null;
    try {
      final mv = _engine.move({
        'from': from,
        'to': to,
        'promotion': promo,
      });
      if (mv != null) {
        _lastMoveFrom = from;
        _lastMoveTo = to;
      }
      return mv != null;
    } catch (_) {
      return false;
    }
  }

  void _attemptUserMove(String from, String to) {
    if (_ended || _isBusy) return;
    if (_startedAt == null) return;

    final piece = _engine.get(from);
    if (piece == null || piece.color != _engine.turn) return;

    if (_moveIndex >= _solutionMoves.length) return;
    final expected = _solutionMoves[_moveIndex];
    final expFrom = expected.substring(0, 2);
    final expTo = expected.substring(2, 4);
    final promo = expected.length > 4 ? expected[4] : null;

    try {
      final mv = _engine.move({
        'from': from,
        'to': to,
        'promotion': promo ?? 'q',
      });
      if (mv == null) return;

      if (from == expFrom && to == expTo) {
        _lastMoveFrom = from;
        _lastMoveTo = to;
        _moveIndex++;
        setState(() {});

        if (_engine.in_checkmate || _moveIndex >= _solutionMoves.length) {
          _onPuzzleSolved();
          return;
        }

        setState(() => _hint = 'Bien. Respuesta forzada del rival...');
        _isBusy = true;
        Future.delayed(const Duration(milliseconds: 450), () {
          _applyUciMove(_solutionMoves[_moveIndex]);
          _moveIndex++;
          _isBusy = false;
          setState(() {});

          if (_engine.in_checkmate || _moveIndex >= _solutionMoves.length) {
            _onPuzzleSolved();
          } else {
            setState(() => _hint = 'Tu turno: continuá la combinación.');
          }
        });
      } else {
        _engine.undo();
        setState(() {});
        _onPuzzleFailed('wrong-move');
      }
    } catch (_) {}
  }

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = 60;
    _startedAt = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_startedAt == null) return;
      final elapsed = DateTime.now().difference(_startedAt!).inMilliseconds;
      final left = 60 - (elapsed / 1000).ceil();
      if (left != _timeLeft) {
        setState(() => _timeLeft = left.clamp(0, 60));
      }
      if (elapsed >= 60000) {
        _onPuzzleFailed('timeout');
      }
    });
  }

  void _onPuzzleSolved() {
    _timer?.cancel();
    setState(() {
      _ended = true;
      _solved = true;
      _hint = '¡Mate!';
    });
    final timeMs = DateTime.now().difference(_startedAt!).inMilliseconds;
    final result = _store.reportResult(
      _currentPuzzle!.puzzle.id,
      true,
      timeMs,
    );
    setState(() => _lastResult = result);
  }

  void _onPuzzleFailed(String reason) {
    _timer?.cancel();
    final timeMs = DateTime.now().difference(_startedAt!).inMilliseconds;
    final result = _store.reportResult(
      _currentPuzzle!.puzzle.id,
      false,
      timeMs,
    );
    setState(() {
      _ended = true;
      _solved = false;
      _hint = reason == 'timeout'
          ? 'Se acabó el tiempo.'
          : 'Ese no era el mate.';
      _lastResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPuzzle == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final stats = _store.getStats();

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  if (_currentPuzzle!.isReview)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7fa650),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'R',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1b1b1b),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    '${_currentPuzzle!.puzzle.rating} ELO',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFa5a49f),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '· ${stats['solved']}✓',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7fa650),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: _timeLeft / 60,
                          strokeWidth: 4,
                          backgroundColor: const Color(0xFF3d3a36),
                          valueColor: AlwaysStoppedAnimation(
                            _timeLeft <= 10
                                ? const Color(0xFFc8462a)
                                : const Color(0xFF7fa650),
                          ),
                        ),
                        Text(
                          '$_timeLeft',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _timeLeft <= 10
                                ? const Color(0xFFc8462a)
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: ChessBoard(
                pieces: _getPieces(),
                orientation: _orientation,
                selectedSquare: null,
                lastMoveFrom: _lastMoveFrom,
                lastMoveTo: _lastMoveTo,
                checkSquare: _getCheckSquare(),
                squareSize: _squareSize,
                onSquareTap: (square) => _handleSquareTap(square),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _hint.isNotEmpty
                  ? _hint
                  : (_orientation == 'white'
                      ? 'Juegan blancas. Encontrá el mate en 2.'
                      : 'Juegan negras. Encontrá el mate en 2.'),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFa5a49f),
              ),
            ),
            if (_ended) ...[
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF302e2c),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      _solved
                          ? '¡Correcto! Mate en 2 resuelto.'
                          : _hint,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _solved
                            ? const Color(0xFF7fa650)
                            : const Color(0xFFc8462a),
                      ),
                    ),
                    if (_lastResult?.patternLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Patrón: ${_lastResult!.patternLabel}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFd8b45c),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Solución: ${_solutionSan.skip(1).join("  ")}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFa5a49f),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _loadNextPuzzle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7fa650),
                        foregroundColor: const Color(0xFF1b1b1b),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text(
                        'Siguiente',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      _isMaximized ? Icons.maximize : Icons.minimize,
                      color: const Color(0xFFa5a49f),
                    ),
                    onPressed: () {
                      setState(() {
                        _isMaximized = !_isMaximized;
                        _squareSize = _isMaximized ? 70 : 40;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSquareTap(String square) {
    if (_ended || _isBusy) return;

    final piece = _engine.get(square);
    final turnColor = _engine.turn;

    if (piece != null && piece.color == turnColor) {
      _showMoveOptions(square);
    }
  }

  void _showMoveOptions(String fromSquare) {
    final moves = _engine.getLegalMoves()
        .where((m) => m.startsWith(fromSquare))
        .toList();

    if (moves.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF262421),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Movimientos desde $fromSquare',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: moves.map((m) {
                final to = m.substring(2, 4);
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _attemptUserMove(fromSquare, to);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3d3a36),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      m,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
