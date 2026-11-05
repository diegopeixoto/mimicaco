# Mimicaço da Turma do Rawzinho (Godot)

Versão em Godot 4.7 do Mimicaço para Steam, tablets e lojas de apps (MIM-0019).
Um projeto só exporta para Windows, Linux/Steam Deck, macOS, Android e iOS/iPadOS.

## Abrir e jogar
1. Instale o Godot 4.7.2 (versão padrão, não a .NET).
2. No Godot: Importar > escolha `project.godot` desta pasta.
3. A primeira abertura importa os modelos, sons e imagens (1 a 2 minutos).
4. F5 roda o jogo.

## Dois jeitos de jogar
- **Jogar aqui (passa-e-joga):** tudo no mesmo aparelho. As equipes têm nomes e idades,
  o jogo chama o mímico da vez ("Passe o aparelho para Ana") e só ele vê a carta.
- **Com celulares:** o app vira a tela principal de uma sala no servidor web
  (`https://mimicaco.onrender.com`, muda em Opções). Os celulares entram pelo QR e jogam
  pelo `jogar.html` de sempre. O plano gratuito do Render leva até 1 minuto para acordar.

As regras são as mesmas do `server.js` (porte em `scripts/game/sala_local.gd`): dado e dado
de categoria, Todos jogam (+3), Pulo do Rawzinho (+2), repescagem (+2), troca de carta,
regras extras, vitória acertando a carta da casa final, nível sugerido pela média de idade.

## Pastas
| Pasta | O que tem |
| --- | --- |
| `scripts/game` | regras (`sala_local.gd`) e conexão com o servidor (`sala_online.gd`) |
| `scripts/board` | tabuleiro 3D (`tabuleiro3d.gd`) e geometria feita por código (`malhas.gd`) |
| `scripts/ui` | telas e janelas, todas montadas por código |
| `scripts/autoload` | cartas, som, opções salvas e tema visual |
| `assets` | artes, modelos, sons e fontes vindos de `public/` |
| `data/cartas.json` | cartas geradas do `cards.js` |
| `tools` | testes e utilitários (não vão para os exports) |

## Diferenças dos assets em relação ao `public/`
- Vídeos de fundo convertidos de MP4 para OGV (o Godot só toca Theora).
- Modelos de cenário com a extensão `EXT_mesh_gpu_instancing` "assados" por
  `tools/expandir_instancias.py` (o Godot ainda não importa essa extensão).
- As reações em Rive viraram poses (`assets/poses/*.webp`) com animação por código.

## Atualizar as cartas
Edite `cards.js` na raiz do repositório e rode `bash tools/atualizar_cartas.sh`.

## Testes
- Regras, 30 partidas simuladas: `godot --headless --path . -s res://tools/teste_regras.gd`
- Partida automática com prints: `godot --path . -- --roteiro --saida=/tmp/prints`
  (`--so=dado` só a rolagem; `--so=online --servidor=http://localhost:3000` o modo com celulares).

## Exportar (Projeto > Exportar)
Presets prontos em `export_presets.cfg`. Instale os templates de exportação 4.7.2 antes.
| Preset | Para | Falta configurar |
| --- | --- | --- |
| Windows (Steam) | Steam no PC | ícone no .exe precisa do rcedit (Editor > Configurações > Exportar > Windows) |
| Linux (Steam Deck) | Steam no Linux e Steam Deck | nada |
| macOS | Steam no Mac | assinatura e notarização da Apple |
| Android (tablet e celular) | Google Play (.aab) | keystore de release e SDK Android |
| iOS e iPadOS | App Store | Mac com Xcode e Team ID da Apple |

## Próximos passos para a Steam
- App ID e página na Steamworks; arte da loja (geramos a arte-chave no Higgsfield).
- GodotSteam (GDExtension) para conquistas e o overlay da Steam.
- Tradução para inglês e espanhol: hoje telas e cartas estão em português.
- Remote Play Together já funciona no modo passa-e-joga, porque só a tela é transmitida.
