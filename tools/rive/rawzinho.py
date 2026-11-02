"""Gera public/rive/rawzinho.riv: Rawzinho 2D com reações para o celular.

Uso: python3 tools/rive/rawzinho.py tools/rive/src
Imagens: raw_cabeca.webp, raw_corpo.webp, tit_acertou.webp, tit_errou.webp, tit_carta.webp
Gatilhos da máquina de estados "Reacoes": acertou, errou, carta, cocegas.
"""
import math, os, random, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
from riv import Riv

src = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), '../../public/rive/rawzinho.riv')
random.seed(7)

r = Riv()
assets = {}
for n in ['raw_cabeca', 'raw_corpo', 'tit_acertou', 'tit_errou', 'tit_carta']:
    f = os.path.join(src, n + '.webp')
    w, h = Image.open(f).size
    assets[n] = (r.image_asset(n, open(f, 'rb').read(), w, h), w, h)

W, H = 500, 640
r.artboard('Rawzinho', W, H)
NAVY, YEL, PUR, RED, WHITE = 0xff123a7a, 0xffffd23d, 0xff6b3fd1, 0xffff5a5f, 0xffffffff
CONF = [0xffffd23d, 0xffff5a5f, 0xff4cc94a, 0xff3fa9f5, 0xffff8fd1, 0xff6b3fd1]

# Ordem de desenho: o primeiro filho fica por cima, então montamos de cima para baixo.
top = r.node(0, 'topo', x=0, y=0)

# título (cada um num nó próprio, escondido)
tits = {}
for k in ['acertou', 'errou', 'carta']:
    a, w, h = assets['tit_' + k]
    n = r.node(top, 'titulo_' + k, x=W / 2, y=86, scaleX=0, scaleY=0, opacity=0)
    r.image(n, a, scaleX=0.78, scaleY=0.78)
    tits[k] = n

# estrelas do "acertou" (estouram do centro)
stars = []
for i in range(10):
    n = r.node(top, 'estrela%d' % i, x=W / 2, y=330, opacity=0, scaleX=0, scaleY=0)
    r.star(n, 64 + (i % 3) * 18, CONF[i % len(CONF)] if i % 2 else YEL, points=5, inner=0.45, stroke=(WHITE, 4))
    stars.append(n)

# confete caindo
confs = []
for i in range(18):
    n = r.node(top, 'confete%d' % i, x=random.uniform(30, W - 30), y=-30, opacity=0)
    r.rect(n, 14, 22, CONF[i % len(CONF)], radius=3)
    confs.append(n)

# gota de suor do "errou"
gota = r.node(top, 'gota', x=W / 2 + 130, y=170, opacity=0)
r.ellipse(gota, 22, 30, 0xff8fd3ff, stroke=(WHITE, 3))

# carta (verso roxo com estrela / frente branca com interrogação de estrelas)
carta = r.node(top, 'carta', x=W / 2, y=H + 200, rotation=-0.2)
carta_flip = r.node(carta, 'carta_flip')
frente = r.node(carta_flip, 'frente', opacity=0)
r.star(frente, 70, YEL, points=5, inner=0.45, stroke=(NAVY, 5), y=-40)
r.ellipse(frente, 26, 26, PUR, y=70)
r.rect(frente, 26, 46, PUR, radius=13, y=28)
r.rect(frente, 190, 250, WHITE, radius=22, stroke=(PUR, 8))
verso = r.node(carta_flip, 'verso')
r.star(verso, 110, YEL, points=5, inner=0.45, stroke=(WHITE, 6))
r.rect(verso, 190, 250, PUR, radius=22, stroke=(WHITE, 8))

# Rawzinho: raiz nos pés, cabeça num pivô no pescoço
SC = 0.66
raw = r.node(top, 'rawzinho', x=W / 2, y=H - 34, scaleX=SC, scaleY=SC)
pesc = r.node(raw, 'pescoco', x=18, y=-344)
cab = r.image(pesc, assets['raw_cabeca'][0], name='cabeca', x=3, y=-182.5)
corpo = r.image(raw, assets['raw_corpo'][0], name='corpo', x=0, y=-177.6)

# sombra (por último = embaixo de tudo)
sombra = r.ellipse(top, 260, 40, 0x40000000, name='sombra', x=W / 2, y=H - 34)

# curvas
r.ease('io', 0.42, 0, 0.58, 1)
r.ease('out', 0.2, 0.9, 0.3, 1)
r.ease('in', 0.6, 0, 0.9, 0.4)
r.ease('pop', 0.3, 1.7, 0.5, 1)     # passa do ponto e volta (efeito mola)

anims = {}
GROUND = H - 34

# ---------- idle (respira, cabeça balança)
anims['idle'] = r.animation('parado', 120, loop=True)
r.keys(raw, 'scaleY', [(0, SC), (60, SC * 1.025), (120, SC)])
r.keys(raw, 'scaleX', [(0, SC), (60, SC * 0.99), (120, SC)])
r.keys(pesc, 'rotation', [(0, -0.05), (60, 0.05), (120, -0.05)])
r.keys(pesc, 'y', [(0, -344), (60, -350), (120, -344)])

# ---------- acertou: agacha, pula, estrelas, confete, título
anims['acertou'] = r.animation('acertou', 110)
r.keys(raw, 'y', [(0, GROUND), (8, GROUND + 6, 'out'), (30, GROUND - 100, 'in'), (48, GROUND, 'lin'), (56, GROUND + 6, 'out'), (66, GROUND)])
r.keys(raw, 'scaleY', [(0, SC), (8, SC * 0.82, 'out'), (18, SC * 1.12), (44, SC * 1.0, 'lin'), (50, SC * 0.86, 'out'), (64, SC, 'pop')])
r.keys(raw, 'scaleX', [(0, SC), (8, SC * 1.14, 'out'), (18, SC * 0.9), (44, SC, 'lin'), (50, SC * 1.12, 'out'), (64, SC, 'pop')])
r.keys(raw, 'rotation', [(0, 0), (20, -0.12), (32, 0.12), (44, 0), (110, 0)])
r.keys(pesc, 'rotation', [(0, 0), (14, -0.22), (50, -0.22), (70, 0.08), (84, 0)])
r.keys(sombra, 'scaleX', [(0, 1), (30, 0.55, 'in'), (48, 1, 'lin')])
r.keys(sombra, 'scaleY', [(0, 1), (30, 0.55, 'in'), (48, 1, 'lin')])
for i, s in enumerate(stars):
    ang = -math.pi / 2 + (i - 4.5) * 0.33 + random.uniform(-0.1, 0.1)
    dist = random.uniform(170, 240)
    t0 = 14 + i % 3 * 3
    r.keys(s, 'x', [(t0, W / 2), (t0 + 34, W / 2 + math.cos(ang) * dist * 1.25, 'out')])
    r.keys(s, 'y', [(t0, 330), (t0 + 34, 330 + math.sin(ang) * dist, 'out')])
    r.keys(s, 'scaleX', [(t0, 0), (t0 + 12, 1.1, 'pop'), (t0 + 64, 0.6)])
    r.keys(s, 'scaleY', [(t0, 0), (t0 + 12, 1.1, 'pop'), (t0 + 64, 0.6)])
    r.keys(s, 'rotation', [(t0, 0), (t0 + 50, random.choice([-1, 1]) * 3.5, 'out')])
    r.keys(s, 'opacity', [(0, 0, 'hold'), (t0, 1), (t0 + 44, 1), (t0 + 64, 0)])
for i, c in enumerate(confs):
    t0 = 10 + random.randint(0, 22)
    x0 = random.uniform(30, W - 30)
    r.keys(c, 'x', [(0, x0, 'hold'), (t0, x0), (t0 + 70, x0 + random.uniform(-60, 60), 'lin')])
    r.keys(c, 'y', [(t0, -30), (t0 + 70, H + 30, 'lin')])
    r.keys(c, 'rotation', [(t0, 0), (t0 + 70, random.uniform(-9, 9), 'lin')])
    r.keys(c, 'opacity', [(0, 0, 'hold'), (t0, 1, 'hold'), (t0 + 70, 0, 'hold')])
t = tits['acertou']
r.keys(t, 'scaleX', [(16, 0), (30, 1, 'pop'), (88, 1), (108, 0.6)])
r.keys(t, 'scaleY', [(16, 0), (30, 1, 'pop'), (88, 1), (108, 0.6)])
r.keys(t, 'rotation', [(16, -0.3), (30, 0.04, 'pop'), (60, -0.04), (88, 0.03)])
r.keys(t, 'opacity', [(0, 0, 'hold'), (16, 1, 'hold'), (92, 1), (108, 0)])

# ---------- errou: cabeça faz "não", corpo murcha, gota, título
anims['errou'] = r.animation('errou', 100)
r.keys(pesc, 'rotation', [(0, 0), (8, -0.2), (16, 0.2), (24, -0.17), (32, 0.13), (40, -0.06), (48, 0.12), (90, 0.12), (100, 0)])
r.keys(pesc, 'y', [(0, -344), (40, -330), (90, -330), (100, -344)])
r.keys(raw, 'scaleY', [(0, SC), (14, SC * 0.92), (90, SC * 0.93), (100, SC)])
r.keys(raw, 'scaleX', [(0, SC), (14, SC * 1.04), (90, SC * 1.03), (100, SC)])
r.keys(gota, 'opacity', [(0, 0, 'hold'), (30, 1), (80, 1), (95, 0)])
r.keys(gota, 'y', [(30, 170), (95, 250, 'in')])
r.keys(gota, 'scaleY', [(30, 0.3), (40, 1.1, 'pop'), (95, 1)])
t = tits['errou']
r.keys(t, 'scaleX', [(10, 0), (24, 0.85, 'pop'), (84, 0.85), (100, 0.5)])
r.keys(t, 'scaleY', [(10, 0), (24, 0.85, 'pop'), (84, 0.85), (100, 0.5)])
r.keys(t, 'y', [(10, 86), (84, 100), (100, 120)])
r.keys(t, 'opacity', [(0, 0, 'hold'), (10, 1, 'hold'), (86, 1), (100, 0)])

# ---------- carta: carta voa, gira e vira; Rawzinho se assusta de alegria
anims['carta'] = r.animation('carta', 130)
r.keys(carta, 'y', [(0, H + 200), (26, 250, 'out'), (100, 250), (126, -220, 'in')])
r.keys(carta, 'x', [(0, W / 2 + 120), (26, W / 2, 'out'), (100, W / 2), (126, W / 2 - 60, 'in')])
r.keys(carta, 'rotation', [(0, 0.6), (26, -0.08, 'pop'), (60, 0.04), (100, 0), (126, -0.5, 'in')])
r.keys(carta, 'scaleX', [(0, 0.5), (26, 1.05, 'pop'), (100, 1.05)])
r.keys(carta, 'scaleY', [(0, 0.5), (26, 1.05, 'pop'), (100, 1.05)])
r.keys(carta_flip, 'scaleX', [(0, 1), (34, 1), (44, 0, 'in'), (54, 1, 'out')])
r.keys(verso, 'opacity', [(0, 1, 'hold'), (44, 0, 'hold')])
r.keys(frente, 'opacity', [(0, 0, 'hold'), (44, 1, 'hold')])
r.keys(raw, 'y', [(30, GROUND), (40, GROUND - 40, 'out'), (52, GROUND, 'in'), (130, GROUND)])
r.keys(pesc, 'rotation', [(0, 0), (30, -0.25, 'out'), (100, -0.2), (120, 0)])
t = tits['carta']
r.keys(t, 'scaleX', [(40, 0), (54, 0.9, 'pop'), (104, 0.9), (122, 0.4)])
r.keys(t, 'scaleY', [(40, 0), (54, 0.9, 'pop'), (104, 0.9), (122, 0.4)])
r.keys(t, 'opacity', [(0, 0, 'hold'), (40, 1, 'hold'), (106, 1), (122, 0)])

# ---------- cócegas (toque no Rawzinho)
anims['cocegas'] = r.animation('cocegas', 48)
r.keys(raw, 'rotation', [(0, 0), (6, 0.1), (12, -0.1), (18, 0.08), (24, -0.06), (32, 0.03), (40, 0)])
r.keys(raw, 'scaleY', [(0, SC), (6, SC * 0.9, 'out'), (16, SC * 1.06), (28, SC * 0.97), (40, SC)])
r.keys(raw, 'scaleX', [(0, SC), (6, SC * 1.08, 'out'), (16, SC * 0.96), (28, SC * 1.02), (40, SC)])
r.keys(pesc, 'rotation', [(0, 0), (10, 0.2), (22, -0.15), (34, 0.08), (46, 0)])

trig = ['acertou', 'errou', 'carta', 'cocegas']
r.state_machine('Reacoes', trig, anims['idle'], {k: anims[k] for k in trig})
os.makedirs(os.path.dirname(out), exist_ok=True)
data = r.bytes()
open(out, 'wb').write(data)
print(out, len(data), 'bytes')
