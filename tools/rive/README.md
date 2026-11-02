# Rive no Mimicaço (experimento)

- `public/rive-lab.html`: página de teste no celular (abre em `/rive-lab.html`).
- `public/rive/rawzinho.riv` e `toninho.riv`: personagens 2D com a máquina de estados `Reacoes`
  e os gatilhos `acertou`, `errou`, `carta` e `cocegas`.
- `public/vendor/rive/`: runtime `@rive-app/canvas-lite` 2.49.0 (MIT), servido localmente.

O `.riv` é gerado por código, sem o editor do Rive:

```
python3 tools/rive/personagem.py todos
```

`riv.py` escreve o formato binário do runtime (chaves tiradas de
`include/rive/generated` do repositório aberto rive-app/rive-runtime).
Só cobre o básico: imagens, formas (retângulo, elipse, estrela),
animações de posição/escala/rotação/opacidade e gatilhos.
Ossos, malhas e deformação do personagem precisam do editor do Rive.

Para usar no jogo: `inputs.acertou.fire()` quando chegar o resultado, etc.
