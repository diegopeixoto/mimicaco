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
const Som = (() => {
  const cache = {};
  let on = true, music = null, unlocked = false, voiceBusy = null;
  try { on = localStorage.getItem('mimica_som') !== 'off'; } catch {}
  function get(name) {
    if (!cache[name]) { cache[name] = new Audio(`som/${name}.mp3`); cache[name].preload = 'auto'; }
    return cache[name];
  }
  function play(name, vol = 0.8) {
    if (!on) return;
    try { const a = get(name).cloneNode(); a.volume = vol; a.play().catch(() => {}); return a; } catch {}
  }
  // falas do Rawzinho: abaixa a música enquanto ele fala, uma fala por vez
  function voz(name, delay = 0) {
    if (!on) return;
    setTimeout(() => {
      if (voiceBusy) { try { voiceBusy.pause(); } catch {} }
      const a = play('voz_' + name, 1);
      if (!a) return;
      voiceBusy = a;
      if (music) music.volume = 0.12;
      a.onended = () => { if (voiceBusy === a) { voiceBusy = null; if (music) music.volume = 0.35; } };
    }, delay);
  }
  function startMusic() {
    if (!on || music) return;
    music = new Audio('som/musica.mp3');
    music.loop = true; music.volume = 0.35;
    music.play().catch(() => { music = null; });
  }
  function stopMusic() { if (music) { music.pause(); music = null; } }
  function toggle() {
    on = !on;
    try { localStorage.setItem('mimica_som', on ? 'on' : 'off'); } catch {}
    if (!on) stopMusic();
    return on;
  }
  // navegadores só tocam som depois de um toque na tela
  function unlock(withMusic, cb) {
    const go = () => {
      if (unlocked) return; unlocked = true;
      if (withMusic) startMusic();
      cb && cb();
    };
    ['pointerdown', 'keydown'].forEach((ev) => addEventListener(ev, go, { once: true }));
  }
  function button(withMusic) {
    const b = document.createElement('button');
    b.className = 'sound-toggle ghost';
    const draw = () => (b.textContent = on ? '🔊' : '🔇');
    draw();
    b.onclick = (e) => { e.stopPropagation(); toggle(); if (on && withMusic) startMusic(); draw(); };
    document.body.appendChild(b);
  }
  return { play, voz, startMusic, stopMusic, toggle, unlock, button, get on() { return on; } };
})();
