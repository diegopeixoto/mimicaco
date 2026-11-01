# Mimicaço

Jogo de mímica em equipes. Uma tela principal (TV, notebook ou celular) mostra o tabuleiro; cada jogador usa o próprio celular.

## Rodar no computador
    npm install
    npm start
Abra http://localhost:3000, clique em "Criar sala nova" na tela principal e leia o QR code com os celulares
(na mesma rede, use o IP do computador no lugar de localhost).

## Publicar (Render, Railway, Fly.io)
Serviço web Node.js: build `npm install`, start `npm start`. A porta vem da variável PORT.

## Como jogar
- Cada equipe anda pelo tabuleiro; a cor da casa define a categoria da carta.
- O mímico da vez (rodízio dentro da equipe) puxa a carta no celular. Só ele vê a palavra; as outras equipes também veem, para conferir.
- Acertou: rola o dado e anda. Errou: passa a vez.
- Casa ⚡ "Todos jogam": qualquer equipe pode adivinhar; quem acertar anda.
- Para vencer, é preciso chegar na casa do troféu e acertar a carta dela.
- Às vezes a carta vem com uma regra extra (ex.: "só com uma mão").

Cartas e categorias ficam em `cards.js`. As artes 3D em `public/img` foram geradas com Higgsfield.
