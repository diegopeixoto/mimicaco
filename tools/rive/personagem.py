"""Gera public/rive/<personagem>.riv: personagem 2D com reações para o celular.

Uso: python3 tools/rive/personagem.py rawzinho|toninho|todos
As imagens ficam em tools/rive/src (poses geradas no Higgsfield, fundo removido).
Máquina de estados "Reacoes", gatilhos: acertou, errou, carta, cocegas.

Cada reação troca a pose do personagem no meio do movimento:
acertou -> feliz, errou -> triste, carta -> aponta, cocegas -> susto.
"""
import math, os, random, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
from riv import Riv

SRC = os.path.join(os.path.dirname(__file__), 'src')
OUT = os.path.join(os.path.dirname(__file__), '../../public/rive')

PERSONAGENS = {
    # parado: ('cabeca_corpo', ...) usa cabeça separada; ou o nome de uma imagem inteira
    'rawzinho': {'parado': 'cabeca_corpo', 'poses': {'feliz': 'raw_feliz', 'triste': 'raw_triste', 'aponta': 'raw_aponta', 'susto': 'raw_susto'}, 'escala': 0.62},
    'toninho': {'parado': 'ton_parado', 'poses': {'feliz': 'ton_feliz', 'triste': 'ton_triste', 'aponta': 'ton_feliz', 'susto': 'ton_susto'}, 'escala': 0.6},
}

NAVY, YEL, PUR, WHITE = 0xff123a7a, 0xffffd23d, 0xff6b3fd1, 0xffffffff
CONF = [0xffffd23d, 0xffff5a5f, 0xff4cc94a, 0xff3fa9f5, 0xffff8fd1, 0xff6b3fd1]
W, H = 500, 640
GROUND = H - 34


def gerar(nome):
    cfg = PERSONAGENS[nome]
    random.seed(7)
    r = Riv()
    assets = {}

    def asset(n):
        if n not in assets:
            f = os.path.join(SRC, n + '.webp')
            w, h = Image.open(f).size
            assets[n] = (r.image_asset(n, open(f, 'rb').read(), w, h), w, h)
        return assets[n]

    imgs = ['tit_acertou', 'tit_errou', 'tit_carta'] + sorted(set(cfg['poses'].values()))
    imgs += ['raw_cabeca', 'raw_corpo'] if cfg['parado'] == 'cabeca_corpo' else [cfg['parado']]
    for n in imgs:
        asset(n)

    r.artboard(nome.capitalize(), W, H)
    # Ordem de desenho: o primeiro filho fica por cima, então montamos de cima para baixo.
    top = r.node(0, 'topo')
    resets = []  # (nó, propriedade, valor de repouso): toda animação começa por eles

    tits = {}
    for k in ['acertou', 'errou', 'carta']:
        n = r.node(top, 'titulo_' + k, x=W / 2, y=86, scaleX=0, scaleY=0, opacity=0)
        r.image(n, asset('tit_' + k)[0], scaleX=0.78, scaleY=0.78)
        tits[k] = n
        resets += [(n, 'opacity', 0), (n, 'scaleX', 0), (n, 'scaleY', 0)]

    stars = []
    for i in range(10):
        n = r.node(top, 'estrela%d' % i, x=W / 2, y=330, opacity=0, scaleX=0, scaleY=0)
        r.star(n, 64 + (i % 3) * 18, CONF[i % len(CONF)] if i % 2 else YEL, points=5, inner=0.45, stroke=(WHITE, 4))
        stars.append(n)
        resets.append((n, 'opacity', 0))

    confs = []
    for i in range(18):
        n = r.node(top, 'confete%d' % i, x=random.uniform(30, W - 30), y=-30, opacity=0)
        r.rect(n, 14, 22, CONF[i % len(CONF)], radius=3)
        confs.append(n)
        resets.append((n, 'opacity', 0))

    gota = r.node(top, 'gota', x=W / 2 + 120, y=170, opacity=0)
    r.ellipse(gota, 22, 30, 0xff8fd3ff, stroke=(WHITE, 3))
    resets.append((gota, 'opacity', 0))

    # carta: aparece no alto à direita, para onde o personagem aponta
    CX, CY = W / 2 + 120, 215
    carta = r.node(top, 'carta', x=W + 200, y=H + 200, rotation=-0.2)
    carta_flip = r.node(carta, 'carta_flip')
    frente = r.node(carta_flip, 'frente', opacity=0)
    r.star(frente, 70, YEL, points=5, inner=0.45, stroke=(NAVY, 5), y=-40)
    r.ellipse(frente, 26, 26, PUR, y=70)
    r.rect(frente, 26, 46, PUR, radius=13, y=28)
    r.rect(frente, 190, 250, WHITE, radius=22, stroke=(PUR, 8))
    verso = r.node(carta_flip, 'verso')
    r.star(verso, 110, YEL, points=5, inner=0.45, stroke=(WHITE, 6))
    r.rect(verso, 190, 250, PUR, radius=22, stroke=(WHITE, 8))
    resets += [(carta, 'y', H + 200), (carta, 'x', W + 200)]

    # personagem: raiz nos pés
    SC = cfg['escala']
    raiz = r.node(top, nome, x=W / 2, y=GROUND, scaleX=SC, scaleY=SC)
    poses = {}
    for p, img in cfg['poses'].items():
        a, w, h = asset(img)
        n = r.node(raiz, 'pose_' + p, opacity=0)
        r.image(n, a, y=-h / 2)
        poses[p] = n
    parado = r.node(raiz, 'pose_parado')
    if cfg['parado'] == 'cabeca_corpo':
        pesc = r.node(parado, 'pescoco', x=18, y=-344)
        r.image(pesc, asset('raw_cabeca')[0], name='cabeca', x=3, y=-182.5)
        r.image(parado, asset('raw_corpo')[0], name='corpo', x=0, y=-177.6)
    else:
        a, w, h = asset(cfg['parado'])
        pesc = r.node(parado, 'balanco')
        r.image(pesc, a, y=-h / 2)
    todas = dict(poses, parado=parado)

    sombra = r.ellipse(top, 260, 40, 0x40000000, name='sombra', x=W / 2, y=GROUND)

    r.ease('io', 0.42, 0, 0.58, 1)
    r.ease('out', 0.2, 0.9, 0.3, 1)
    r.ease('in', 0.6, 0, 0.9, 0.4)
    r.ease('pop', 0.3, 1.7, 0.5, 1)

    def pose(seq):
        """seq: [(frame, nome_da_pose)] — troca instantânea de pose."""
        for p, n in todas.items():
            r.keys(n, 'opacity', [(f, 1 if q == p else 0, 'hold') for f, q in seq])

    def fim():
        for n, prop, v in resets:
            if not any(pp == prop for pp, _ in r._keys.get(n, [])):
                r.keys(n, prop, [(0, v, 'hold')])
        for n, prop, v in [(raiz, 'x', W / 2), (raiz, 'y', GROUND), (raiz, 'rotation', 0), (pesc, 'rotation', 0), (sombra, 'scaleX', 1), (sombra, 'scaleY', 1)]:
            if not any(pp == prop for pp, _ in r._keys.get(n, [])):
                r.keys(n, prop, [(0, v, 'hold')])

    anims = {}
    # ---------- parado
    anims['parado'] = r.animation('parado', 120, loop=True)
    pose([(0, 'parado')])
    r.keys(raiz, 'scaleY', [(0, SC), (60, SC * 1.025), (120, SC)])
    r.keys(raiz, 'scaleX', [(0, SC), (60, SC * 0.99), (120, SC)])
    r.keys(pesc, 'rotation', [(0, -0.04), (60, 0.04), (120, -0.04)])
    fim()

    # ---------- acertou: agacha, pula já comemorando, estrelas, confete, título
    anims['acertou'] = r.animation('acertou', 120)
    pose([(0, 'parado'), (9, 'feliz'), (104, 'parado')])
    r.keys(raiz, 'y', [(0, GROUND), (8, GROUND + 6, 'out'), (30, GROUND - 100, 'in'), (48, GROUND, 'lin'), (56, GROUND + 6, 'out'), (66, GROUND),
                       (72, GROUND - 30, 'in'), (82, GROUND, 'lin'), (88, GROUND)])
    r.keys(raiz, 'scaleY', [(0, SC), (8, SC * 0.82, 'out'), (18, SC * 1.1), (44, SC, 'lin'), (50, SC * 0.88, 'out'), (64, SC, 'pop'), (104, SC * 0.9, 'out'), (114, SC, 'pop')])
    r.keys(raiz, 'scaleX', [(0, SC), (8, SC * 1.14, 'out'), (18, SC * 0.92), (44, SC, 'lin'), (50, SC * 1.1, 'out'), (64, SC, 'pop'), (104, SC * 1.08, 'out'), (114, SC, 'pop')])
    r.keys(raiz, 'rotation', [(0, 0), (20, -0.1), (32, 0.1), (44, 0), (76, -0.06), (88, 0)])
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
        r.keys(s, 'rotation', [(t0, 0), (t0 + 64, random.choice([-1, 1]) * 3.5, 'out')])
        r.keys(s, 'opacity', [(0, 0, 'hold'), (t0, 1), (t0 + 44, 1), (t0 + 64, 0)])
    for i, c in enumerate(confs):
        t0 = 10 + random.randint(0, 22)
        x0 = random.uniform(30, W - 30)
        r.keys(c, 'x', [(0, x0, 'hold'), (t0, x0), (t0 + 70, x0 + random.uniform(-60, 60), 'lin')])
        r.keys(c, 'y', [(t0, -30), (t0 + 70, H + 30, 'lin')])
        r.keys(c, 'rotation', [(t0, 0), (t0 + 70, random.uniform(-9, 9), 'lin')])
        r.keys(c, 'opacity', [(0, 0, 'hold'), (t0, 1, 'hold'), (t0 + 70, 0, 'hold')])
    t = tits['acertou']
    r.keys(t, 'scaleX', [(16, 0), (30, 1, 'pop'), (96, 1), (116, 0.6)])
    r.keys(t, 'scaleY', [(16, 0), (30, 1, 'pop'), (96, 1), (116, 0.6)])
    r.keys(t, 'rotation', [(16, -0.3), (30, 0.04, 'pop'), (60, -0.04), (88, 0.03)])
    r.keys(t, 'opacity', [(0, 0, 'hold'), (16, 1, 'hold'), (100, 1), (116, 0)])
    fim()

    # ---------- errou: murcha, fica triste, gota, título
    anims['errou'] = r.animation('errou', 120)
    pose([(0, 'parado'), (8, 'triste'), (108, 'parado')])
    r.keys(raiz, 'scaleY', [(0, SC), (7, SC * 0.86, 'out'), (18, SC, 'pop'), (100, SC), (107, SC * 0.9), (116, SC, 'pop')])
    r.keys(raiz, 'scaleX', [(0, SC), (7, SC * 1.1, 'out'), (18, SC, 'pop'), (100, SC), (107, SC * 1.06), (116, SC, 'pop')])
    r.keys(raiz, 'rotation', [(18, 0), (30, -0.05), (42, 0.05), (54, -0.03), (66, 0)])
    r.keys(gota, 'opacity', [(0, 0, 'hold'), (30, 1), (86, 1), (100, 0)])
    r.keys(gota, 'y', [(30, 170), (100, 250, 'in')])
    r.keys(gota, 'scaleY', [(30, 0.3), (40, 1.1, 'pop'), (100, 1)])
    t = tits['errou']
    r.keys(t, 'scaleX', [(10, 0), (24, 0.85, 'pop'), (96, 0.85), (114, 0.5)])
    r.keys(t, 'scaleY', [(10, 0), (24, 0.85, 'pop'), (96, 0.85), (114, 0.5)])
    r.keys(t, 'y', [(10, 86), (96, 100), (114, 120)])
    r.keys(t, 'opacity', [(0, 0, 'hold'), (10, 1, 'hold'), (98, 1), (114, 0)])
    fim()

    # ---------- carta: personagem aponta, carta voa e vira no alto à direita
    anims['carta'] = r.animation('carta', 140)
    pose([(0, 'parado'), (10, 'aponta'), (118, 'parado')])
    r.keys(raiz, 'x', [(0, W / 2), (12, W / 2 - 60, 'out'), (112, W / 2 - 60), (130, W / 2, 'io')])
    r.keys(raiz, 'y', [(0, GROUND), (12, GROUND - 26, 'out'), (22, GROUND, 'in'), (140, GROUND)])
    r.keys(raiz, 'scaleY', [(0, SC), (8, SC * 0.88, 'out'), (20, SC, 'pop'), (112, SC), (118, SC * 0.9), (128, SC, 'pop')])
    r.keys(raiz, 'scaleX', [(0, SC), (8, SC * 1.08, 'out'), (20, SC, 'pop'), (112, SC), (118, SC * 1.06), (128, SC, 'pop')])
    r.keys(sombra, 'scaleX', [(0, 1), (12, 0.85), (22, 1)])
    r.keys(carta, 'y', [(0, H + 200), (28, CY, 'out'), (108, CY), (134, -220, 'in')])
    r.keys(carta, 'x', [(0, W + 120), (28, CX, 'out'), (108, CX), (134, CX + 40, 'in')])
    r.keys(carta, 'rotation', [(0, 0.6), (28, -0.1, 'pop'), (60, 0.03), (108, 0), (134, 0.4, 'in')])
    r.keys(carta, 'scaleX', [(0, 0.4), (28, 0.82, 'pop'), (108, 0.82)])
    r.keys(carta, 'scaleY', [(0, 0.4), (28, 0.82, 'pop'), (108, 0.82)])
    r.keys(carta_flip, 'scaleX', [(0, 1), (36, 1), (46, 0, 'in'), (56, 1, 'out')])
    r.keys(verso, 'opacity', [(0, 1, 'hold'), (46, 0, 'hold')])
    r.keys(frente, 'opacity', [(0, 0, 'hold'), (46, 1, 'hold')])
    t = tits['carta']
    r.keys(t, 'scaleX', [(40, 0), (54, 0.9, 'pop'), (108, 0.9), (126, 0.4)])
    r.keys(t, 'scaleY', [(40, 0), (54, 0.9, 'pop'), (108, 0.9), (126, 0.4)])
    r.keys(t, 'opacity', [(0, 0, 'hold'), (40, 1, 'hold'), (110, 1), (126, 0)])
    fim()

    # ---------- cócegas: leva um susto e treme
    anims['cocegas'] = r.animation('cocegas', 66)
    pose([(0, 'parado'), (4, 'susto'), (54, 'parado')])
    r.keys(raiz, 'y', [(0, GROUND), (10, GROUND - 40, 'out'), (22, GROUND, 'in'), (66, GROUND)])
    r.keys(raiz, 'rotation', [(0, 0), (24, 0), (28, 0.06), (32, -0.06), (36, 0.05), (40, -0.04), (44, 0.03), (50, 0)])
    r.keys(raiz, 'scaleY', [(0, SC), (4, SC * 0.86, 'out'), (14, SC * 1.06), (24, SC, 'pop'), (54, SC * 0.92), (62, SC, 'pop')])
    r.keys(raiz, 'scaleX', [(0, SC), (4, SC * 1.1, 'out'), (14, SC * 0.95), (24, SC, 'pop'), (54, SC * 1.05), (62, SC, 'pop')])
    fim()

    trig = ['acertou', 'errou', 'carta', 'cocegas']
    r.state_machine('Reacoes', trig, anims['parado'], {k: anims[k] for k in trig})
    out = os.path.join(OUT, nome + '.riv')
    os.makedirs(OUT, exist_ok=True)
    data = r.bytes()
    open(out, 'wb').write(data)
    print(out, len(data), 'bytes')


if __name__ == '__main__':
    alvo = sys.argv[1] if len(sys.argv) > 1 else 'todos'
    for n in (PERSONAGENS if alvo == 'todos' else [alvo]):
        gerar(n)
