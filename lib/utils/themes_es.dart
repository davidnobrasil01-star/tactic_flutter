const Map<String, String> THEMES_ES = {
  'mateIn2': 'Mate en 2',
  'smotheredMate': 'Mate ahogado (smothered mate)',
  'backRankMate': 'Mate de pasillo (back rank)',
  'arabianMate': 'Mate árabe',
  'anastasiaMate': 'Mate de Anastasia',
  'hookMate': 'Mate del gancho',
  'bodenMate': 'Mate de Boden',
  'doubleBishopMate': 'Mate de los dos alfiles',
  'dovetailMate': 'Mate de la cola de milano',
  'killBoxMate': 'Mate de la caja',
  'vukovicMate': 'Mate de Vukovic',
  'doubleCheck': 'Jaque doble',
  'discoveredAttack': 'Ataque descubierto',
  'attraction': 'Atracción (desviar una pieza a una casilla)',
  'deflection': 'Sobrecarga / desviación',
  'clearance': 'Despeje de línea o casilla',
  'interference': 'Interferencia',
  'pin': 'Clavada',
  'fork': 'Horquilla / tenedor',
  'skewer': 'Ensarte (rayos X)',
  'xRayAttack': 'Ataque de rayos X',
  'quietMove': 'Movimiento tranquilo',
  'sacrifice': 'Sacrificio',
  'zugzwang': 'Zugzwang',
  'exposedKing': 'Rey expuesto',
  'kingsideAttack': 'Ataque en el flanco de rey',
  'queensideAttack': 'Ataque en el flanco de dama',
  'middlegame': 'Medio juego',
  'endgame': 'Final',
  'short': 'Combinación corta',
  'crushing': 'Ventaja decisiva',
  'master': 'Partida de maestros',
  'masterVsMaster': 'Maestro contra maestro',
};

const Set<String> GENERIC_TAGS = {
  'mateIn2',
  'short',
  'middlegame',
  'endgame',
  'crushing',
  'master',
  'masterVsMaster',
};

const List<String> MATE_PATTERN_KEYS = [
  'smotheredMate',
  'backRankMate',
  'arabianMate',
  'anastasiaMate',
  'hookMate',
  'bodenMate',
  'doubleBishopMate',
  'dovetailMate',
  'killBoxMate',
  'vukovicMate',
];

List<String> translateThemes(List<String>? themes) {
  return (themes ?? [])
      .where((t) => THEMES_ES.containsKey(t))
      .map((t) => THEMES_ES[t]!)
      .toList();
}

String? primaryPattern(List<String>? themes) {
  final matches = (themes ?? []).where((t) => MATE_PATTERN_KEYS.contains(t));
  final found = matches.isEmpty ? null : matches.first;
  return found != null ? THEMES_ES[found] : null;
}

List<String> trackableThemes(List<String>? themes) {
  return (themes ?? [])
      .where((t) => THEMES_ES.containsKey(t) && !GENERIC_TAGS.contains(t))
      .toList();
}
