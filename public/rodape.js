// Créditos, copyright e links legais, iguais em todas as telas.
// <footer id="rodape"></footer> recebe o rodapé completo; <footer id="rodape" data-mini> recebe a versão discreta (tela principal).
// Botão de destaque do canal: qualquer elemento com data-canal-yt="Texto" vira o botão; no JS, use canalYT('Texto').
(() => {
  const ANO = new Date().getFullYear();
  const CANAL = 'https://www.youtube.com/@TurmadoRawzinho';
  const PLAY = '<svg viewBox="0 0 28 20" aria-hidden="true"><rect width="28" height="20" rx="5" fill="#ff0033"/><path d="M11 5.5v9l8-4.5z" fill="#fff"/></svg>';
  window.canalYT = (texto = 'Assista à Turma do Rawzinho no YouTube') =>
    `<a class="canal-yt" href="${CANAL}" target="_blank" rel="noopener"><span class="canal-yt-play">${PLAY}</span>` +
    `<span class="canal-yt-txt"><b>${texto}</b><small>youtube.com/@TurmadoRawzinho</small></span></a>`;
  const html = (mini) => `
    <div class="rodape-linha">
      <span>© ${ANO} Aquarela. Todos os direitos reservados.</span>
      ${mini ? '' : '<span>Turma do Rawzinho, Rawzinho e Toninho são marcas da Aquarela Productions.</span>'}
    </div>
    <div class="rodape-linha">
      <a class="rodape-dev" href="https://aquarela.io" target="_blank" rel="noopener">Desenvolvido por <img src="img/aquarela.svg" alt="aquarela.io"></a>
      <a href="termos.html">Termos de uso</a>
      <a href="privacidade.html">Privacidade</a>
      <a class="rodape-yt" href="${CANAL}" target="_blank" rel="noopener">${PLAY}${mini ? 'YouTube' : 'Turma do Rawzinho no YouTube'}</a>
    </div>`;
  const css = `
    #rodape { font-size: .85rem; color: #fff; text-align: center; padding: 18px 12px 22px; text-shadow: 0 1px 3px rgba(0,0,0,.7); }
    #rodape .rodape-linha { display: flex; flex-wrap: wrap; justify-content: center; align-items: center; gap: 4px 14px; margin: 4px 0; }
    #rodape a { color: #fff; font-weight: 700; text-decoration: underline; text-underline-offset: 3px; }
    #rodape .rodape-dev { display: inline-flex; align-items: center; gap: 6px; text-decoration: none; }
    #rodape .rodape-yt { display: inline-flex; align-items: center; gap: 6px; }
    #rodape .rodape-yt svg { height: 14px; width: auto; filter: drop-shadow(0 1px 2px rgba(0,0,0,.5)); }
    #rodape .rodape-dev img { height: 14px; width: auto; filter: drop-shadow(0 1px 2px rgba(0,0,0,.6)); }
    #rodape[data-mini] { position: fixed; left: 66px; bottom: 8px; z-index: 5; padding: 4px 10px; font-size: .72rem; text-align: left;
      background: rgba(18,58,122,.55); border-radius: 10px; opacity: .85; }
    #rodape[data-mini] .rodape-linha { justify-content: flex-start; margin: 1px 0; gap: 2px 10px; }
    #rodape[data-mini] .rodape-dev img { height: 11px; }
    @media (min-width: 820px) and (orientation: landscape) {
      #rodape:not([data-mini]) { display: flex; flex-wrap: wrap; justify-content: center; gap: 0 14px; padding: 8px 12px 10px; font-size: .78rem; }
      #rodape:not([data-mini]) .rodape-linha { margin: 0; }
    }
    /* página inicial em TV/notebook: o rodapé fica no pé da tela para tudo caber sem rolar */
    @media (min-width: 820px) and (orientation: landscape) and (min-height: 700px) {
      #rodape[data-fixo] { position: fixed; left: 0; right: 0; bottom: 0; padding: 4px 12px 6px; }
    }
    .canal-yt { display: inline-flex; align-items: center; gap: 10px; padding: 8px 16px 8px 10px; border-radius: 16px;
      background: #ff0033; color: #fff !important; text-decoration: none !important; text-align: left; line-height: 1.1;
      box-shadow: 0 5px 0 #a3001f, 0 8px 18px rgba(0,0,0,.25); border: 3px solid #fff; pointer-events: auto;
      transition: transform .1s; animation: canal-yt-pulo 3.2s ease-in-out infinite; }
    .canal-yt:hover { transform: translateY(-2px) scale(1.03); }
    .canal-yt:active { transform: translateY(2px); }
    .canal-yt-play { display: grid; place-items: center; width: 40px; height: 40px; border-radius: 50%; background: #fff; flex: none; }
    .canal-yt-play svg { width: 24px; height: auto; }
    .canal-yt-txt b { display: block; font-family: 'Lilita One', 'Baloo 2', sans-serif; font-weight: 400; font-size: 1.05rem; letter-spacing: .01em; }
    .canal-yt-txt small { display: block; font-size: .78rem; font-weight: 700; opacity: .9; }
    @keyframes canal-yt-pulo { 0%, 86%, 100% { transform: none; } 90% { transform: translateY(-4px) rotate(-1.5deg); } 95% { transform: translateY(0) rotate(1deg); } }
    @media (prefers-reduced-motion: reduce) { .canal-yt { animation: none; } }`;
  const st = document.createElement('style');
  st.textContent = css;
  document.head.appendChild(st);
  function montar() {
    document.querySelectorAll('[data-canal-yt]').forEach((el) => (el.innerHTML = window.canalYT(el.dataset.canalYt || undefined)));
    const el = document.getElementById('rodape');
    if (el) el.innerHTML = html(el.hasAttribute('data-mini'));
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', montar);
  else montar();
})();
