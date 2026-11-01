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
