import 'dart:math';
import 'package:flutter/material.dart';

// Cores idênticas ao CSS original
const Color kLightSquare = Color(0xFFF0D9B5);
const Color kDarkSquare = Color(0xFFB58863);
const Color kPanelBg = Color(0xFF262421);
const Color kPanelBg2 = Color(0xFF302E2C);
const Color kText = Color(0xFFE8E6E3);
const Color kMuted = Color(0xFFA5A49F);
const Color kAccent = Color(0xFF7FA650);
const Color kDanger = Color(0xFFC8462A);
const Color kHighlight = Color(0xD4CDD26A); // rgba(205,210,106,0.82)
const Color kSelected = Color(0xBF829769); // rgba(130,151,105,0.75)

class ChessBoard extends StatelessWidget {
  final Map<String, String> pieces; // square -> "wK", "bP", etc
  final String orientation; // 'white' ou 'black'
  final String? selectedSquare;
  final String? lastMoveFrom;
  final String? lastMoveTo;
  final String? checkSquare;
  final Set<String> legalDots;
  final double squareSize;
  final Function(String square)? onSquareTap;
  final Function(String square)? onPieceTapDown;

  const ChessBoard({
    super.key,
    required this.pieces,
    this.orientation = 'white',
    this.selectedSquare,
    this.lastMoveFrom,
    this.lastMoveTo,
    this.checkSquare,
    this.legalDots = const {},
    this.squareSize = 26,
    this.onSquareTap,
    this.onPieceTapDown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: squareSize * 8,
      height: squareSize * 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: _buildAll(),
      ),
    );
  }

  List<Widget> _buildAll() {
    final widgets = <Widget>[];

    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final square = _xyToSquare(col, row);
        final isDark = _isDarkSquare(square);

        // Cor base do quadrado
        Color bg = isDark ? kDarkSquare : kLightSquare;

        // Highlight de última jogada (por cima da cor base)
        if (square == lastMoveFrom || square == lastMoveTo) {
          bg = kHighlight;
        }

        // Seleção (por cima de tudo)
        if (square == selectedSquare) {
          bg = kSelected;
        }

        widgets.add(Positioned(
          left: col * squareSize,
          top: row * squareSize,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSquareTap?.call(square),
            child: Container(
              width: squareSize,
              height: squareSize,
              color: bg,
              child: _coordLabel(square, isDark, col, row),
            ),
          ),
        ));

        // Check highlight (radial gradient vermelho)
        if (square == checkSquare) {
          widgets.add(Positioned(
            left: col * squareSize,
            top: row * squareSize,
            child: IgnorePointer(
              child: Container(
                width: squareSize,
                height: squareSize,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.0,
                    colors: const [
                      Color(0xE6EB0000), // 0.9
                      Color(0x80EB0000), // 0.5
                      Color(0x00EB0000), // 0.0
                    ],
                    stops: const [0.0, 0.25, 0.89],
                  ),
                ),
              ),
            ),
          ));
        }

        // Legal dots
        if (legalDots.contains(square)) {
          final isCapture = pieces.containsKey(square);
          widgets.add(Positioned(
            left: col * squareSize,
            top: row * squareSize,
            child: IgnorePointer(
              child: Container(
                width: squareSize,
                height: squareSize,
                alignment: Alignment.center,
                child: isCapture
                    ? Container(
                        width: squareSize * 0.82,
                        height: squareSize * 0.82,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0x4D141414),
                            width: 3,
                          ),
                        ),
                      )
                    : Container(
                        width: squareSize * 0.28,
                        height: squareSize * 0.28,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0x4D141414),
                        ),
                      ),
              ),
            ),
          ));
        }
      }
    }

    // Peças por cima
    for (final entry in pieces.entries) {
      final square = entry.key;
      final pieceCode = entry.value;
      final file = square.codeUnitAt(0) - 97;
      final rank = int.parse(square[1]) - 1;
      int col, row;
      if (orientation == 'white') {
        col = file;
        row = 7 - rank;
      } else {
        col = 7 - file;
        row = rank;
      }

      widgets.add(Positioned(
        left: col * squareSize,
        top: row * squareSize,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => onPieceTapDown?.call(square),
          child: Image.asset(
            'assets/pieces/$pieceCode.svg',
            width: squareSize,
            height: squareSize,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _fallbackPiece(pieceCode),
          ),
        ),
      ));
    }

    return widgets;
  }

  Widget _fallbackPiece(String code) {
    if (code.length < 2) return const SizedBox();
    final type = code[1].toUpperCase();
    final isWhite = code[0] == 'w';
    const symbols = {
      'K': '\u265A',
      'Q': '\u265B',
      'R': '\u265C',
      'B': '\u265D',
      'N': '\u265E',
      'P': '\u265F',
    };
    return Container(
      width: squareSize,
      height: squareSize,
      alignment: Alignment.center,
      child: Text(
        symbols[type] ?? '?',
        style: TextStyle(
          fontSize: squareSize * 0.7,
          color: isWhite ? Colors.white : Colors.black87,
          shadows: const [
            Shadow(offset: Offset(0, 1), blurRadius: 1, color: Colors.black45),
          ],
        ),
      ),
    );
  }

  Widget? _coordLabel(String square, bool isDark, int col, int row) {
    // File label (letras) - última linha
    if (row == 7) {
      return Positioned(
        bottom: 1,
        right: 2,
        child: Text(
          square[0],
          style: TextStyle(
            fontSize: 6,
            fontWeight: FontWeight.w700,
            height: 1,
            color: isDark ? kLightSquare : kDarkSquare,
          ),
        ),
      );
    }
    // Rank label (números) - primeira coluna
    if (col == 0) {
      return Positioned(
        top: 1,
        left: 2,
        child: Text(
          square[1],
          style: TextStyle(
            fontSize: 6,
            fontWeight: FontWeight.w700,
            height: 1,
            color: isDark ? kLightSquare : kDarkSquare,
          ),
        ),
      );
    }
    return null;
  }

  String _xyToSquare(int col, int row) {
    int file, rank;
    if (orientation == 'white') {
      file = col;
      rank = 7 - row;
    } else {
      file = 7 - col;
      rank = row;
    }
    return String.fromCharCode(97 + file) + (rank + 1).toString();
  }

  bool _isDarkSquare(String square) {
    final file = square.codeUnitAt(0) - 97;
    final rank = int.parse(square[1]) - 1;
    return (file + rank) % 2 == 0;
  }
}
