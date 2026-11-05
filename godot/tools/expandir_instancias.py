#!/usr/bin/env python3
"""Expande a extensão EXT_mesh_gpu_instancing dos modelos de cenário (.glb).

O Godot ainda não importa essa extensão: as cópias (folhas, flores, tufos) caem todas na origem.
Este script "assa" as instâncias numa malha só por nó, que o Godot importa normalmente.

Uso: python3 tools/expandir_instancias.py entrada.glb [saida.glb]
     python3 tools/expandir_instancias.py --pasta assets/model/cenario
"""
import json
import math
import os
import struct
import sys

COMP = {5120: ('b', 1), 5121: ('B', 1), 5122: ('h', 2), 5123: ('H', 2), 5125: ('I', 4), 5126: ('f', 4)}
NCOMP = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}
NORM_DIV = {5120: 127.0, 5121: 255.0, 5122: 32767.0, 5123: 65535.0}


def ler_glb(caminho):
    b = open(caminho, 'rb').read()
    magic, ver, total = struct.unpack('<III', b[:12])
    assert magic == 0x46546C67, 'não é GLB'
    off = 12
    js, binc = None, b''
    while off < total:
        ln, tipo = struct.unpack('<II', b[off:off + 8])
        dados = b[off + 8:off + 8 + ln]
        if tipo == 0x4E4F534A:
            js = json.loads(dados.decode('utf-8'))
        elif tipo == 0x004E4942:
            binc = dados
        off += 8 + ln
    return js, bytearray(binc)


def gravar_glb(caminho, js, binc):
    jb = json.dumps(js, separators=(',', ':')).encode('utf-8')
    jb += b' ' * ((4 - len(jb) % 4) % 4)
    binc = bytes(binc) + b'\0' * ((4 - len(binc) % 4) % 4)
    total = 12 + 8 + len(jb) + 8 + len(binc)
    with open(caminho, 'wb') as f:
        f.write(struct.pack('<III', 0x46546C67, 2, total))
        f.write(struct.pack('<II', len(jb), 0x4E4F534A) + jb)
        f.write(struct.pack('<II', len(binc), 0x004E4942) + binc)


def ler_accessor(js, binc, idx):
    acc = js['accessors'][idx]
    fmt, tam = COMP[acc['componentType']]
    n = NCOMP[acc['type']]
    cnt = acc['count']
    if 'bufferView' not in acc:
        return [[0.0] * n for _ in range(cnt)]
    bv = js['bufferViews'][acc['bufferView']]
    base = bv.get('byteOffset', 0) + acc.get('byteOffset', 0)
    passo = bv.get('byteStride', tam * n)
    out = []
    for i in range(cnt):
        v = list(struct.unpack_from('<' + fmt * n, binc, base + i * passo))
        if acc.get('normalized') and acc['componentType'] in NORM_DIV:
            v = [max(x / NORM_DIV[acc['componentType']], -1.0) for x in v]
        out.append(v)
    return out


def anexar(js, binc, valores, comp, tipo, alvo=None, minmax=False):
    fmt, tam = COMP[comp]
    n = NCOMP[tipo]
    while len(binc) % 4:
        binc.append(0)
    ini = len(binc)
    for v in valores:
        binc.extend(struct.pack('<' + fmt * n, *v))
    bv = {'buffer': 0, 'byteOffset': ini, 'byteLength': len(binc) - ini}
    if alvo:
        bv['target'] = alvo
    js['bufferViews'].append(bv)
    acc = {'bufferView': len(js['bufferViews']) - 1, 'componentType': comp, 'count': len(valores), 'type': tipo}
    if minmax:
        acc['min'] = [min(v[k] for v in valores) for k in range(n)]
        acc['max'] = [max(v[k] for v in valores) for k in range(n)]
    js['accessors'].append(acc)
    return len(js['accessors']) - 1


def quat_rot(q, v):
    x, y, z, w = q
    # v' = q * v * q^-1
    ix = w * v[0] + y * v[2] - z * v[1]
    iy = w * v[1] + z * v[0] - x * v[2]
    iz = w * v[2] + x * v[1] - y * v[0]
    iw = -x * v[0] - y * v[1] - z * v[2]
    return [ix * w + iw * -x + iy * -z - iz * -y,
            iy * w + iw * -y + iz * -x - ix * -z,
            iz * w + iw * -z + ix * -y - iy * -x]


def normalizar(v):
    l = math.sqrt(v[0] ** 2 + v[1] ** 2 + v[2] ** 2) or 1.0
    return [v[0] / l, v[1] / l, v[2] / l]


def expandir(entrada, saida):
    js, binc = ler_glb(entrada)
    usadas = js.get('extensionsUsed') or []
    if 'EXT_mesh_gpu_instancing' not in usadas:
        return 0
    feitos = 0
    for node in js['nodes']:
        ext = (node.get('extensions') or {}).get('EXT_mesh_gpu_instancing')
        if not ext or 'mesh' not in node:
            continue
        at = ext['attributes']
        cnt = js['accessors'][list(at.values())[0]]['count']
        T = ler_accessor(js, binc, at['TRANSLATION']) if 'TRANSLATION' in at else [[0, 0, 0]] * cnt
        R = ler_accessor(js, binc, at['ROTATION']) if 'ROTATION' in at else [[0, 0, 0, 1]] * cnt
        S = ler_accessor(js, binc, at['SCALE']) if 'SCALE' in at else [[1, 1, 1]] * cnt
        malha = js['meshes'][node['mesh']]
        nova = {'name': (malha.get('name') or 'malha') + '_assada', 'primitives': []}
        for prim in malha['primitives']:
            pos = ler_accessor(js, binc, prim['attributes']['POSITION'])
            nor = ler_accessor(js, binc, prim['attributes']['NORMAL']) if 'NORMAL' in prim['attributes'] else None
            uv = ler_accessor(js, binc, prim['attributes']['TEXCOORD_0']) if 'TEXCOORD_0' in prim['attributes'] else None
            cor = ler_accessor(js, binc, prim['attributes']['COLOR_0']) if 'COLOR_0' in prim['attributes'] else None
            idx = [i[0] for i in ler_accessor(js, binc, prim['indices'])] if 'indices' in prim else list(range(len(pos)))
            P, N, U, C, I = [], [], [], [], []
            for k in range(cnt):
                t, r, s = T[k], R[k], S[k]
                base = len(P)
                for v in pos:
                    p = quat_rot(r, [v[0] * s[0], v[1] * s[1], v[2] * s[2]])
                    P.append([p[0] + t[0], p[1] + t[1], p[2] + t[2]])
                if nor:
                    for v in nor:
                        N.append(normalizar(quat_rot(r, normalizar([v[0] / (s[0] or 1), v[1] / (s[1] or 1), v[2] / (s[2] or 1)]))))
                if uv:
                    U.extend(uv)
                if cor:
                    C.extend(cor)
                I.extend(base + i for i in idx)
            attrs = {'POSITION': anexar(js, binc, P, 5126, 'VEC3', 34962, True)}
            if N:
                attrs['NORMAL'] = anexar(js, binc, N, 5126, 'VEC3', 34962)
            if U:
                attrs['TEXCOORD_0'] = anexar(js, binc, U, 5126, 'VEC2', 34962)
            if C:
                attrs['COLOR_0'] = anexar(js, binc, C, 5126, 'VEC4' if len(C[0]) == 4 else 'VEC3', 34962)
            np = {'attributes': attrs, 'indices': anexar(js, binc, [[i] for i in I], 5125, 'SCALAR', 34963)}
            for k in ('material', 'mode'):
                if k in prim:
                    np[k] = prim[k]
            nova['primitives'].append(np)
        js['meshes'].append(nova)
        node['mesh'] = len(js['meshes']) - 1
        del node['extensions']['EXT_mesh_gpu_instancing']
        if not node['extensions']:
            del node['extensions']
        feitos += 1
    js['extensionsUsed'] = [e for e in usadas if e != 'EXT_mesh_gpu_instancing']
    if not js['extensionsUsed']:
        del js['extensionsUsed']
    if 'extensionsRequired' in js:
        js['extensionsRequired'] = [e for e in js['extensionsRequired'] if e != 'EXT_mesh_gpu_instancing']
        if not js['extensionsRequired']:
            del js['extensionsRequired']
    js['buffers'][0]['byteLength'] = len(binc)
    gravar_glb(saida, js, binc)
    return feitos


if __name__ == '__main__':
    if len(sys.argv) >= 3 and sys.argv[1] == '--pasta':
        for nome in sorted(os.listdir(sys.argv[2])):
            if nome.endswith('.glb'):
                c = os.path.join(sys.argv[2], nome)
                n = expandir(c, c)
                if n:
                    print(f'{nome}: {n} nós expandidos')
    else:
        print(expandir(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else sys.argv[1]), 'nós expandidos')
