// Tela de "carregando" com o Rawzinho (Rive) e progresso de verdade:
// a barra anda conforme os bytes das vozes, da música e do Rive chegam.
// Uso:
//   const load = Carregando.abrir({ quem: 'rawzinho', comecar: true });
//   load.baixar('som/musica.mp3')   -> Promise<Blob> (conta na barra)
//   load.esperar(promessa, peso)    -> conta na barra quando a promessa termina
//   load.pronto()                   -> fecha quando tudo que foi pedido terminou
//                                      (com comecar: mostra "Toque para começar")
// Carregando.baixar(url) baixa sem tela nenhuma (pré-carga em segundo plano).
(() => {
  const FRASES = [
    'Afinando a voz do Rawzinho…',
    'Toninho está trazendo as cartas…',
    'Aquecendo a música…',
    'Embaralhando as mímicas…',
    'Arrumando o tabuleiro…',
  ];

  const css = `
  #carregando { position: fixed; inset: 0; z-index: 80; display: grid; place-items: center; padding: 16px;
    background: radial-gradient(circle at 50% 40%, rgba(29,79,163,.92), rgba(18,58,122,.97)); transition: opacity .35s; }
  #carregando.saindo { opacity: 0; pointer-events: none; }
  #carregando .box { width: min(420px, 100%); text-align: center; display: grid; justify-items: center; gap: 6px; }
  #carregando .logo { width: min(220px, 55vw); filter: drop-shadow(0 4px 0 rgba(0,0,0,.2)); }
  #carregando .palco { position: relative; width: min(300px, 70vw, 38vh); aspect-ratio: 500 / 640; display: grid; place-items: end center; }
  #carregando canvas { width: 100%; height: 100%; opacity: 0; transition: opacity .3s; cursor: pointer; touch-action: manipulation; }
  #carregando canvas.on { opacity: 1; }
  #carregando .dino { position: absolute; bottom: 12%; font-size: min(120px, 14vh); animation: car-pula .7s ease-in-out infinite alternate; }
  #carregando canvas.on + .dino { display: none; }
  @keyframes car-pula { from { transform: translateY(0) scaleY(.95); } to { transform: translateY(-18%) scaleY(1.03); } }
  #carregando .frase { font-weight: 800; color: var(--muted, #cfe3ff); min-height: 1.6em; }
  #carregando .trilho { position: relative; width: 100%; height: 22px; border-radius: 99px; background: rgba(0,0,0,.28); border: 3px solid rgba(255,255,255,.35); overflow: hidden; }
  #carregando .enche { position: absolute; inset: 0 auto 0 0; width: 0; border-radius: 99px; transition: width .25s;
    background: repeating-linear-gradient(-45deg, var(--accent, #ffd23d) 0 14px, #ffe27a 14px 28px); background-size: 40px 100%; animation: car-listra 1s linear infinite; }
  @keyframes car-listra { to { background-position: 40px 0; } }
  #carregando .pct { font-family: 'Lilita One', sans-serif; font-size: 1.5rem; color: #fff; text-shadow: 0 3px 0 #123a7a; }
  #carregando .comecar { font-size: 1.4rem; padding: .6em 1.6em; animation: pulse .9s infinite; }
  #carregando .pular { background: none; box-shadow: none; color: var(--muted, #cfe3ff); text-decoration: underline; font-size: .95rem; padding: .3em; opacity: 0; transition: opacity .3s; }
  #carregando .pular.on { opacity: 1; }
  @keyframes pulse { 50% { transform: scale(1.06); } }`;

  // fetch que avisa quantos bytes já chegaram
  async function baixar(url, aviso) {
    const res = await fetch(url);
    if (!res.ok) throw new Error(url + ': ' + res.status);
    const total = +res.headers.get('content-length') || 0;
    const type = res.headers.get('content-type') || '';
    if (aviso) aviso(0, total);
    if (!res.body || !res.body.getReader) {
      const b = await res.blob();
      if (aviso) aviso(b.size, total || b.size);
      return b;
    }
    const reader = res.body.getReader(), partes = [];
    let got = 0;
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      partes.push(value); got += value.length;
      if (aviso) aviso(got, total);
    }
    if (aviso) aviso(got, got);
    return new Blob(partes, { type });
  }

  function abrir({ quem = 'rawzinho', comecar = false, aoFechar } = {}) {
    const st = document.createElement('style'); st.textContent = css; document.head.appendChild(st);
    const d = document.createElement('div'); d.id = 'carregando';
    d.innerHTML = `<div class="box">
      <img class="logo" src="img/logo.png" alt="Turma do Rawzinho">
      <div class="palco"><canvas width="500" height="640"></canvas><div class="dino">🦖</div></div>
      <div class="frase">${FRASES[0]}</div>
      <div class="trilho" role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="0"><div class="enche"></div></div>
      <div class="pct">0%</div>
      <button class="pular" type="button">Pular</button></div>`;
    document.body.appendChild(d);
    const $ = (s) => d.querySelector(s);
    const canvas = $('canvas'), enche = $('.enche'), pct = $('.pct'), frase = $('.frase'), trilho = $('.trilho');

    const itens = []; // { got, total }
    const promessas = [];
    let mostrado = 0, fechado = false, r = null, inputs = {};
    function desenha() {
      let got = 0, total = 0;
      for (const i of itens) { total += i.total; got += Math.min(i.got, i.total); }
      const p = total ? Math.floor((got / total) * 100) : 0;
      if (p <= mostrado) return; // a barra nunca anda para trás (quando chega um item novo)
      mostrado = p;
      enche.style.width = p + '%';
      pct.textContent = p + '%';
      trilho.setAttribute('aria-valuenow', p);
    }
    function item(estimado) {
      const it = { got: 0, total: estimado }; itens.push(it); return it;
    }
    function baixarComBarra(url, estimado = 60000) {
      const it = item(estimado);
      const p = baixar(url, (got, total) => { it.got = got; if (total) it.total = total; desenha(); })
        .finally(() => { it.got = it.total; desenha(); });
      promessas.push(p);
      return p;
    }
    function esperar(promessa, peso = 100000) {
      const it = item(peso);
      const p = Promise.resolve(promessa).finally(() => { it.got = it.total; desenha(); });
      promessas.push(p);
      return p;
    }

    // frases trocando enquanto carrega
    let fi = 0;
    const trocaFrase = setInterval(() => { frase.textContent = FRASES[++fi % FRASES.length]; }, 1800);
    // cócegas a cada pouco e quando tocam nele
    const cocegas = setInterval(() => inputs.cocegas?.fire(), 2600);
    canvas.addEventListener('pointerdown', () => inputs.cocegas?.fire());

    // o próprio Rawzinho em Rive (o .riv conta na barra e fica guardado para as reações do jogo)
    let rivePronto = Promise.resolve();
    if (window.RiveFx && !RiveFx.desligado) {
      const riv = baixarComBarra(`rive/${quem}.riv`, 340000).then((b) => b.arrayBuffer());
      // baixa o runtime pela barra; depois o navegador pega do cache (vendor/ fica guardado 1 dia)
      const pre = window.rive ? Promise.resolve() : Promise.all([
        baixarComBarra('vendor/rive/rive.js', 530000), baixarComBarra('vendor/rive/rive.wasm', 830000)]);
      rivePronto = pre.then(() => RiveFx.runtime()).then((rive) => riv.then((buf) => new Promise((ok) => {
        RiveFx.guardar(quem, buf);
        if (fechado) return ok();
        r = new rive.Rive({
          buffer: buf.slice(0), canvas, autoplay: true, stateMachines: 'Reacoes',
          layout: new rive.Layout({ fit: rive.Fit.Contain, alignment: rive.Alignment.BottomCenter }),
          onLoad: () => {
            r.resizeDrawingSurfaceToCanvas();
            for (const i of r.stateMachineInputs('Reacoes')) inputs[i.name] = i;
            canvas.classList.add('on');
            ok();
          },
          onLoadError: () => ok(),
        });
      }))).catch(() => {});
    }

    const pular = $('.pular');
    setTimeout(() => pular.classList.add('on'), 5000);
    let fecharJa;
    const pulou = new Promise((ok) => (fecharJa = ok));
    pular.onclick = () => fecharJa();

    function fechar() {
      if (fechado) return; fechado = true;
      clearInterval(trocaFrase); clearInterval(cocegas);
      d.classList.add('saindo');
      setTimeout(() => { try { r?.cleanup(); } catch {} d.remove(); st.remove(); }, 400);
      aoFechar && aoFechar();
    }

    // espera tudo que foi pedido até aqui (o que der erro não trava: o jogo busca de novo na hora)
    function pronto() {
      const tudo = Promise.allSettled(promessas.slice()).then(() => rivePronto);
      Promise.race([tudo.then(() => 'ok'), pulou.then(() => 'pulou')]).then((como) => {
        if (fechado) return;
        if (como === 'pulou' || !comecar) return fechar();
        enche.style.width = '100%'; pct.textContent = '100%';
        clearInterval(trocaFrase);
        frase.textContent = 'Tudo pronto!';
        inputs.acertou?.fire();
        pular.remove();
        const b = document.createElement('button');
        b.className = 'big comecar'; b.type = 'button'; b.textContent = 'Toque para começar';
        pct.replaceWith(b);
        b.onclick = fechar;
      });
      return tudo;
    }

    return { baixar: baixarComBarra, esperar, pronto, fechar };
  }

  window.Carregando = { abrir, baixar: (url) => baixar(url) };
})();
