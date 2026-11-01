// Mimicaço da Turma do Rawzinho: servidor do jogo de mímica.
// Serve as páginas e mantém as salas em memória, conversando com a tela principal e os celulares por WebSocket.
const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { WebSocketServer } = require('ws');
const QRCode = require('qrcode');
const { CATEGORIES, TWISTS } = require('./cards');

const PORT = process.env.PORT || 3000;
const PUBLIC = path.join(__dirname, 'public');
const TEAM_PRESETS = [
  { name: 'Equipe Rawzinho', color: '#5cc93a' },
  { name: 'Equipe Morango', color: '#e8453c' },
  { name: 'Equipe Mochila', color: '#2f7bf5' },
  { name: 'Equipe Sol', color: '#ffc21a' },
  { name: 'Equipe Uva', color: '#a26bff' },
  { name: 'Equipe Chiclete', color: '#ff6fb5' },
];
const CAT_ORDER = ['acao', 'objeto', 'gente', 'bicho', 'lugar', 'dificil'];
const ROOM_TTL_MS = 6 * 60 * 60 * 1000;
const BONUS_STEAL = 2; // casas extras para quem acerta na repescagem
const BONUS_ALL = 3; // casas extras para quem acerta no "Todos jogam"
const JUMP = 2; // casa "Pulo do Rawzinho"

// Tempo da animação de um movimento (precisa bater com board3d.js)
const DICE_MS = 1700;
const HOP_MS = 330;
function moveDuration(move) {
  return (move.kind === 'dice' ? DICE_MS : 400) + move.path.length * HOP_MS + 300;
}

// ---------- Tabuleiro ----------
function buildBoard(length) {
  const squares = [{ type: 'start' }];
  let c = 0;
  for (let i = 1; i < length - 1; i++) {
    if (i % 7 === 0) squares.push({ type: 'all' }); // Todos jogam
    else if (i % 11 === 4) squares.push({ type: 'jump' }); // Pulo do Rawzinho: anda +2
    else squares.push({ type: 'cat', cat: CAT_ORDER[c++ % CAT_ORDER.length] });
  }
  squares.push({ type: 'finish', cat: 'dificil' });
  return squares;
}

// ---------- Salas ----------
const rooms = new Map();

function newCode() {
  const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  let code;
  do code = Array.from({ length: 4 }, () => letters[crypto.randomInt(letters.length)]).join('');
  while (rooms.has(code));
  return code;
}

function createRoom() {
  const code = newCode();
  const room = {
    code,
    hostKey: crypto.randomBytes(12).toString('hex'),
    sockets: new Set(),
    settings: { teamCount: 2, seconds: 60, boardLength: 31, twists: true, steal: true, again: true },
    teams: [],
    players: {}, // pid -> { names: [], teamId, connected }
    phase: 'lobby', // lobby | turn | draw | card | miming | timeup | over
    turn: null, // { teamIdx, allPlay, steal, stealIdx }
    mimerIdx: {},
    card: null,
    timerEnd: null,
    move: null, // último movimento: { id, teamId, kind, value, path, at, dur }
    moveSeq: 0,
    result: null, // { id, kind: 'hit' | 'miss' | 'steal_hit' | 'all_hit', teamId, word }
    resultSeq: 0,
    winner: null,
    decks: {},
    message: '',
    touched: Date.now(),
  };
  setTeams(room, 2);
  room.board = buildBoard(room.settings.boardLength);
  rooms.set(code, room);
  return room;
}

function setTeams(room, n) {
  const old = room.teams;
  room.teams = TEAM_PRESETS.slice(0, n).map((p, i) => ({ id: 't' + i, name: old[i]?.name || p.name, color: p.color, pos: 0 }));
  for (const pl of Object.values(room.players)) if (!room.teams.find((t) => t.id === pl.teamId)) pl.teamId = null;
}

function drawWord(room, cat) {
  if (!room.decks[cat] || room.decks[cat].length === 0) room.decks[cat] = shuffle([...CATEGORIES[cat].words]);
  return room.decks[cat].pop();
}

function shuffle(a) {
  for (let i = a.length - 1; i > 0; i--) {
    const j = crypto.randomInt(i + 1);
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

const last = (room) => room.board.length - 1;
const squareAt = (room, pos) => room.board[Math.min(pos, last(room))];

// Cada celular pode ter várias pessoas. O mímico gira entre as pessoas da equipe.
function slots(room, teamId) {
  const out = [];
  for (const [pid, p] of Object.entries(room.players)) {
    if (p.teamId !== teamId) continue;
    p.names.forEach((name, i) => out.push({ pid, i, name, connected: p.connected }));
  }
  return out;
}

// Equipe que está fazendo a mímica agora (na repescagem é a próxima equipe).
function actingTeam(room) {
  if (!room.turn) return null;
  return room.teams[room.turn.steal ? room.turn.stealIdx : room.turn.teamIdx];
}
const turnTeam = (room) => (room.turn ? room.teams[room.turn.teamIdx] : null);

function currentMimer(room) {
  const team = actingTeam(room);
  if (!team) return null;
  const list = slots(room, team.id);
  if (!list.length) return null;
  const start = room.mimerIdx[team.id] || 0;
  for (let k = 0; k < list.length; k++) {
    const s = list[(start + k) % list.length];
    if (s.connected) return s;
  }
  return list[start % list.length];
}

function advanceMimer(room, team) {
  const n = slots(room, team.id).length;
  if (n) room.mimerIdx[team.id] = ((room.mimerIdx[team.id] || 0) + 1) % n;
}

function startTurn(room, teamIdx, message = '') {
  room.turn = { teamIdx, allPlay: false, steal: false, stealIdx: null };
  room.card = null;
  room.timerEnd = null;
  room.phase = 'turn';
  room.message = message;
}

const nextIdx = (room, i) => (i + 1) % room.teams.length;

// Anda com o peão e registra o caminho casa a casa para a animação.
function moveTeam(room, team, steps, kind, value = null) {
  const from = team.pos;
  const pathArr = [];
  let pos = from;
  for (let s = 0; s < steps && pos < last(room); s++) pathArr.push(++pos);
  let jumped = false;
  if (kind === 'dice' && squareAt(room, pos).type === 'jump') {
    jumped = true;
    for (let s = 0; s < JUMP && pos < last(room); s++) pathArr.push(++pos);
  }
  team.pos = pos;
  room.move = { id: ++room.moveSeq, teamId: team.id, kind, value, from, path: pathArr, jumped, at: Date.now() };
  room.move.dur = moveDuration(room.move);
  return room.move;
}

function setResult(room, kind, teamId, word) {
  room.result = { id: ++room.resultSeq, kind, teamId, word };
}

function startTimer(room, seconds) {
  room.phase = 'miming';
  room.timerEnd = Date.now() + seconds * 1000;
  clearTimeout(room.timer);
  room.timer = setTimeout(() => {
    if (room.phase === 'miming') {
      room.phase = 'timeup';
      broadcast(room);
    }
  }, seconds * 1000 + 300);
}

// ---------- Ações ----------
function handle(room, who, msg) {
  const host = who.host;
  const me = who.pid && room.players[who.pid];
  const mimer = currentMimer(room);
  const isMimer = mimer && who.pid === mimer.pid;
  const acting = actingTeam(room);
  const inActing = me && acting && me.teamId === acting.id;
  const can = host || isMimer;
  switch (msg.t) {
    case 'join_team': {
      if (!me) return;
      const team = room.teams.find((t) => t.id === msg.teamId);
      if (team) { me.teamId = team.id; me.judge = false; }
      break;
    }
    case 'be_judge': {
      // o juiz não joga por nenhuma equipe, vê as palavras e decide acertou/errou
      if (!me) return;
      me.judge = !!msg.on;
      if (me.judge) me.teamId = null;
      break;
    }
    case 'names': {
      if (!me) return;
      const names = (Array.isArray(msg.names) ? msg.names : [])
        .map((n) => String(n || '').trim().slice(0, 20))
        .filter(Boolean)
        .slice(0, 8);
      if (names.length) me.names = names;
      break;
    }
    case 'settings': {
      if (!host || room.phase !== 'lobby') return;
      const s = msg.settings || {};
      if (s.teamCount >= 2 && s.teamCount <= 6) setTeams(room, s.teamCount | 0);
      if ([30, 45, 60, 90, 120].includes(s.seconds)) room.settings.seconds = s.seconds;
      if ([21, 31, 41].includes(s.boardLength)) {
        room.settings.boardLength = s.boardLength;
        room.board = buildBoard(s.boardLength);
      }
      for (const k of ['twists', 'steal', 'again']) if (typeof s[k] === 'boolean') room.settings[k] = s[k];
      room.settings.teamCount = room.teams.length;
      break;
    }
    case 'team_name': {
      if (!host) return;
      const team = room.teams.find((t) => t.id === msg.teamId);
      const name = String(msg.name || '').trim().slice(0, 20);
      if (team && name) team.name = name;
      break;
    }
    case 'start_game': {
      if (!host || room.phase !== 'lobby') return;
      room.teams.forEach((t) => (t.pos = 0));
      room.winner = null;
      room.move = null;
      room.result = null;
      startTurn(room, 0);
      break;
    }
    case 'roll': {
      // qualquer pessoa da equipe da vez (ou a tela principal) pode jogar o dado
      if (room.phase !== 'turn' || !(host || inActing)) return;
      if (room.move && Date.now() < room.move.at + room.move.dur - 200) return; // espera a animação anterior
      const team = turnTeam(room);
      const value = 1 + crypto.randomInt(6);
      const mv = moveTeam(room, team, value, 'dice', value);
      const sq = squareAt(room, team.pos);
      room.turn.allPlay = sq.type === 'all';
      room.phase = 'draw';
      room.message = mv.jumped ? 'Pulo do Rawzinho! +2 casas' : '';
      break;
    }
    case 'draw': {
      if (!can || room.phase !== 'draw') return;
      const team = turnTeam(room);
      const sq = squareAt(room, team.pos);
      const cat = sq.cat || CAT_ORDER[crypto.randomInt(CAT_ORDER.length)];
      const twist = room.settings.twists && crypto.randomInt(4) === 0 ? TWISTS[crypto.randomInt(TWISTS.length)] : null;
      room.card = { cat, word: drawWord(room, cat), twist };
      room.phase = 'card';
      break;
    }
    case 'swap_card': {
      if (!can || room.phase !== 'card' || room.card.swapped || room.turn.steal) return;
      room.card.word = drawWord(room, room.card.cat);
      room.card.swapped = true;
      break;
    }
    case 'go': {
      if (!can || room.phase !== 'card') return;
      const secs = room.turn.steal ? Math.ceil(room.settings.seconds / 2) : room.settings.seconds;
      startTimer(room, secs);
      break;
    }
    case 'result': {
      const judging = hasJudge(room) ? host || me?.judge : can;
      if (!judging || !['miming', 'timeup'].includes(room.phase)) return;
      clearTimeout(room.timer);
      onResult(room, msg.teamId || null);
      break;
    }
    case 'skip_mimer': {
      if (!host || !['turn', 'draw', 'card'].includes(room.phase)) return;
      advanceMimer(room, actingTeam(room));
      break;
    }
    case 'skip_turn': {
      if (!host || ['lobby', 'over'].includes(room.phase)) return;
      clearTimeout(room.timer);
      startTurn(room, nextIdx(room, room.turn.teamIdx));
      break;
    }
    case 'back_to_lobby': {
      if (!host) return;
      clearTimeout(room.timer);
      Object.assign(room, { phase: 'lobby', turn: null, card: null, winner: null, move: null, result: null });
      room.teams.forEach((t) => (t.pos = 0));
      break;
    }
  }
}

function hasJudge(room) {
  return Object.values(room.players).some((p) => p.judge && p.connected);
}

function onResult(room, guessedTeamId) {
  const team = turnTeam(room);
  const word = room.card.word;
  const onFinish = team.pos === last(room);

  // Repescagem: a próxima equipe tentou a mesma carta
  if (room.turn.steal) {
    const stealTeam = room.teams[room.turn.stealIdx];
    advanceMimer(room, stealTeam);
    if (guessedTeamId) {
      setResult(room, 'steal_hit', stealTeam.id, word);
      moveTeam(room, stealTeam, BONUS_STEAL, 'bonus');
      startTurn(room, room.turn.stealIdx, `${stealTeam.name} roubou a carta e ganhou +${BONUS_STEAL} casas!`);
    } else {
      setResult(room, 'miss', null, word);
      startTurn(room, room.turn.stealIdx, `Ninguém acertou "${word}".`);
    }
    return;
  }

  advanceMimer(room, team);

  // Todos jogam: quem acertar ganha casas extras
  if (room.turn.allPlay) {
    const winner = room.teams.find((t) => t.id === guessedTeamId);
    if (!winner) {
      setResult(room, 'miss', null, word);
      return startTurn(room, nextIdx(room, room.turn.teamIdx), `Ninguém acertou "${word}".`);
    }
    setResult(room, 'all_hit', winner.id, word);
    moveTeam(room, winner, BONUS_ALL, 'bonus');
    const again = winner.id === team.id && room.settings.again;
    return startTurn(room, again ? room.turn.teamIdx : nextIdx(room, room.turn.teamIdx),
      `${winner.name} acertou e ganhou +${BONUS_ALL} casas!`);
  }

  if (guessedTeamId) {
    setResult(room, 'hit', team.id, word);
    if (onFinish) {
      room.winner = team.id;
      room.phase = 'over';
      return;
    }
    return startTurn(room, room.settings.again ? room.turn.teamIdx : nextIdx(room, room.turn.teamIdx),
      room.settings.again ? `${team.name} acertou e joga de novo!` : `${team.name} acertou!`);
  }

  // Errou: a próxima equipe tenta a mesma carta, com metade do tempo
  if (room.settings.steal && room.teams.length > 1 && slots(room, room.teams[nextIdx(room, room.turn.teamIdx)].id).length) {
    setResult(room, 'miss', null, null);
    room.turn.steal = true;
    room.turn.stealIdx = nextIdx(room, room.turn.teamIdx);
    room.card.twist = null;
    room.timerEnd = null;
    room.phase = 'card';
    room.message = `Repescagem! ${room.teams[room.turn.stealIdx].name} tenta a mesma carta.`;
    return;
  }
  setResult(room, 'miss', null, word);
  startTurn(room, nextIdx(room, room.turn.teamIdx), `Ninguém acertou "${word}".`);
}

// ---------- Estado enviado a cada tela ----------
// A palavra só vai para quem pode ver: o celular do mímico e as equipes juízas (fora do "Todos jogam").
function viewFor(room, who) {
  const mimer = currentMimer(room);
  const acting = actingTeam(room);
  let canSee = false;
  if (room.card && who.pid) {
    const me = room.players[who.pid];
    if (mimer && who.pid === mimer.pid) canSee = true;
    else if (me?.judge) canSee = true;
    else if (acting && !room.turn.allPlay && me?.teamId && me.teamId !== acting.id && room.phase !== 'card') canSee = true;
  }
  const card = room.card
    ? { cat: room.card.cat, twist: room.card.twist, swapped: !!room.card.swapped, word: canSee || (who.host && who.peek) ? room.card.word : null }
    : null;
  return {
    t: 'state',
    code: room.code,
    you: who.host ? { host: true } : { pid: who.pid, ...room.players[who.pid] },
    settings: room.settings,
    teams: room.teams.map((t) => ({ ...t, people: slots(room, t.id) })),
    unassigned: Object.entries(room.players).filter(([, p]) => !p.teamId && !p.judge).map(([pid, p]) => ({ pid, ...p })),
    judges: Object.entries(room.players).filter(([, p]) => p.judge).map(([pid, p]) => ({ pid, ...p })),
    hasJudge: hasJudge(room),
    board: room.board,
    phase: room.phase,
    turn: room.turn
      ? { ...room.turn, teamId: turnTeam(room).id, actingId: acting.id, mimer: mimer ? { pid: mimer.pid, name: mimer.name } : null }
      : null,
    card,
    timerEnd: room.timerEnd,
    now: Date.now(),
    move: room.move,
    result: room.result,
    winner: room.winner,
    message: room.message,
    categories: Object.fromEntries(Object.entries(CATEGORIES).map(([k, c]) => [k, { name: c.name, emoji: c.emoji, color: c.color }])),
  };
}

function broadcast(room) {
  room.touched = Date.now();
  for (const ws of room.sockets) if (ws.readyState === 1) ws.send(JSON.stringify(viewFor(room, ws.who)));
}

// ---------- HTTP ----------
const MIME = {
  '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.svg': 'image/svg+xml',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.mp3': 'audio/mpeg', '.ttf': 'font/ttf', '.txt': 'text/plain; charset=utf-8',
};

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://x');
  if (url.pathname === '/api/new' && req.method === 'POST') {
    const room = createRoom();
    res.writeHead(200, { 'content-type': 'application/json' });
    return res.end(JSON.stringify({ code: room.code, hostKey: room.hostKey }));
  }
  if (url.pathname === '/api/qr') {
    const text = (url.searchParams.get('u') || '').slice(0, 300);
    const svg = await QRCode.toString(text, { type: 'svg', margin: 1, color: { dark: '#123a7a', light: '#ffffff' } });
    res.writeHead(200, { 'content-type': 'image/svg+xml' });
    return res.end(svg);
  }
  if (url.pathname === '/health') {
    res.writeHead(200);
    return res.end('ok');
  }
  // Atalho: /ABCD abre a tela do celular já com o código.
  if (/^\/[A-Za-z]{4}$/.test(url.pathname)) {
    res.writeHead(302, { location: '/jogar.html?sala=' + url.pathname.slice(1).toUpperCase() });
    return res.end();
  }
  const file = url.pathname === '/' ? '/index.html' : url.pathname;
  const full = path.join(PUBLIC, path.normalize(decodeURIComponent(file)));
  if (!full.startsWith(PUBLIC)) {
    res.writeHead(403);
    return res.end();
  }
  fs.readFile(full, (err, data) => {
    if (err) {
      res.writeHead(404);
      return res.end('Não encontrado');
    }
    const ext = path.extname(full);
    const cache = ['.jpg', '.png', '.mp3', '.ttf'].includes(ext) || full.includes('/vendor/') ? 'public, max-age=86400' : 'no-cache';
    res.writeHead(200, { 'content-type': MIME[ext] || 'application/octet-stream', 'cache-control': cache });
    res.end(data);
  });
});

// ---------- WebSocket ----------
const wss = new WebSocketServer({ server, path: '/ws' });

wss.on('connection', (ws) => {
  ws.isAlive = true;
  ws.on('pong', () => (ws.isAlive = true));
  ws.on('message', (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw);
    } catch {
      return;
    }
    if (msg.t === 'hello') {
      const room = rooms.get(String(msg.code || '').toUpperCase());
      if (!room) return ws.send(JSON.stringify({ t: 'error', error: 'Sala não encontrada. Confira o código.' }));
      if (msg.hostKey) {
        if (msg.hostKey !== room.hostKey) return ws.send(JSON.stringify({ t: 'error', error: 'Chave da tela principal inválida.' }));
        ws.who = { host: true };
      } else {
        const pid = String(msg.pid || '').slice(0, 40) || crypto.randomUUID();
        let names = (Array.isArray(msg.names) ? msg.names : [msg.name]).map((n) => String(n || '').trim().slice(0, 20)).filter(Boolean).slice(0, 8);
        if (!names.length) names = ['Jogador'];
        if (!room.players[pid]) room.players[pid] = { names, teamId: null, judge: false, connected: true };
        room.players[pid].connected = true;
        ws.who = { pid };
      }
      ws.room = room;
      room.sockets.add(ws);
      return broadcast(room);
    }
    if (!ws.room) return;
    if (msg.t === 'peek' && ws.who.host) {
      ws.who.peek = !!msg.on;
      return ws.send(JSON.stringify(viewFor(ws.room, ws.who)));
    }
    handle(ws.room, ws.who, msg);
    broadcast(ws.room);
  });
  ws.on('close', () => {
    const room = ws.room;
    if (!room) return;
    room.sockets.delete(ws);
    if (ws.who.pid && room.players[ws.who.pid]) {
      room.players[ws.who.pid].connected = [...room.sockets].some((s) => s.who.pid === ws.who.pid);
    }
    broadcast(room);
  });
});

// Mantém conexões vivas e limpa salas antigas.
setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.isAlive) ws.terminate();
    else {
      ws.isAlive = false;
      ws.ping();
    }
  }
  for (const [code, room] of rooms) if (room.sockets.size === 0 && Date.now() - room.touched > ROOM_TTL_MS) rooms.delete(code);
}, 30000);

server.listen(PORT, () => console.log(`Mimicaço rodando em http://localhost:${PORT}`));
