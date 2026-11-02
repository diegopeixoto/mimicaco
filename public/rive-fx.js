// Reações animadas (Rive) por cima da tela do celular: Rawzinho ou Toninho
// comemorando, ficando triste ou mostrando a carta.
// Uso: RiveFx.preload('rawzinho'); RiveFx.play('acertou', 'rawzinho') -> Promise<boolean>
// Devolve false se o Rive não carregar (aí quem chamou mostra o aviso antigo).
(() => {
  const DUR = { acertou: 2000, errou: 2000, carta: 2350, cocegas: 1100 };
  const SM = 'Reacoes';
  let runtime = null, hideTimer = null, off = false;
  const chars = {}; // nome -> Promise<{ r, inputs, canvas }>
  try { off = new URLSearchParams(location.search).get('rive') === '0'; } catch {}

  const css = `
  #riveFx { position: fixed; inset: 0; z-index: 45; pointer-events: none; opacity: 0; transition: opacity .2s; display: grid; place-items: end center; }
  #riveFx.show { opacity: 1; }
  #riveFx::before { content: ''; position: absolute; inset: 0; background: radial-gradient(circle at 50% 55%, rgba(18,58,122,.25), rgba(18,58,122,.75)); }
  #riveFx canvas { grid-area: 1 / 1; position: relative; width: min(100vw, 520px); height: min(100dvh, 666px); max-height: 100dvh; visibility: hidden; }
  #riveFx canvas.on { visibility: visible; }`;

  function el() {
    let d = document.getElementById('riveFx');
    if (d) return d;
    const st = document.createElement('style'); st.textContent = css; document.head.appendChild(st);
    d = document.createElement('div'); d.id = 'riveFx';
    document.body.appendChild(d);
    return d;
  }

  function loadRuntime() {
    if (runtime) return runtime;
    runtime = new Promise((ok, fail) => {
      if (window.rive) return ok(window.rive);
      const s = document.createElement('script');
      s.src = 'vendor/rive/rive.js';
      s.onload = () => {
        window.rive.RuntimeLoader.setWasmUrl('vendor/rive/rive.wasm');
        window.rive.Rive.suppressDeprecationWarnings = ['state-machines-param', 'state-machine-inputs'];
        ok(window.rive);
      };
      s.onerror = () => { runtime = null; fail(new Error('rive.js não carregou')); };
      document.head.appendChild(s);
    });
    return runtime;
  }

  // carrega o personagem uma vez e deixa pronto (cada um tem o seu canvas)
  function preload(who = 'rawzinho') {
    if (off) return Promise.reject(new Error('rive desligado'));
    if (chars[who]) return chars[who];
    chars[who] = loadRuntime().then((rive) => new Promise((ok, fail) => {
      const canvas = document.createElement('canvas');
      canvas.width = 500; canvas.height = 640;
      el().appendChild(canvas);
      const r = new rive.Rive({
        src: `rive/${who}.riv`, canvas, autoplay: false, stateMachines: SM,
        layout: new rive.Layout({ fit: rive.Fit.Contain, alignment: rive.Alignment.BottomCenter }),
        onLoad: () => {
          const inputs = {};
          for (const i of r.stateMachineInputs(SM)) inputs[i.name] = i;
          ok({ r, inputs, canvas });
        },
        onLoadError: (e) => { canvas.remove(); fail(e); },
      });
    }));
    chars[who].catch(() => { delete chars[who]; });
    return chars[who];
  }

  async function play(trigger, who = 'rawzinho') {
    try {
      const { r, inputs, canvas } = await Promise.race([preload(who), new Promise((_, no) => setTimeout(() => no(new Error('demorou')), 4000))]);
      if (!inputs[trigger]) return false;
      const d = el();
      d.querySelectorAll('canvas').forEach((c) => c.classList.toggle('on', c === canvas));
      d.classList.add('show');
      r.resizeDrawingSurfaceToCanvas();
      r.play(SM);
      inputs[trigger].fire();
      clearTimeout(hideTimer);
      hideTimer = setTimeout(() => {
        d.classList.remove('show');
        setTimeout(() => { if (!d.classList.contains('show')) r.pause(SM); }, 250);
      }, DUR[trigger] || 2000);
      return true;
    } catch (e) {
      return false;
    }
  }

  window.RiveFx = { preload, play };
})();
