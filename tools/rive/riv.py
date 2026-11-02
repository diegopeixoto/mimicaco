"""Escritor mínimo de arquivos .riv (formato binário do runtime Rive).

Serve para gerar animações Rive por código, sem o editor do Rive.
As chaves de tipo/propriedade vêm de include/rive/generated/*_base.hpp
do repositório aberto rive-app/rive-runtime (MIT).
"""
import struct

# tipos de campo
U, D, S, B, C, BY = 'uint', 'double', 'string', 'bool', 'color', 'bytes'

# chave da propriedade -> (nome, tipo)
P = {
    'name': (4, S), 'parentId': (5, U),
    'width': (7, D), 'height': (8, D),            # LayoutComponent/Artboard
    'x': (13, D), 'y': (14, D), 'rotation': (15, D), 'scaleX': (16, D), 'scaleY': (17, D),
    'opacity': (18, D),
    'pw': (20, D), 'ph': (21, D),                 # ParametricPath width/height
    'cornerRadius': (31, D),
    'colorValue': (37, C), 'thickness': (47, D),
    'objectId': (51, U), 'propertyKey': (53, U),
    'animName': (55, S), 'fps': (56, U), 'duration': (57, U), 'speed': (58, D), 'loopValue': (59, U),
    'x1': (63, D), 'y1': (64, D), 'x2': (65, D), 'y2': (66, D),
    'frame': (67, U), 'interpolationType': (68, U), 'interpolatorId': (69, U), 'value': (70, D),
    'points': (125, U), 'innerRadius': (127, D),
    'smName': (138, S), 'animationId': (149, U),
    'stateToId': (151, U), 'flags': (152, U), 'transDuration': (158, U), 'exitTime': (160, U),
    'inputId': (155, U),
    'assetName': (203, S), 'assetId': (204, U), 'imgAssetId': (206, U),
    'assetH': (207, D), 'assetW': (208, D), 'bytes': (212, BY),
    'defaultStateMachineId': (236, U),
}

T = {
    'Backboard': 23, 'Artboard': 1, 'Node': 2, 'Shape': 3, 'Ellipse': 4, 'Rectangle': 7,
    'Star': 52, 'Fill': 20, 'Stroke': 24, 'SolidColor': 18, 'Image': 100,
    'ImageAsset': 105, 'FileAssetContents': 106,
    'CubicEaseInterpolator': 28, 'LinearAnimation': 31, 'KeyedObject': 25, 'KeyedProperty': 26,
    'KeyFrameDouble': 30,
    'StateMachine': 53, 'StateMachineTrigger': 58, 'StateMachineLayer': 57,
    'AnyState': 62, 'EntryState': 63, 'ExitState': 64, 'AnimationState': 61,
    'StateTransition': 65, 'TransitionTriggerCondition': 68,
}

PROP = {'x': 13, 'y': 14, 'rotation': 15, 'scaleX': 16, 'scaleY': 17, 'opacity': 18}


def varuint(n):
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def enc(kind, v):
    if kind == U:
        return varuint(int(v))
    if kind == D:
        return struct.pack('<f', float(v))
    if kind == S:
        b = v.encode('utf8')
        return varuint(len(b)) + b
    if kind == BY:
        return varuint(len(v)) + v
    if kind == B:
        return bytes([1 if v else 0])
    if kind == C:
        return struct.pack('<I', v)
    raise ValueError(kind)


class Riv:
    def __init__(self):
        self.objs = []          # (typeKey, [(propKey, kind, value)])
        self.ab_index = None    # índice do objeto Artboard
        self.n_assets = 0
        self.ab_count = 0       # objetos do artboard (Artboard = 0)
        self.interp = {}
        self.add('Backboard')

    def add(self, type_name, **props):
        lst = []
        for k, v in props.items():
            if v is None:
                continue
            key, kind = P[k]
            lst.append((key, kind, v))
        self.objs.append((T[type_name], lst))

    # ---- arquivos de imagem embutidos
    def image_asset(self, name, data, w, h):
        self.add('ImageAsset', assetName=name, assetId=self.n_assets, assetW=w, assetH=h)
        self.add('FileAssetContents', bytes=data)
        self.n_assets += 1
        return self.n_assets - 1

    # ---- artboard e componentes (o id é a posição dentro do artboard)
    def artboard(self, name, w, h):
        self.add('Artboard', name=name, width=w, height=h, defaultStateMachineId=0)
        self.ab_count = 1
        return 0

    def comp(self, type_name, parent=None, **props):
        self.add(type_name, parentId=parent, **props)
        self.ab_count += 1
        return self.ab_count - 1

    def node(self, parent, name=None, **p):
        return self.comp('Node', parent, name=name, **p)

    def _paint(self, shape, color, stroke=None):
        f = self.comp('Fill', shape)
        self.comp('SolidColor', f, colorValue=color)
        if stroke:
            s = self.comp('Stroke', shape, thickness=stroke[1])
            self.comp('SolidColor', s, colorValue=stroke[0])

    def rect(self, parent, w, h, color, radius=0, stroke=None, name=None, **p):
        s = self.comp('Shape', parent, name=name, **p)
        self.comp('Rectangle', s, pw=w, ph=h, cornerRadius=radius or None)
        self._paint(s, color, stroke)
        return s

    def ellipse(self, parent, w, h, color, stroke=None, name=None, **p):
        s = self.comp('Shape', parent, name=name, **p)
        self.comp('Ellipse', s, pw=w, ph=h)
        self._paint(s, color, stroke)
        return s

    def star(self, parent, size, color, points=5, inner=0.5, stroke=None, name=None, **p):
        s = self.comp('Shape', parent, name=name, **p)
        self.comp('Star', s, pw=size, ph=size, points=points, innerRadius=inner)
        self._paint(s, color, stroke)
        return s

    def image(self, parent, asset, name=None, **p):
        return self.comp('Image', parent, name=name, imgAssetId=asset, **p)

    def ease(self, name, x1, y1, x2, y2):
        self.interp[name] = self.comp('CubicEaseInterpolator', x1=x1, y1=y1, x2=x2, y2=y2)

    # ---- animações
    def animation(self, name, frames, loop=False, fps=60):
        self.flush()
        self.add('LinearAnimation', animName=name, fps=fps, duration=frames, loopValue=1 if loop else 0)
        self._keys = {}
        self.n_anims = getattr(self, 'n_anims', 0) + 1
        return self.n_anims - 1

    def keys(self, obj, prop, kfs):
        """kfs: lista de (frame, valor[, ease]) — ease = 'lin', 'hold' ou nome de curva."""
        self._keys.setdefault(obj, []).append((prop, kfs))

    def flush(self):
        for obj, plist in getattr(self, '_keys', {}).items():
            self.add('KeyedObject', objectId=obj)
            for prop, kfs in plist:
                self._emit(prop, kfs)
        self._keys = {}

    def _emit(self, prop, kfs):
        self.add('KeyedProperty', propertyKey=PROP[prop])
        for kf in kfs:
            frame, value = kf[0], kf[1]
            e = kf[2] if len(kf) > 2 else 'io'
            if e == 'lin':
                it, iid = 1, None
            elif e == 'hold':
                it, iid = 0, None
            else:
                it, iid = 2, self.interp[e]
            self.add('KeyFrameDouble', frame=frame, value=value, interpolationType=it, interpolatorId=iid)

    # ---- máquina de estados (uma camada, gatilhos)
    def state_machine(self, name, triggers, idle_anim, oneshots):
        """triggers: nomes; oneshots: {trigger: animação} — tocam uma vez e voltam ao idle."""
        self.flush()
        self.add('StateMachine', animName=name)
        for t in triggers:
            self.add('StateMachineTrigger', smName=t)
        self.add('StateMachineLayer', smName='Camada 1')
        # estados: 0 Entry, 1 Any, 2 Exit, 3 idle, 4.. oneshots
        names = list(oneshots)
        self.add('EntryState')
        self.add('StateTransition', stateToId=3)
        self.add('AnyState')
        for i, t in enumerate(names):
            self.add('StateTransition', stateToId=4 + i, transDuration=0)
            self.add('TransitionTriggerCondition', inputId=triggers.index(t))
        self.add('ExitState')
        self.add('AnimationState', animationId=idle_anim)
        for i, t in enumerate(names):
            self.add('AnimationState', animationId=oneshots[t])
            # volta para o idle quando a animação termina (exit time 100%)
            self.add('StateTransition', stateToId=3, flags=4 | 8, exitTime=100, transDuration=0)

    def bytes(self):
        self.flush()
        out = bytearray(b'RIVE')
        out += varuint(7) + varuint(0) + varuint(0)
        out += varuint(0)  # tabela de propriedades vazia: todas são conhecidas pelo runtime
        for t, props in self.objs:
            out += varuint(t)
            for key, kind, v in props:
                out += varuint(key) + enc(kind, v)
            out += varuint(0)
        return bytes(out)
