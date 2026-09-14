window.addEventListener('error', (e) => console.error('window.onerror:', e.message, e.filename, e.lineno));
window.addEventListener('unhandledrejection', (e) => console.error('unhandledrejection:', e.reason));

const SQUARE_SIZE_COMPACT = 26;
const SQUARE_SIZE_LARGE = 56;
let SQUARE_SIZE = SQUARE_SIZE_COMPACT;
let isMaximized = false;
const TOTAL_TIME = 60; // segundos

const boardEl = document.getElementById('board');
const piecesLayer = document.getElementById('pieces-layer');
const clockTimeEl = document.getElementById('clock-time');
const ringProgress = document.getElementById('ring-progress');
const feedbackEl = document.getElementById('feedback');
const feedbackTitle = document.getElementById('feedback-title');
const feedbackPattern = document.getElementById('feedback-pattern');
const feedbackTime = document.getElementById('feedback-time');
const feedbackLine = document.getElementById('feedback-line');
const nextBtn = document.getElementById('next-btn');
const reviewTag = document.getElementById('review-tag');
const puzzleRatingEl = document.getElementById('puzzle-rating');
const turnHint = document.getElementById('turn-hint');
const panelEl = document.getElementById('panel');
const puzzleInfoEl = document.getElementById('puzzle-info');
const solvedCountEl = document.getElementById('solved-count');
const maximizeBtn = document.getElementById('maximize-btn');

const RING_CIRCUMFERENCE = 2 * Math.PI * 19;
ringProgress.style.strokeDasharray = `${RING_CIRCUMFERENCE}`;

let orientation = 'white';
let currentPuzzle = null;
let solutionMoves = [];
let solutionSan = [];
let moveIndex = 0;
let solved = false;
let ended = false;

let timeLeft = TOTAL_TIME;
let timerHandle = null;
let startedAt = null;
let pausedAt = null;

let selectedSquare = null;
let lastMoveSquares = [];
let dragInfo = null;
let isBusy = false; // true mientras se reproduce automaticamente la respuesta forzada del rival

function squareToXY(square) {
  const file = square.charCodeAt(0) - 97;
  const rank = parseInt(square[1], 10) - 1;
  if (orientation === 'white') return [file, 7 - rank];
  return [7 - file, rank];
}

function xyToSquare(col, row) {
  let file, rank;
  if (orientation === 'white') { file = col; rank = 7 - row; }
  else { file = 7 - col; rank = row; }
  return String.fromCharCode(97 + file) + (rank + 1);
}

function isDarkSquare(square) {
  const file = square.charCodeAt(0) - 97;
  const rank = parseInt(square[1], 10) - 1;
  return (file + rank) % 2 === 0;
}

function buildEmptyBoard() {
  boardEl.innerHTML = '';
  for (let row = 0; row < 8; row++) {
    for (let col = 0; col < 8; col++) {
      const square = xyToSquare(col, row);
      const dark = isDarkSquare(square);
      const sq = document.createElement('div');
      sq.className = `square ${dark ? 'dark' : 'light'}`;
      sq.style.left = `${col * SQUARE_SIZE}px`;
      sq.style.top = `${row * SQUARE_SIZE}px`;
      sq.dataset.square = square;
      sq.addEventListener('mousedown', onSquareMouseDown);
      boardEl.appendChild(sq);

      if (row === 7) {
        const label = document.createElement('span');
        label.className = `coord file ${dark ? 'on-dark' : 'on-light'}`;
        label.textContent = square[0];
        sq.appendChild(label);
      }
      if (col === 0) {
        const label = document.createElement('span');
        label.className = `coord rank ${dark ? 'on-dark' : 'on-light'}`;
        label.textContent = square[1];
        sq.appendChild(label);
      }
    }
  }
}

function pieceImgSrc(piece) {
  const color = piece.color === 'w' ? 'w' : 'b';
  const type = piece.type.toUpperCase();
  return `assets/pieces/${color}${type}.svg`;
}

function renderPieces() {
  piecesLayer.innerHTML = '';
  const board = window.chessAPI.board();
  for (let r = 0; r < 8; r++) {
    for (let c = 0; c < 8; c++) {
      const piece = board[r][c];
      if (!piece) continue;
      const square = piece.square;
      const [col, row] = squareToXY(square);
      const img = document.createElement('img');
      img.className = 'piece';
      img.src = pieceImgSrc(piece);
      img.draggable = false;
      img.style.left = `${col * SQUARE_SIZE}px`;
      img.style.top = `${row * SQUARE_SIZE}px`;
      img.dataset.square = square;
      img.addEventListener('mousedown', onPieceMouseDown);
      piecesLayer.appendChild(img);
    }
  }
}

function clearSquareStyles() {
  boardEl.querySelectorAll('.square').forEach((sq) => {
    sq.classList.remove('last-move', 'selected', 'check');
  });
  boardEl.querySelectorAll('.legal-dot').forEach((el) => el.remove());
}

function highlightLastMove() {
  lastMoveSquares.forEach((sq) => {
    const el = boardEl.querySelector(`.square[data-square="${sq}"]`);
    if (el) el.classList.add('last-move');
  });
}

function highlightCheck() {
  if (!window.chessAPI.isCheck()) return;
  const board = window.chessAPI.board();
  for (const row of board) {
    for (const piece of row) {
      if (piece && piece.type === 'k' && piece.color === window.chessAPI.turn()) {
        const el = boardEl.querySelector(`.square[data-square="${piece.square}"]`);
        if (el) el.classList.add('check');
      }
    }
  }
}

function showLegalTargets(square) {
  const moves = window.chessAPI.moves({ square });
  moves.forEach((m) => {
    const [col, row] = squareToXY(m.to);
    const dot = document.createElement('div');
    dot.className = `legal-dot ${m.captured ? 'capture' : ''}`;
    dot.style.left = `${col * SQUARE_SIZE}px`;
    dot.style.top = `${row * SQUARE_SIZE}px`;
    boardEl.appendChild(dot);
  });
}

function renderAll() {
  clearSquareStyles();
  renderPieces();
  highlightLastMove();
  highlightCheck();
  if (selectedSquare) {
    const el = boardEl.querySelector(`.square[data-square="${selectedSquare}"]`);
    if (el) el.classList.add('selected');
    showLegalTargets(selectedSquare);
  }
}

function applyUciMove(uci) {
  const from = uci.slice(0, 2);
  const to = uci.slice(2, 4);
  const promotion = uci.length > 4 ? uci[4] : undefined;
  const mv = window.chessAPI.move({ from, to, promotion });
  if (mv) lastMoveSquares = [mv.from, mv.to];
  return mv;
}

async function loadNextPuzzle() {
  ended = false;
  solved = false;
  selectedSquare = null;
  hideFeedback();
  const puzzle = await window.api.getNextPuzzle();
  currentPuzzle = puzzle;

  // Pre-calcular la linea de solucion en SAN para el feedback pedagogico
  window.chessAPI.load(puzzle.fen);
  const sanLine = [];
  for (const uci of puzzle.moves) {
    const mv = applyUciMove(uci);
    if (mv) sanLine.push(mv.san);
  }
  solutionSan = sanLine;

  // Reiniciar y jugar solo el movimiento de planteamiento
  window.chessAPI.load(puzzle.fen);
  solutionMoves = puzzle.moves;
  moveIndex = 0;
  applyUciMove(solutionMoves[0]);
  moveIndex = 1;

  const solverColor = window.chessAPI.turn();
  orientation = solverColor === 'w' ? 'white' : 'black';

  reviewTag.classList.toggle('hidden', !puzzle.isReview);
  puzzleRatingEl.textContent = `${puzzle.rating} ELO`;
  turnHint.textContent = solverColor === 'w' ? 'Juegan blancas. Encontrá el mate en 2.' : 'Juegan negras. Encontrá el mate en 2.';

  buildEmptyBoard();
  renderAll();
  syncSize();
  refreshStatsTooltip();
  startTimer();
}

function attemptUserMove(from, to) {
  if (ended || isBusy) return;
  if (Date.now() - startedAt >= TOTAL_TIME * 1000) return; // se acabo el tiempo, el timeout se dispara solo
  const piece = window.chessAPI.get(from);
  if (!piece || piece.color !== window.chessAPI.turn()) return;

  const expected = solutionMoves[moveIndex];
  const expFrom = expected.slice(0, 2);
  const expTo = expected.slice(2, 4);

  const attempted = window.chessAPI.move({ from, to, promotion: 'q' });
  if (!attempted) {
    selectedSquare = null;
    renderAll();
    return; // movimiento ilegal, se ignora
  }

  if (from === expFrom && to === expTo) {
    lastMoveSquares = [from, to];
    moveIndex++;
    selectedSquare = null;
    renderAll();

    if (window.chessAPI.isCheckmate() || moveIndex >= solutionMoves.length) {
      onPuzzleSolved();
      return;
    }

    turnHint.textContent = 'Bien. Respuesta forzada del rival...';
    isBusy = true;
    setTimeout(() => {
      applyUciMove(solutionMoves[moveIndex]);
      moveIndex++;
      isBusy = false;
      renderAll();
      if (window.chessAPI.isCheckmate() || moveIndex >= solutionMoves.length) {
        onPuzzleSolved();
      } else {
        turnHint.textContent = 'Tu turno: continuá la combinación.';
      }
    }, 450);
  } else {
    window.chessAPI.undo();
    selectedSquare = null;
    renderAll();
    onPuzzleFailed('wrong-move');
  }
}

function onSquareMouseDown(e) {
  const square = e.currentTarget.dataset.square;
  handleSquareClick(square);
}

function handleSquareClick(square) {
  if (ended || isBusy) return;
  const piece = window.chessAPI.get(square);
  const turnColor = window.chessAPI.turn();
  if (selectedSquare) {
    if (square === selectedSquare) {
      selectedSquare = null;
      renderAll();
      return;
    }
    if (piece && piece.color === turnColor) {
      selectedSquare = square;
      renderAll();
      return;
    }
    const from = selectedSquare;
    selectedSquare = null;
    attemptUserMove(from, square);
    return;
  }
  if (piece && piece.color === turnColor) {
    selectedSquare = square;
    renderAll();
  }
}

function onPieceMouseDown(e) {
  e.preventDefault();
  if (ended || isBusy) return;
  const square = e.currentTarget.dataset.square;
  const piece = window.chessAPI.get(square);
  if (!piece || piece.color !== window.chessAPI.turn()) {
    handleSquareClick(square);
    return;
  }

  selectedSquare = square;
  renderAll();

  // renderAll() reconstruye todas las piezas (para pintar la seleccion y los
  // puntos de jugadas legales), asi que el nodo original queda desmontado.
  // Hay que volver a tomar la referencia del nuevo <img> antes de arrastrarlo.
  const img = piecesLayer.querySelector(`img[data-square="${square}"]`);
  if (!img) return;
  const boardRect = boardEl.getBoundingClientRect();
  img.classList.add('dragging');

  dragInfo = { square, img, boardRect };

  function onMove(ev) {
    const x = ev.clientX - boardRect.left - SQUARE_SIZE / 2;
    const y = ev.clientY - boardRect.top - SQUARE_SIZE / 2;
    img.style.left = `${x}px`;
    img.style.top = `${y}px`;
  }

  function onUp(ev) {
    document.removeEventListener('mousemove', onMove);
    document.removeEventListener('mouseup', onUp);
    img.classList.remove('dragging');

    const x = ev.clientX - boardRect.left;
    const y = ev.clientY - boardRect.top;
    const col = Math.floor(x / SQUARE_SIZE);
    const row = Math.floor(y / SQUARE_SIZE);
    dragInfo = null;

    if (col < 0 || col > 7 || row < 0 || row > 7) {
      selectedSquare = null;
      renderAll();
      return;
    }
    const targetSquare = xyToSquare(col, row);
    const targetPiece = window.chessAPI.get(targetSquare);
    selectedSquare = null;
    if (targetSquare === square || (targetPiece && targetPiece.color === window.chessAPI.turn())) {
      selectedSquare = targetSquare;
      renderAll();
    } else {
      attemptUserMove(square, targetSquare);
    }
  }

  document.addEventListener('mousemove', onMove);
  document.addEventListener('mouseup', onUp);
}

function startTimer() {
  stopTimer();
  timeLeft = TOTAL_TIME;
  startedAt = Date.now();
  pausedAt = null;
  updateClockUI();
  runInterval();
}

function resumeTimer() {
  if (timerHandle || ended) return;
  if (pausedAt) {
    startedAt += Date.now() - pausedAt;
    pausedAt = null;
  }
  runInterval();
}

function runInterval() {
  timerHandle = setInterval(() => {
    const elapsedMs = Date.now() - startedAt;
    timeLeft = Math.max(0, Math.ceil((TOTAL_TIME * 1000 - elapsedMs) / 1000));
    updateClockUI();
    if (elapsedMs >= TOTAL_TIME * 1000) {
      stopTimer();
      onPuzzleFailed('timeout');
    }
  }, 200);
}

function stopTimer() {
  if (timerHandle) clearInterval(timerHandle);
  timerHandle = null;
}

function updateClockUI() {
  clockTimeEl.textContent = Math.max(0, timeLeft);
  const frac = Math.max(0, timeLeft) / TOTAL_TIME;
  ringProgress.style.strokeDashoffset = `${RING_CIRCUMFERENCE * (1 - frac)}`;
  ringProgress.classList.toggle('low', timeLeft <= 10);
}

async function onPuzzleSolved() {
  ended = true;
  solved = true;
  stopTimer();
  turnHint.textContent = '¡Mate!';
  const timeMs = Date.now() - startedAt;
  const result = await window.api.reportResult({ id: currentPuzzle.id, success: true, timeMs });
  showFeedback(true, result, null, timeMs);
}

async function onPuzzleFailed(reason) {
  ended = true;
  solved = false;
  stopTimer();
  const timeMs = Date.now() - startedAt;
  const result = await window.api.reportResult({ id: currentPuzzle.id, success: false, timeMs });
  showFeedback(false, result, reason, timeMs);
}

function showFeedback(success, result, reason, timeMs) {
  feedbackEl.classList.remove('hidden');
  feedbackTitle.className = success ? 'ok' : 'fail';
  if (success) {
    feedbackTitle.textContent = '¡Correcto! Mate en 2 resuelto.';
  } else if (reason === 'timeout') {
    feedbackTitle.textContent = 'Se acabó el tiempo.';
  } else {
    feedbackTitle.textContent = 'Ese no era el mate.';
  }

  const matePattern = window.themesAPI.pattern(currentPuzzle.themes);
  const tracked = result && result.pattern;
  const label = matePattern || (tracked && tracked.label);
  feedbackPattern.textContent = label ? `Patrón: ${label}` : '';

  if (success) {
    let timeText = `Tu tiempo: ${(timeMs / 1000).toFixed(1)}s`;
    if (tracked && tracked.avgMs && tracked.solved > 1) {
      timeText += ` · promedio en este patrón: ${(tracked.avgMs / 1000).toFixed(1)}s (${tracked.solved}/${tracked.attempts})`;
    }
    feedbackTime.textContent = timeText;
  } else {
    feedbackTime.textContent = '';
  }

  const line = solutionSan.slice(1).join('  ');
  feedbackLine.textContent = `Solución: ${line}`;

  refreshStatsTooltip();
  syncSize();
}

function hideFeedback() {
  feedbackEl.classList.add('hidden');
}

function syncSize() {
  requestAnimationFrame(() => {
    const width = panelEl.scrollWidth;
    const height = panelEl.scrollHeight;
    window.api.resizeOverlay(width, height);
  });
}

function toggleMaximize() {
  isMaximized = !isMaximized;
  SQUARE_SIZE = isMaximized ? SQUARE_SIZE_LARGE : SQUARE_SIZE_COMPACT;
  document.documentElement.style.setProperty('--square-size', `${SQUARE_SIZE}px`);
  maximizeBtn.textContent = isMaximized ? '⤡' : '⤢';
  maximizeBtn.title = isMaximized ? 'Achicar tablero' : 'Agrandar tablero';
  buildEmptyBoard();
  renderAll();
  syncSize();
}

async function refreshStatsTooltip() {
  const stats = await window.api.getStats();
  solvedCountEl.textContent = `· ${stats.solved}✓`;
  puzzleInfoEl.title =
    `Resueltos: ${stats.solved}\n` +
    `Fallados: ${stats.failed}\n` +
    `Repasos pendientes: ${stats.dueCount}\n` +
    `Puzzles vistos: ${stats.seenCount} de ${stats.totalPuzzles}`;
}

maximizeBtn.addEventListener('click', toggleMaximize);

nextBtn.addEventListener('click', () => loadNextPuzzle());

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    window.api.closeOverlay();
  } else if ((e.key === 'Enter' || e.key === ' ') && ended) {
    e.preventDefault();
    loadNextPuzzle();
  }
});

window.api.onOverlayShown(() => {
  if (!currentPuzzle) {
    loadNextPuzzle();
  } else if (!ended) {
    resumeTimer();
  }
});

window.api.onOverlayHidden(() => {
  if (timerHandle) pausedAt = Date.now();
  stopTimer();
});
