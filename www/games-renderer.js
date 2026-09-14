window.addEventListener('error', (e) => console.error('window.onerror:', e.message, e.filename, e.lineno));
window.addEventListener('unhandledrejection', (e) => console.error('unhandledrejection:', e.reason));

const SQUARE_SIZE_COMPACT = 26;
const SQUARE_SIZE_LARGE = 56;
let SQUARE_SIZE = SQUARE_SIZE_COMPACT;
let isMaximized = false;
const START_FEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const AUTOPLAY_MS = 1100;

const boardEl = document.getElementById('board-games');
const piecesLayer = document.getElementById('pieces-layer-games');
const panelEl = document.getElementById('panel-games');
const playerTopEl = document.getElementById('player-top');
const playerBottomEl = document.getElementById('player-bottom');
const resultBadge = document.getElementById('result-badge');
const openingLine = document.getElementById('opening-line');
const moveIndexEl = document.getElementById('move-index');
const moveTotalEl = document.getElementById('move-total');
const calcLine = document.getElementById('calc-line');
const btnStart = document.getElementById('btn-start');
const btnPrev = document.getElementById('btn-prev');
const btnPlay = document.getElementById('btn-play');
const btnNext = document.getElementById('btn-next');
const btnEnd = document.getElementById('btn-end');
const btnNew = document.getElementById('btn-new');
const btnLichess = document.getElementById('btn-lichess');
const maximizeBtn = document.getElementById('maximize-btn-games');

let orientation = 'white';
let currentGame = null;
let moveIndex = 0; // cantidad de jugadas ya aplicadas (0 = posicion inicial)
let lastMoveSquares = [];
let autoplayHandle = null;

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
      boardEl.appendChild(sq);
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
  for (const row of board) {
    for (const piece of row) {
      if (!piece) continue;
      const [col, rowIdx] = squareToXY(piece.square);
      const img = document.createElement('img');
      img.className = 'piece';
      img.src = pieceImgSrc(piece);
      img.draggable = false;
      img.style.left = `${col * SQUARE_SIZE}px`;
      img.style.top = `${rowIdx * SQUARE_SIZE}px`;
      piecesLayer.appendChild(img);
    }
  }
}

function clearSquareStyles() {
  boardEl.querySelectorAll('.square').forEach((sq) => {
    sq.classList.remove('last-move', 'check');
  });
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

function setPlayerLine(el, name, elo, colorClass) {
  el.innerHTML = '';
  const dot = document.createElement('span');
  dot.className = `piece-dot ${colorClass}`;
  el.appendChild(dot);

  const nameSpan = document.createElement('span');
  nameSpan.className = 'name-text';
  nameSpan.textContent = name;
  nameSpan.title = name;
  el.appendChild(nameSpan);

  if (elo) {
    const eloSpan = document.createElement('span');
    eloSpan.className = 'elo';
    eloSpan.textContent = ` (${elo})`;
    el.appendChild(eloSpan);
  }
}

function renderAll() {
  clearSquareStyles();
  renderPieces();
  highlightLastMove();
  highlightCheck();
}

function gotoMove(idx) {
  idx = Math.max(0, Math.min(currentGame.moves.length, idx));
  window.chessAPI.load(START_FEN);
  lastMoveSquares = [];
  for (let i = 0; i < idx; i++) {
    const mv = window.chessAPI.move(currentGame.moves[i].san);
    if (mv) lastMoveSquares = [mv.from, mv.to];
  }
  moveIndex = idx;
  moveIndexEl.textContent = moveIndex;
  renderAll();
  updateControlsState();
  updateCalcLine();
  syncSize();
}

function updateCalcLine() {
  if (moveIndex === 0) {
    calcLine.textContent = '';
    return;
  }
  const mv = currentGame.moves[moveIndex - 1];
  if (mv.book) {
    calcLine.textContent = 'Jugada de apertura (libro)';
    return;
  }
  if (mv.eval === undefined) {
    calcLine.textContent = '';
    return;
  }
  let text = `Eval TCEC: ${mv.eval}`;
  if (mv.depth) text += ` (prof. ${mv.depth})`;
  if (mv.pv && mv.pv.length > 1) {
    text += ` · esperaba: ${mv.pv.slice(1).join(' ')}`;
  }
  calcLine.textContent = text;
}

function updateControlsState() {
  const atStart = moveIndex === 0;
  const atEnd = moveIndex >= currentGame.moves.length;
  btnStart.disabled = atStart;
  btnPrev.disabled = atStart;
  btnNext.disabled = atEnd;
  btnEnd.disabled = atEnd;
  if (atEnd) stopAutoplay();
}

async function loadRandomGame() {
  stopAutoplay();
  const game = await window.gamesAPI.getRandomGame();
  if (!game) return;
  currentGame = game;
  orientation = game.winner === 'w' ? 'white' : 'black';

  const bottomIsWhite = orientation === 'white';
  setPlayerLine(
    playerTopEl,
    bottomIsWhite ? game.black : game.white,
    bottomIsWhite ? game.blackElo : game.whiteElo,
    bottomIsWhite ? 'b' : 'w',
  );
  setPlayerLine(
    playerBottomEl,
    bottomIsWhite ? game.white : game.black,
    bottomIsWhite ? game.whiteElo : game.blackElo,
    bottomIsWhite ? 'w' : 'b',
  );
  resultBadge.textContent = game.result;
  openingLine.textContent = game.opening ? `${game.opening}${game.eco ? ` (${game.eco})` : ''}` : '';
  moveTotalEl.textContent = game.moves.length;

  buildEmptyBoard();
  gotoMove(0);
  syncSize();
}

function startAutoplay() {
  if (autoplayHandle) return;
  btnPlay.textContent = '⏸';
  btnPlay.classList.add('active');
  autoplayHandle = setInterval(() => {
    if (moveIndex >= currentGame.moves.length) {
      stopAutoplay();
      return;
    }
    gotoMove(moveIndex + 1);
  }, AUTOPLAY_MS);
}

function stopAutoplay() {
  if (autoplayHandle) clearInterval(autoplayHandle);
  autoplayHandle = null;
  btnPlay.textContent = '▶';
  btnPlay.classList.remove('active');
}

function toggleAutoplay() {
  if (autoplayHandle) stopAutoplay();
  else startAutoplay();
}

function syncSize() {
  requestAnimationFrame(() => {
    window.api.resizeOverlay(panelEl.scrollWidth, panelEl.scrollHeight);
  });
}

function toggleMaximize() {
  isMaximized = !isMaximized;
  SQUARE_SIZE = isMaximized ? SQUARE_SIZE_LARGE : SQUARE_SIZE_COMPACT;
  document.documentElement.style.setProperty('--square-size', `${SQUARE_SIZE}px`);
  maximizeBtn.textContent = isMaximized ? '⤡' : '⤢';
  maximizeBtn.title = isMaximized ? 'Achicar tablero' : 'Agrandar tablero';
  if (currentGame) {
    buildEmptyBoard();
    gotoMove(moveIndex);
  }
  syncSize();
}

function openInLichess() {
  if (!currentGame) return;
  const fen = window.chessAPI.fen().replace(/ /g, '_');
  const url = `https://lichess.org/analysis/${fen}?color=${orientation}`;
  window.api.openExternal(url);
}

maximizeBtn.addEventListener('click', toggleMaximize);

btnStart.addEventListener('click', () => gotoMove(0));
btnPrev.addEventListener('click', () => gotoMove(moveIndex - 1));
btnNext.addEventListener('click', () => gotoMove(moveIndex + 1));
btnEnd.addEventListener('click', () => gotoMove(currentGame.moves.length));
btnPlay.addEventListener('click', toggleAutoplay);
btnNew.addEventListener('click', () => loadRandomGame());
btnLichess.addEventListener('click', openInLichess);

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    window.api.closeOverlay();
  } else if (e.key === 'ArrowLeft') {
    gotoMove(moveIndex - 1);
  } else if (e.key === 'ArrowRight') {
    gotoMove(moveIndex + 1);
  } else if (e.key === ' ') {
    e.preventDefault();
    toggleAutoplay();
  } else if (e.key.toLowerCase() === 'n') {
    loadRandomGame();
  }
});

window.api.onOverlayShown(() => {
  if (!currentGame) loadRandomGame();
});

window.api.onOverlayHidden(() => {
  stopAutoplay();
});
