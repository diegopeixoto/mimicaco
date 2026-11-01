// Mimicaço: servidor do jogo de mímica.
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
  { name: 'Equipe Coral', color: '#ff6b6b' },
  { name: 'Equipe Oceano', color: '#4dabf7' },
  { name: 'Equipe Limão', color: '#94d82d' },
  { name: 'Equipe Uva', color: '#b197fc' },
  { name: 'Equipe Laranja', color: '#ffa94d' },
  { name: 'Equipe Menta', color: '#38d9a9' },
];
const CAT_ORDER = ['acao', 'objeto', 'gente', 'bicho', 'lugar', 'dificil'];
const ROOM_TTL_MS = 6 * 60 * 60 * 1000;

// ---------- Tabuleiro ----------
function buildBoard(length) {
  const squares = [{ type: 'start' }];
  for (let i = 1; i < length - 1; i++) {
    if (i % 6 === 0) squares.push({ type: 'all' }); // Todos jogam
    else squares.push({ type: 'cat', cat: CAT_ORDER[(i - 1) % 5] }); // sem "Desafio" no meio
  }
  squares.push({ type: 'finish', cat: 'dificil' });
  return squares;
}

// ---------- Salas ----------
const rooms = new Map();

function newCode() {
  const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  let code;
  do {
    code = Array.from({ length: 4 }, () => letters[crypto.randomInt(letters.length)]).join('');
  } while (rooms.has(code));
  return code;
}

function createRoom() {
  const code = newCode();
  const room = {
    code,
    hostKey: crypto.randomBytes(12).toString('hex'),
    sockets: new Set(),
    settings: { teamCount: 2, seconds: 60, boardLength: 31, twists: true },
    teams: [],
    players: {}, // pid -> { name, teamId, connected }
    phase: 'lobby', // lobby | turn | card | miming | timeup | roll | over
    turn: null, // { teamIdx, allPlay }
    mimerIdx: {}, // teamId -> índice do próximo mímico
    card: null, // { cat, word, twist }
    timerEnd: null,
    lastRoll: null, // { teamId, value, from, to }
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
  room.teams = TEAM_PRESETS.slice(0, n).map((p, i) => ({
    id: 't' + i,
    name: old[i]?.name || p.name,
    color: p.color,
    pos: 0,
  }));
  for (const pl of Object.values(room.players)) {
    if (!room.teams.find((t) => t.id === pl.teamId)) pl.teamId = null;
  }
}

function drawWord(room, cat) {
  if (!room.decks[cat] || room.decks[cat].length === 0) {
    room.decks[cat] = shuffle([...CATEGORIES[cat].words]);
  }
  return room.decks[cat].pop();
}

function shuffle(a) {
  for (let i = a.length - 1; i > 0; i--) {
    const j = crypto.randomInt(i + 1);
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function teamPlayers(room, teamId) {
  return Object.entries(room.players)
    .filter(([, p]) => p.teamId === teamId)
    .map(([pid]) => pid);
}

function currentTeam(room) {
  return room.turn ? room.teams[room.turn.teamIdx] : null;
}

// Mímico da vez: próximo jogador conectado da equipe (rodízio).
function currentMimer(room) {
  const team = currentTeam(room);
  if (!team) return null;
  const pids = teamPlayers(room, team.id);
  if (pids.length === 0) return null;
  const start = room.mimerIdx[team.id] || 0;
  for (let k = 0; k < pids.length; k++) {
    const pid = pids[(start + k) % pids.length];
    if (room.players[pid].connected) return pid;
  }
  return pids[start % pids.length];
}

function squareAt(room, pos) {
  return room.board[Math.min(pos, room.board.length - 1)];
}

function startTurn(room, teamIdx) {
  const team = room.teams[teamIdx];
  const sq = squareAt(room, team.pos);
  room.turn = { teamIdx, allPlay: sq.type === 'all' };
  room.card = null;
  room.timerEnd = null;
  room.phase = 'turn';
  room.message = '';
}

function nextTeamIdx(room) {
  return (room.turn.teamIdx + 1) % room.teams.length;
}

function advanceMimer(room) {
  const team = currentTeam(room);
  const pids = teamPlayers(room, team.id);
  if (pids.length) room.mimerIdx[team.id] = ((room.mimerIdx[team.id] || 0) + 1) % pids.length;
}

// ---------- Ações ----------
function isMimer(room, who) {
  return who.pid && who.pid === currentMimer(room);
}

function handle(room, who, msg) {
  const host = who.host;
  const mimerOrHost = host || isMimer(room, who);
  switch (msg.t) {
    case 'join_team': {
      if (!who.pid) return;
      const team = room.teams.find((t) => t.id === msg.teamId);
      if (team) room.players[who.pid].teamId = team.id;
      break;
    }
    case 'rename': {
      if (!who.pid) return;
      const name = String(msg.name || '').trim().slice(0, 20);
      if (name) room.players[who.pid].name = name;
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
      if (typeof s.twists === 'boolean') room.settings.twists = s.twists;
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
    case 'kick': {
      if (!host) return;
      delete room.players[msg.pid];
      break;
    }
    case 'start_game': {
      if (!host || room.phase !== 'lobby') return;
      room.teams.forEach((t) => (t.pos = 0));
      room.winner = null;
      room.lastRoll = null;
      startTurn(room, 0);
      break;
    }
    case 'draw': {
      if (!mimerOrHost || room.phase !== 'turn') return;
      const team = currentTeam(room);
      const sq = squareAt(room, team.pos);
      let cat;
      if (sq.type === 'cat' || sq.type === 'finish') cat = sq.cat;
      else cat = CAT_ORDER[crypto.randomInt(CAT_ORDER.length)]; // início e "Todos jogam": categoria sorteada
      const twist = room.settings.twists && crypto.randomInt(4) === 0 ? TWISTS[crypto.randomInt(TWISTS.length)] : null;
      room.card = { cat, word: drawWord(room, cat), twist };
      room.phase = 'card';
      break;
    }
    case 'swap_card': {
      // Mímico não conhece a palavra: troca uma vez de graça.
      if (!mimerOrHost || room.phase !== 'card' || room.card.swapped) return;
      room.card.word = drawWord(room, room.card.cat);
      room.card.swapped = true;
      break;
    }
    case 'go': {
      if (!mimerOrHost || room.phase !== 'card') return;
      room.phase = 'miming';
      room.timerEnd = Date.now() + room.settings.seconds * 1000;
      clearTimeout(room.timer);
      room.timer = setTimeout(() => {
        if (room.phase === 'miming') {
          room.phase = 'timeup';
          broadcast(room);
        }
      }, room.settings.seconds * 1000 + 300);
      break;
    }
    case 'result': {
      // msg.teamId: equipe que acertou (ou null = ninguém)
      if (!mimerOrHost || !['miming', 'timeup'].includes(room.phase)) return;
      clearTimeout(room.timer);
      const team = currentTeam(room);
      let winnerTeam = null;
      if (msg.teamId) {
        winnerTeam = room.turn.allPlay ? room.teams.find((t) => t.id === msg.teamId) : team;
      }
      room.revealed = { ...room.card };
      advanceMimer(room);
      if (!winnerTeam) {
        room.lastRoll = null;
        startTurn(room, nextTeamIdx(room));
        room.message = `Ninguém acertou "${room.revealed.word}".`;
        return;
      }
      // Rola o dado e anda.
      const value = 1 + crypto.randomInt(6);
      const from = winnerTeam.pos;
      const to = Math.min(from + value, room.board.length - 1);
      const wasOnFinish = team.pos === room.board.length - 1 && winnerTeam.id === team.id;
      winnerTeam.pos = to;
      room.lastRoll = { teamId: winnerTeam.id, value, from, to, word: room.card.word };
      if (wasOnFinish) {
        room.winner = winnerTeam.id;
        room.phase = 'over';
        return;
      }
      room.phase = 'roll';
      room.message = `${winnerTeam.name} acertou "${room.card.word}" e tirou ${value} no dado!`;
      break;
    }
    case 'next': {
      if (!mimerOrHost || room.phase !== 'roll') return;
      startTurn(room, nextTeamIdx(room));
      break;
    }
    case 'skip_mimer': {
      if (!host || room.phase !== 'turn') return;
      advanceMimer(room);
      break;
    }
    case 'skip_turn': {
      if (!host || !['turn', 'card'].includes(room.phase)) return;
      startTurn(room, nextTeamIdx(room));
      break;
    }
    case 'back_to_lobby': {
      if (!host) return;
      clearTimeout(room.timer);
      room.phase = 'lobby';
      room.turn = null;
      room.card = null;
      room.winner = null;
      room.teams.forEach((t) => (t.pos = 0));
      break;
    }
  }
}

// ---------- Estado enviado a cada tela ----------
// A palavra só vai para quem pode ver: o mímico e, fora do "Todos jogam", as outras equipes (para conferir).
function viewFor(room, who) {
  const team = currentTeam(room);
  const mimer = currentMimer(room);
  let canSee = false;
  if (room.card && who.pid) {
    const me = room.players[who.pid];
    if (who.pid === mimer) canSee = true;
    else if (team && !room.turn.allPlay && me && me.teamId && me.teamId !== team.id && room.phase !== 'card') canSee = true;
  }
  const card = room.card
    ? {
        cat: room.card.cat,
        twist: room.card.twist,
        swapped: !!room.card.swapped,
        word: canSee || (who.host && msgHostPeek(who)) ? room.card.word : null,
      }
    : null;
  return {
    t: 'state',
    code: room.code,
    you: who.host ? { host: true } : { pid: who.pid, ...room.players[who.pid] },
    settings: room.settings,
    teams: room.teams.map((t) => ({ ...t, players: teamPlayers(room, t.id).map((pid) => ({ pid, ...room.players[pid] })) })),
    unassigned: Object.entries(room.players).filter(([, p]) => !p.teamId).map(([pid, p]) => ({ pid, ...p })),
    board: room.board,
    phase: room.phase,
    turn: room.turn ? { ...room.turn, teamId: team.id, mimer, mimerName: mimer ? room.players[mimer]?.name : null } : null,
    card,
    timerEnd: room.timerEnd,
    now: Date.now(),
    lastRoll: room.lastRoll,
    winner: room.winner,
    message: room.message,
    categories: Object.fromEntries(Object.entries(CATEGORIES).map(([k, c]) => [k, { name: c.name, emoji: c.emoji, color: c.color }])),
  };
}
function msgHostPeek(who) {
  return who.peek; // a tela principal só vê a palavra enquanto segura o botão "espiar"
}

function broadcast(room) {
  room.touched = Date.now();
  for (const ws of room.sockets) {
    if (ws.readyState === 1) ws.send(JSON.stringify(viewFor(room, ws.who)));
  }
}

// ---------- HTTP ----------
const MIME = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.svg': 'image/svg+xml', '.png': 'image/png' };

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://x');
  if (url.pathname === '/api/new' && req.method === 'POST') {
    const room = createRoom();
    res.writeHead(200, { 'content-type': 'application/json' });
    return res.end(JSON.stringify({ code: room.code, hostKey: room.hostKey }));
  }
  if (url.pathname === '/api/qr') {
    const text = url.searchParams.get('u') || '';
    const svg = await QRCode.toString(text, { type: 'svg', margin: 1, color: { dark: '#1b1035', light: '#ffffff' } });
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
  let file = url.pathname === '/' ? '/index.html' : url.pathname;
  file = path.normalize(file).replace(/^(\.\.[/\\])+/, '');
  const full = path.join(PUBLIC, file);
  if (!full.startsWith(PUBLIC)) {
    res.writeHead(403);
    return res.end();
  }
  fs.readFile(full, (err, data) => {
    if (err) {
      res.writeHead(404);
      return res.end('Não encontrado');
    }
    res.writeHead(200, { 'content-type': MIME[path.extname(full)] || 'application/octet-stream' });
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
        const name = String(msg.name || '').trim().slice(0, 20) || 'Jogador';
        if (!room.players[pid]) room.players[pid] = { name, teamId: null, connected: true };
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
      const stillOn = [...room.sockets].some((s) => s.who.pid === ws.who.pid);
      room.players[ws.who.pid].connected = stillOn;
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
  for (const [code, room] of rooms) {
    if (room.sockets.size === 0 && Date.now() - room.touched > ROOM_TTL_MS) rooms.delete(code);
  }
}, 30000);

server.listen(PORT, () => console.log(`Mimicaço rodando em http://localhost:${PORT}`));
