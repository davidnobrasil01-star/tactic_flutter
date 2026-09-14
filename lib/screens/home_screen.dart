import 'package:flutter/material.dart';
import 'puzzle_screen.dart';
import 'games_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.grid_3x3,
              size: 80,
              color: Color(0xFF7fa650),
            ),
            const SizedBox(height: 20),
            const Text(
              'Mate en 2 Trainer',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 40),
            _MenuButton(
              icon: Icons.psychology,
              label: 'Puzzles',
              subtitle: 'Resuelve mate en 2',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PuzzleScreen(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _MenuButton(
              icon: Icons.smart_toy,
              label: 'Motor vs Motor',
              subtitle: 'Partidas TCEC',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GamesScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF262421),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3d3a36)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF7fa650), size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFa5a49f),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFa5a49f)),
          ],
        ),
      ),
    );
  }
}
