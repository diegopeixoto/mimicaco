// Conexão WebSocket com reconexão automática.
function connect(hello, onState, onError) {
  let ws, delay = 500, closedByError = false;
  const api = {
    send(msg) { if (ws && ws.readyState === 1) ws.send(JSON.stringify(msg)); },
    offset: 0, // diferença entre relógio do servidor e do aparelho
  };
  function open() {
    const proto = location.protocol === 'https:' ? 'wss' : 'ws';
    ws = new WebSocket(`${proto}://${location.host}/ws`);
    ws.onopen = () => { delay = 500; setConn(true); ws.send(JSON.stringify({ t: 'hello', ...hello() })); };
    ws.onmessage = (e) => {
      const msg = JSON.parse(e.data);
      if (msg.t === 'error') { closedByError = true; onError(msg.error); ws.close(); return; }
      if (msg.t === 'state') { api.offset = msg.now - Date.now(); onState(msg); }
    };
    ws.onclose = () => {
      setConn(false);
      if (closedByError) return;
      setTimeout(open, delay);
      delay = Math.min(delay * 2, 5000);
    };
  }
  function setConn(ok) {
    document.body.classList.toggle('offline', !ok);
  }
  open();
  return api;
}

function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function store(key, val) {
  try {
    if (val === undefined) return JSON.parse(localStorage.getItem(key) || 'null');
    localStorage.setItem(key, JSON.stringify(val));
  } catch { return null; }
}

function beep(freq = 880, ms = 150) {
  try {
    const ctx = beep.ctx || (beep.ctx = new (window.AudioContext || window.webkitAudioContext)());
    const o = ctx.createOscillator(), g = ctx.createGain();
    o.frequency.value = freq; o.connect(g); g.connect(ctx.destination);
    g.gain.setValueAtTime(0.2, ctx.currentTime);
    g.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + ms / 1000);
    o.start(); o.stop(ctx.currentTime + ms / 1000);
  } catch {}
}

// ---------- Sons (ElevenLabs) ----------
// Música, falas do Rawzinho e efeitos podem ser ligados/desligados separadamente.
const Som = (() => {
  const cache = {};
  let opt = { musica: true, vozes: true, efeitos: true };
  try { opt = { ...opt, ...(JSON.parse(localStorage.getItem('mimica_som2')) || {}) }; } catch {}
  let music = null, unlocked = false, voiceBusy = null, wantMusic = false, track = 'musica';
  const save = () => { try { localStorage.setItem('mimica_som2', JSON.stringify(opt)); } catch {} };
  function get(name) {
    if (!cache[name]) { cache[name] = new Audio(`som/${name}.mp3`); cache[name].preload = 'auto'; }
    return cache[name];
  }
  function raw(name, vol) {
    try { const a = get(name).cloneNode(); a.volume = vol; a.play().catch(() => {}); return a; } catch { return null; }
  }
  function play(name, vol = 0.8) { if (opt.efeitos) return raw(name, vol); }
  // falas do Rawzinho: abaixa a música enquanto ele fala, uma fala por vez
  function voz(name, delay = 0) {
    if (!opt.vozes) return;
    setTimeout(() => {
      if (!opt.vozes) return;
      if (voiceBusy) { try { voiceBusy.pause(); } catch {} }
      const a = raw('voz_' + name, 1);
      if (!a) return;
      voiceBusy = a;
      if (music) music.volume = 0.12;
      a.onended = () => { if (voiceBusy === a) { voiceBusy = null; if (music) music.volume = 0.35; } };
    }, delay);
  }
  function startMusic() {
    wantMusic = true;
    if (!opt.musica || music || !unlocked) return;
    music = new Audio(`som/${track}.mp3`);
    music.loop = true; music.volume = 0.35;
    music.play().catch(() => { music = null; });
  }
  function stopMusic() { if (music) { music.pause(); music = null; } }
  // cada mundo tem sua música
  function setTrack(name) {
    if (name === track) return;
    track = name;
    if (music) { stopMusic(); startMusic(); }
  }
  // navegadores só tocam som depois de um toque na tela
  function unlock(withMusic, cb) {
    wantMusic = withMusic;
    const go = () => {
      if (unlocked) return; unlocked = true;
      if (withMusic) startMusic();
      cb && cb();
    };
    ['pointerdown', 'keydown'].forEach((ev) => addEventListener(ev, go, { once: true }));
  }
  function button(withMusic) {
    const wrap = document.createElement('div');
    wrap.className = 'sound-box';
    const b = document.createElement('button');
    b.className = 'sound-toggle ghost';
    const menu = document.createElement('div');
    menu.className = 'sound-menu panel hidden';
    const items = [['musica', '🎵 Música'], ['vozes', '🦖 Falas do Rawzinho'], ['efeitos', '🔔 Efeitos']].filter(([k]) => withMusic || k !== 'musica');
    const draw = () => {
      const anyOn = items.some(([k]) => opt[k]);
      b.textContent = anyOn ? '🔊' : '🔇';
      menu.innerHTML = items.map(([k, label]) => `<label><span>${label}</span><input type="checkbox" data-som="${k}" ${opt[k] ? 'checked' : ''}></label>`).join('');
      menu.querySelectorAll('[data-som]').forEach((el) => (el.onchange = () => {
        opt[el.dataset.som] = el.checked; save();
        if (el.dataset.som === 'musica') { if (el.checked && wantMusic) startMusic(); else stopMusic(); }
        if (el.dataset.som === 'vozes' && !el.checked && voiceBusy) { voiceBusy.pause(); voiceBusy = null; if (music) music.volume = 0.35; }
        draw();
      }));
    };
    draw();
    b.onclick = (e) => { e.stopPropagation(); menu.classList.toggle('hidden'); };
    menu.onclick = (e) => e.stopPropagation();
    addEventListener('click', () => menu.classList.add('hidden'));
    wrap.append(menu, b);
    document.body.appendChild(wrap);
  }
  return { play, voz, startMusic, stopMusic, unlock, button, setTrack };
})();
