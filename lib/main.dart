import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const TacticApp());
}

class TacticApp extends StatelessWidget {
  const TacticApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mate en 2 Trainer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1a1a1a),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7fa650),
          secondary: Color(0xFFd8b45c),
          surface: Color(0xFF262421),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
