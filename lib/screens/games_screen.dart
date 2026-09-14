import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess;
import '../widgets/chess_board.dart';
import '../models/game.dart';
import '../services/games_store.dart';

Map<String, String> _buildPiecesMap(chess.Chess engine) {
  final pieces = <String, String>{};
  for (var i = 0; i < 128; i++) {
    if ((i & 0x88) != 0) continue;
    final piece = engine.board[i];
    if (piece == null) continue;
    final square = chess.Chess.algebraic(i);
    final color = piece.color == chess.Color.WHITE ? 'w' : 'b';
    final type = piece.type.name.toUpperCase();
    pieces[square] = '$color$type';
  }
  return pieces;
}

String? _findKingSquare(chess.Chess engine, chess.Color color) {
  final kingSq = engine.kings[color];
  if (kingSq == -1) return null;
  return chess.Chess.algebraic(kingSq);
}

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  final GamesStore _store = GamesStore();
  chess.Chess _engine = chess.Chess();
  Game? _currentGame;
  int _moveIndex = 0;
  bool _isPlaying = false;
  Timer? _autoplayTimer;
  double _squareSize = 40;
  bool _isMaximized = false;
  bool _loading = true;
  String? _lastMoveFrom;
  String? _lastMoveTo;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _store.init();
    setState(() => _loading = false);
    _loadRandomGame();
  }

  @override
  void dispose() {
    _autoplayTimer?.cancel();
    super.dispose();
  }

  String? _getCheckSquare() {
    if (!_engine.in_check) return null;
    return _findKingSquare(_engine, _engine.turn);
  }

  void _loadRandomGame() {
    _autoplayTimer?.cancel();
    setState(() => _isPlaying = false);

    final game = _store.getRandomGame();
    if (game == null) return;

    _currentGame = game;
    _engine = chess.Chess();
    _moveIndex = 0;
    _lastMoveFrom = null;
    _lastMoveTo = null;

    setState(() {});
    _gotoMove(0);
  }

  void _gotoMove(int idx) {
    if (_currentGame == null) return;
    idx = idx.clamp(0, _currentGame!.moves.length);

    _engine = chess.Chess();
    _moveIndex = 0;
    _lastMoveFrom = null;
    _lastMoveTo = null;

    for (int i = 0; i < idx; i++) {
      try {
        final ok = _engine.move(_currentGame!.moves[i].san);
        if (ok) {
          final history = _engine.getHistory({'verbose': true});
          if (history.isNotEmpty) {
            final last = history.last;
            _lastMoveFrom = last['from'] as String?;
            _lastMoveTo = last['to'] as String?;
          }
        }
      } catch (_) {}
    }

    _moveIndex = idx;
    setState(() {});
  }

  String _getCalcLine() {
    if (_currentGame == null || _moveIndex == 0) return '';
    final mv = _currentGame!.moves[_moveIndex - 1];
    if (mv.book == true) return 'Jugada de apertura (libro)';
    if (mv.eval_ == null) return '';
    String text = 'Eval TCEC: ${mv.eval_}';
    if (mv.depth != null) text += ' (prof. ${mv.depth})';
    if (mv.pv != null && mv.pv!.length > 1) {
      text += ' · esperaba: ${mv.pv!.skip(1).join(' ')}';
    }
    return text;
  }

  void _startAutoplay() {
    if (_autoplayTimer != null) return;
    setState(() => _isPlaying = true);
    _autoplayTimer = Timer.periodic(const Duration(milliseconds: 1100), (_) {
      if (_currentGame == null) return;
      if (_moveIndex >= _currentGame!.moves.length) {
        _stopAutoplay();
        return;
      }
      _gotoMove(_moveIndex + 1);
    });
  }

  void _stopAutoplay() {
    _autoplayTimer?.cancel();
    _autoplayTimer = null;
    setState(() => _isPlaying = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final game = _currentGame;
    if (game == null) {
      return const Scaffold(body: Center(child: Text('No hay partidas disponibles', style: TextStyle(color: Colors.white))));
    }

    final bottomIsWhite = game.winner == 'w' || game.winner != 'b';

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${game.opening} (${game.eco})', style: const TextStyle(fontSize: 12, color: Color(0xFFa5a49f)), overflow: TextOverflow.ellipsis),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF7fa650), borderRadius: BorderRadius.circular(4)),
                    child: Text(game.result, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1b1b1b))),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(_isMaximized ? Icons.maximize : Icons.minimize, color: const Color(0xFFa5a49f), size: 20),
                    onPressed: () => setState(() { _isMaximized = !_isMaximized; _squareSize = _isMaximized ? 70 : 40; }),
                  ),
                ],
              ),
            ),
            _PlayerLine(name: bottomIsWhite ? game.black : game.white, elo: bottomIsWhite ? game.blackElo : game.whiteElo, colorCode: bottomIsWhite ? 'b' : 'w', squareSize: _squareSize),
            Center(
              child: ChessBoard(
                pieces: _buildPiecesMap(_engine),
                orientation: bottomIsWhite ? 'white' : 'black',
                lastMoveFrom: _lastMoveFrom,
                lastMoveTo: _lastMoveTo,
                checkSquare: _getCheckSquare(),
                squareSize: _squareSize,
              ),
            ),
            _PlayerLine(name: bottomIsWhite ? game.white : game.black, elo: bottomIsWhite ? game.whiteElo : game.blackElo, colorCode: bottomIsWhite ? 'w' : 'b', squareSize: _squareSize),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Jugada $_moveIndex/${game.moves.length}', style: const TextStyle(fontSize: 12, color: Color(0xFFa5a49f))),
            ),
            if (_getCalcLine().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(_getCalcLine(), style: const TextStyle(fontSize: 11, color: Color(0xFFd8b45c)), textAlign: TextAlign.center),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ControlButton(icon: Icons.skip_previous, onTap: () => _gotoMove(0), enabled: _moveIndex > 0),
                  _ControlButton(icon: Icons.navigate_before, onTap: () => _gotoMove(_moveIndex - 1), enabled: _moveIndex > 0),
                  _ControlButton(icon: _isPlaying ? Icons.pause : Icons.play_arrow, onTap: _isPlaying ? _stopAutoplay : _startAutoplay, active: _isPlaying),
                  _ControlButton(icon: Icons.navigate_next, onTap: () => _gotoMove(_moveIndex + 1), enabled: _moveIndex < game.moves.length),
                  _ControlButton(icon: Icons.skip_next, onTap: () => _gotoMove(game.moves.length), enabled: _moveIndex < game.moves.length),
                  const SizedBox(width: 12),
                  _ControlButton(icon: Icons.shuffle, onTap: _loadRandomGame),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerLine extends StatelessWidget {
  final String name;
  final int? elo;
  final String colorCode;
  final double squareSize;

  const _PlayerLine({required this.name, this.elo, required this.colorCode, required this.squareSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: squareSize * 8,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorCode == 'w' ? const Color(0xFFF0D9B5) : const Color(0xFFB58863),
              border: Border.all(color: const Color(0xFFa5a49f)),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white), overflow: TextOverflow.ellipsis)),
          if (elo != null) Text('($elo)', style: const TextStyle(fontSize: 12, color: Color(0xFFa5a49f))),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  final bool active;

  const _ControlButton({required this.icon, this.onTap, this.enabled = true, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF7fa650) : const Color(0xFF302e2c),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 18, color: enabled ? (active ? const Color(0xFF1b1b1b) : Colors.white) : const Color(0xFF555555)),
        ),
      ),
    );
  }
}
