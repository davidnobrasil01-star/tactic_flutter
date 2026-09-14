// bridge.js — Replaces Electron's preload.js for Capacitor/browser
// Provides window.chessAPI, window.api, window.gamesAPI, window.themesAPI

// ═══════════════════════════════════════════════
// themesEs — inline
// ═══════════════════════════════════════════════
const THEMES_ES = {
  mateIn2: 'Mate en 2',
  smotheredMate: 'Mate ahogado (smothered mate)',
  backRankMate: 'Mate de pasillo (back rank)',
  arabianMate: 'Mate árabe',
  anastasiaMate: 'Mate de Anastasia',
  hookMate: 'Mate del gancho',
  bodenMate: 'Mate de Boden',
  doubleBishopMate: 'Mate de los dos alfiles',
  dovetailMate: 'Mate de la cola de milano',
  killBoxMate: 'Mate de la caja',
  vukovicMate: 'Mate de Vukovic',
  doubleCheck: 'Jaque doble',
  discoveredAttack: 'Ataque descubierto',
  attraction: 'Atracción (desviar una pieza a una casilla)',
  deflection: 'Sobrecarga / desviación',
  clearance: 'Despeje de línea o casilla',
  interference: 'Interferencia',
  pin: 'Clavada',
  fork: 'Horquilla / tenedor',
  skewer: 'Ensarte (rayos X)',
  xRayAttack: 'Ataque de rayos X',
  quietMove: 'Movimiento tranquilo',
  sacrifice: 'Sacrificio',
  zugzwang: 'Zugzwang',
  exposedKing: 'Rey expuesto',
  kingsideAttack: 'Ataque en el flanco de rey',
  queensideAttack: 'Ataque en el flanco de dama',
  middlegame: 'Medio juego',
  endgame: 'Final',
  short: 'Combinación corta',
  crushing: 'Ventaja decisiva',
  master: 'Partida de maestros',
  masterVsMaster: 'Maestro contra maestro',
};
const MATE_PATTERN_KEYS = [
  'smotheredMate','backRankMate','arabianMate','anastasiaMate','hookMate',
  'bodenMate','doubleBishopMate','dovetailMate','killBoxMate','vukovicMate',
];
function translateThemes(themes) {
  return (themes || []).filter((t) => THEMES_ES[t]).map((t) => THEMES_ES[t]);
}
function primaryPattern(themes) {
  const found = (themes || []).find((t) => MATE_PATTERN_KEYS.includes(t));
  return found ? THEMES_ES[found] : null;
}

window.themesAPI = { translate: translateThemes, pattern: primaryPattern };

// ═══════════════════════════════════════════════
// chessAPI — uses chess.js loaded via <script>
// ═══════════════════════════════════════════════
let engine = new Chess();

window.chessAPI = {
  load: (fen) => { engine = new Chess(fen); return engine.fen(); },
  turn: () => engine.turn(),
  moves: (opts) => engine.moves({ ...opts, verbose: true }),
  move: (m) => { try { return engine.move(m); } catch (e) { return null; } },
  fen: () => engine.fen(),
  get: (square) => engine.get(square),
  board: () => engine.board(),
  isCheckmate: () => engine.isCheckmate(),
  isCheck: () => engine.isCheck(),
  history: (opts) => engine.history(opts),
  undo: () => engine.undo(),
};

// ═══════════════════════════════════════════════
// Puzzle Store — localStorage version of puzzleStore.js
// ═══════════════════════════════════════════════
const PUZZLE_CONSTS = {
  MIN_EASE: 1.3,
  START_EASE: 2.5,
  LEARN_STEP_1_MS: 10 * 60 * 1000,
  LEARN_STEP_2_MS: 24 * 60 * 60 * 1000,
  START_USER_RATING: 2100,
  K_FACTOR: 24,
  INITIAL_WINDOW: 100,
  WINDOW_STEP: 100,
  MAX_WINDOW: 1500,
  TOTAL_TIME_MS: 60 * 1000,
  FAST_MS: 15 * 1000,
  NORMAL_MS: 40 * 1000,
};
const GENERIC_TAGS = new Set([
  'mateIn2','short','middlegame','endgame','crushing','master','masterVsMaster',
]);
function trackableThemes(themes) {
  return (themes || []).filter((t) => THEMES_ES[t] && !GENERIC_TAGS.has(t));
}

let pool = [];
let byId = new Map();
let srsState = {};
let meta = { userRating: PUZZLE_CONSTS.START_USER_RATING, solved: 0, failed: 0, themeStats: {} };

function loadSrsState() {
  try {
    const raw = localStorage.getItem('gmchess-srs');
    if (raw) {
      const parsed = JSON.parse(raw);
      srsState = parsed.srsState || {};
      meta = Object.assign(meta, parsed.meta || {});
      meta.themeStats = meta.themeStats || {};
    }
  } catch (e) { srsState = {}; }
}
function saveSrsState() {
  localStorage.setItem('gmchess-srs', JSON.stringify({ srsState, meta }));
}

function lowerBound(target) {
  let lo = 0, hi = pool.length;
  while (lo < hi) {
    const mid = (lo + hi) >> 1;
    if (pool[mid].rating < target) lo = mid + 1; else hi = mid;
  }
  return lo;
}
function weaknessWeight(puzzle) {
  let worst = 0;
  for (const tag of trackableThemes(puzzle.themes)) {
    const s = meta.themeStats[tag];
    if (!s || s.attempts < 2) continue;
    const successRate = s.solved / s.attempts;
    const avgMs = s.solved ? s.totalMs / s.solved : PUZZLE_CONSTS.TOTAL_TIME_MS;
    const weak = (1 - successRate) * 2.5 + avgMs / PUZZLE_CONSTS.TOTAL_TIME_MS;
    if (weak > worst) worst = weak;
  }
  return 1 + worst;
}
function weightedPick(candidates) {
  const weights = candidates.map(weaknessWeight);
  const total = weights.reduce((a, b) => a + b, 0);
  let r = Math.random() * total;
  for (let i = 0; i < candidates.length; i++) {
    r -= weights[i];
    if (r <= 0) return candidates[i];
  }
  return candidates[candidates.length - 1];
}
function pickNewPuzzle() {
  let window = PUZZLE_CONSTS.INITIAL_WINDOW;
  while (window <= PUZZLE_CONSTS.MAX_WINDOW) {
    const lo = lowerBound(meta.userRating - window);
    const hi = lowerBound(meta.userRating + window);
    const candidates = [];
    for (let i = lo; i < hi && candidates.length < 500; i++) {
      if (!srsState[pool[i].id]) candidates.push(pool[i]);
    }
    if (candidates.length > 0) return weightedPick(candidates);
    window += PUZZLE_CONSTS.WINDOW_STEP;
  }
  const unseen = pool.filter((p) => !srsState[p.id]);
  if (unseen.length > 0) return weightedPick(unseen);
  return pool[Math.floor(Math.random() * pool.length)];
}
function getDueReview() {
  const now = Date.now();
  let best = null;
  for (const id in srsState) {
    const s = srsState[id];
    if (s.dueAt <= now && (!best || s.dueAt < srsState[best].dueAt)) best = id;
  }
  return best ? byId.get(best) : null;
}
function speedTierOf(timeMs) {
  if (timeMs < PUZZLE_CONSTS.FAST_MS) return 'fast';
  if (timeMs < PUZZLE_CONSTS.NORMAL_MS) return 'normal';
  return 'slow';
}
function updateThemeStats(puzzle, success, timeMs) {
  for (const tag of trackableThemes(puzzle.themes)) {
    const s = meta.themeStats[tag] || { attempts: 0, solved: 0, totalMs: 0 };
    s.attempts += 1;
    if (success) { s.solved += 1; s.totalMs += timeMs; }
    meta.themeStats[tag] = s;
  }
}
function primaryTrackedTheme(themes) {
  const tags = trackableThemes(themes);
  return tags.length ? tags[0] : null;
}

function puzzleReportResult({ id, success, timeMs }) {
  const puzzle = byId.get(id);
  if (!puzzle) return { ok: false };
  const speedTier = success ? speedTierOf(timeMs) : null;
  const ratingScore = !success ? 0 : speedTier === 'slow' ? 0.8 : 1;
  const expected = 1 / (1 + Math.pow(10, (puzzle.rating - meta.userRating) / 400));
  meta.userRating += PUZZLE_CONSTS.K_FACTOR * (ratingScore - expected);
  meta.userRating = Math.max(1600, Math.min(3200, meta.userRating));
  if (success) meta.solved = (meta.solved || 0) + 1;
  else meta.failed = (meta.failed || 0) + 1;
  updateThemeStats(puzzle, success, timeMs);
  const prev = srsState[id] || { ease: PUZZLE_CONSTS.START_EASE, reps: 0, lapses: 0 };
  const now = Date.now();
  let nextState;
  if (success) {
    const reps = prev.reps + 1;
    const easeDelta = speedTier === 'fast' ? 0.1 : speedTier === 'normal' ? 0.05 : 0;
    const ease = Math.min(3.2, prev.ease + easeDelta);
    let intervalMs;
    if (reps === 1) intervalMs = PUZZLE_CONSTS.LEARN_STEP_1_MS;
    else if (reps === 2) intervalMs = PUZZLE_CONSTS.LEARN_STEP_2_MS;
    else {
      const growth = speedTier === 'slow' ? 1.2 : ease;
      intervalMs = Math.round((prev.intervalMs || PUZZLE_CONSTS.LEARN_STEP_2_MS) * growth);
    }
    nextState = { ease, reps, lapses: prev.lapses, intervalMs, dueAt: now + intervalMs, seenAt: now };
  } else {
    nextState = {
      ease: Math.max(PUZZLE_CONSTS.MIN_EASE, prev.ease - 0.2),
      reps: 0, lapses: prev.lapses + 1,
      intervalMs: PUZZLE_CONSTS.LEARN_STEP_1_MS,
      dueAt: now + PUZZLE_CONSTS.LEARN_STEP_1_MS, seenAt: now,
    };
  }
  srsState[id] = nextState;
  saveSrsState();
  const patternTag = primaryTrackedTheme(puzzle.themes);
  const patternStats = patternTag ? meta.themeStats[patternTag] : null;
  return {
    ok: true,
    userRating: Math.round(meta.userRating),
    nextDueInMs: nextState.intervalMs,
    reps: nextState.reps,
    speedTier,
    pattern: patternTag && patternStats ? {
      tag: patternTag,
      label: THEMES_ES[patternTag],
      attempts: patternStats.attempts,
      solved: patternStats.solved,
      avgMs: patternStats.solved ? Math.round(patternStats.totalMs / patternStats.solved) : null,
    } : null,
  };
}

// ═══════════════════════════════════════════════
// Games Store — loads from bundled JSON
// ═══════════════════════════════════════════════
let games = [];
let lastGameId = null;

// ═══════════════════════════════════════════════
// api bridge
// ═══════════════════════════════════════════════
window.api = {
  onOverlayShown: () => {},
  onOverlayHidden: () => {},
  closeOverlay: () => {},
  resizeOverlay: () => {},
  getNextPuzzle: () => {
    if (pool.length === 0) return null;
    const due = getDueReview();
    const puzzle = due || pickNewPuzzle();
    return {
      id: puzzle.id,
      fen: puzzle.fen,
      moves: puzzle.moves,
      rating: puzzle.rating,
      themes: puzzle.themes,
      isReview: !!srsState[puzzle.id],
      userRating: Math.round(meta.userRating),
    };
  },
  reportResult: (payload) => puzzleReportResult(payload),
  getStats: () => {
    const dueCount = Object.values(srsState).filter((s) => s.dueAt <= Date.now()).length;
    return {
      totalPuzzles: pool.length,
      seenCount: Object.keys(srsState).length,
      dueCount,
      userRating: Math.round(meta.userRating),
      solved: meta.solved || 0,
      failed: meta.failed || 0,
    };
  },
  openExternal: (url) => { window.open(url, '_blank'); },
};

window.gamesAPI = {
  getRandomGame: () => {
    if (games.length === 0) return null;
    let game;
    do {
      game = games[Math.floor(Math.random() * games.length)];
    } while (games.length > 1 && game.id === lastGameId);
    lastGameId = game.id;
    return game;
  },
};

// ═══════════════════════════════════════════════
// Init — load data from bundled assets
// ═══════════════════════════════════════════════
async function initBridge() {
  // Load puzzles
  try {
    const resp = await fetch('data/puzzles.jsonl');
    const text = await resp.text();
    const list = [];
    for (const line of text.split('\n')) {
      if (!line) continue;
      try { list.push(JSON.parse(line)); } catch (e) {}
    }
    list.sort((a, b) => a.rating - b.rating);
    pool = list;
    byId = new Map(pool.map((p) => [p.id, p]));
  } catch (e) {
    console.error('Failed to load puzzles:', e);
  }

  // Load SRS state from localStorage
  loadSrsState();

  // Load games
  try {
    const resp = await fetch('data/games.jsonl');
    if (resp.ok) {
      const text = await resp.text();
      for (const line of text.split('\n')) {
        if (!line) continue;
        try { games.push(JSON.parse(line)); } catch (e) {}
      }
    }
  } catch (e) {
    console.error('Failed to load games:', e);
  }

  console.log(`GMchess loaded: ${pool.length} puzzles, ${games.length} games`);
}

initBridge();
