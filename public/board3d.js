// Tabuleiro 3D do Mimicaço da Turma do Rawzinho (Three.js).
// Tudo que se mexe é calculado a partir do horário do servidor, então a TV e os celulares mostram o mesmo movimento.
import * as THREE from './vendor/three.module.min.js';
import { RoundedBoxGeometry } from './vendor/RoundedBoxGeometry.js';

// Precisa bater com server.js
export const DICE_MS = 1700;
export const HOP_MS = 330;
export function moveDuration(move) {
  return (move.kind === 'dice' ? DICE_MS : 400) + move.path.length * HOP_MS + 300;
}

const ART = { acao: 'acao', objeto: 'objeto', gente: 'gente', bicho: 'bicho', lugar: 'lugar', dificil: 'dificil' };
const SPACING = 1.42;
const TILE = 1.08;

function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const ease = (t) => 1 - Math.pow(1 - t, 3);
const clamp01 = (t) => Math.max(0, Math.min(1, t));

function loadImage(src) {
  return new Promise((res) => {
    const im = new Image();
    im.onload = () => res(im);
    im.onerror = () => res(null);
    im.src = src;
  });
}

export async function createBoard(container, opts = {}) {
  const low = !!opts.low;
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, low ? 1.5 : 2));
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.05;
  container.appendChild(renderer.domElement);
  Object.assign(renderer.domElement.style, { display: 'block', width: '100%', height: '100%' });

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(38, 1, 0.1, 200);

  scene.add(new THREE.HemisphereLight(0xfff4d6, 0x5f9e3a, 1.25));
  const sun = new THREE.DirectionalLight(0xfff0d0, 2.2);
  sun.position.set(-8, 16, 10);
  sun.castShadow = true;
  sun.shadow.mapSize.set(low ? 1024 : 2048, low ? 1024 : 2048);
  sun.shadow.bias = -0.0005;
  scene.add(sun);
  scene.add(sun.target);

  await Promise.all([document.fonts?.load('48px "Lilita One"').catch(() => {}), document.fonts?.ready]);
  const images = {};
  await Promise.all(['acao', 'objeto', 'gente', 'bicho', 'lugar', 'dificil', 'todos', 'trofeu', 'largada'].map(async (k) => {
    images[k] = await loadImage(`img/${k}.jpg`);
  }));

  // ---------- Texturas ----------
  function tileTexture({ img, color, num, label }) {
    const c = document.createElement('canvas');
    c.width = c.height = 256;
    const g = c.getContext('2d');
    g.fillStyle = '#ffffff';
    g.beginPath(); g.arc(128, 128, 126, 0, Math.PI * 2); g.fill();
    g.save();
    g.beginPath(); g.arc(128, 128, 112, 0, Math.PI * 2); g.clip();
    if (img) g.drawImage(img, 16, 16, 224, 224);
    else { g.fillStyle = color; g.fillRect(0, 0, 256, 256); }
    if (label) {
      g.fillStyle = color; g.fillRect(0, 0, 256, 256);
      g.fillStyle = '#fff';
      g.font = '110px "Lilita One", sans-serif';
      g.textAlign = 'center'; g.textBaseline = 'middle';
      g.lineWidth = 12; g.strokeStyle = 'rgba(18,58,122,.8)';
      g.strokeText(label, 128, 120); g.fillText(label, 128, 120);
      g.font = '34px "Lilita One", sans-serif';
      g.lineWidth = 7; g.strokeText('PULO!', 128, 200); g.fillText('PULO!', 128, 200);
    }
    g.restore();
    if (num) {
      g.fillStyle = '#123a7a';
      g.beginPath(); g.arc(128, 222, 26, 0, Math.PI * 2); g.fill();
      g.fillStyle = '#fff';
      g.font = '34px "Lilita One", sans-serif';
      g.textAlign = 'center'; g.textBaseline = 'middle';
      g.fillText(String(num), 128, 224);
    }
    const t = new THREE.CanvasTexture(c);
    t.colorSpace = THREE.SRGBColorSpace;
    t.anisotropy = 4;
    return t;
  }

  function pipTexture(n) {
    const c = document.createElement('canvas');
    c.width = c.height = 128;
    const g = c.getContext('2d');
    g.fillStyle = '#ffffff'; g.fillRect(0, 0, 128, 128);
    const P = { 1: [[64, 64]], 2: [[34, 34], [94, 94]], 3: [[30, 30], [64, 64], [98, 98]], 4: [[34, 34], [94, 34], [34, 94], [94, 94]],
      5: [[30, 30], [98, 30], [64, 64], [30, 98], [98, 98]], 6: [[34, 28], [94, 28], [34, 64], [94, 64], [34, 100], [94, 100]] };
    g.fillStyle = n === 1 ? '#e8453c' : '#123a7a';
    for (const [x, y] of P[n]) { g.beginPath(); g.arc(x, y, n === 1 ? 17 : 12, 0, Math.PI * 2); g.fill(); }
    const t = new THREE.CanvasTexture(c);
    t.colorSpace = THREE.SRGBColorSpace;
    return t;
  }

  // ---------- Grupos ----------
  const world = new THREE.Group();
  scene.add(world);
  let boardKey = null;
  let tiles = []; // { mesh, pos: Vector3 }
  let boardGroup = null;
  let center = new THREE.Vector3();
  let radius = 8;
  const pawns = new Map(); // teamId -> { group, body, color }
  let ring;

  // Dado
  const diceFaces = [3, 4, 1, 6, 2, 5]; // +x, -x, +y, -y, +z, -z
  const faceNormals = [new THREE.Vector3(1, 0, 0), new THREE.Vector3(-1, 0, 0), new THREE.Vector3(0, 1, 0),
    new THREE.Vector3(0, -1, 0), new THREE.Vector3(0, 0, 1), new THREE.Vector3(0, 0, -1)];
  const dice = new THREE.Mesh(
    new RoundedBoxGeometry(0.95, 0.95, 0.95, 5, 0.18),
    diceFaces.map((n) => new THREE.MeshStandardMaterial({ map: pipTexture(n), roughness: 0.35 })),
  );
  dice.castShadow = true;
  dice.visible = false;
  scene.add(dice);

  function layout(n) {
    const rows = n <= 21 ? 3 : n <= 31 ? 4 : 5;
    const W = Math.max(5, ((n - 1) * SPACING - (rows - 1) * 3.4) / rows);
    const rowGap = 2.5;
    const pts = [];
    for (let r = 0; r < rows; r++) {
      const z = (rows - 1) * rowGap / 2 - r * rowGap;
      const dir = r % 2 === 0 ? 1 : -1;
      const xs = [-W / 2, -W / 6, W / 6, W / 2].map((x) => x * dir);
      xs.forEach((x, i) => pts.push(new THREE.Vector3(x, 0, z + (i % 2 ? 0.35 : -0.15) * (r % 2 ? -1 : 1))));
    }
    const curve = new THREE.CatmullRomCurve3(pts, false, 'centripetal', 0.5);
    return curve.getSpacedPoints(n - 1);
  }

  function buildBoard(board, categories) {
    if (boardGroup) world.remove(boardGroup);
    boardGroup = new THREE.Group();
    world.add(boardGroup);
    tiles = [];
    const positions = layout(board.length);
    const box = new THREE.Box3().setFromPoints(positions);
    center = box.getCenter(new THREE.Vector3());
    const size = box.getSize(new THREE.Vector3());
    radius = Math.max(size.x, size.z) / 2 + 2.5;

    // Ilha flutuante em camadas, como um bolo de brinquedo
    const pad = 1.6;
    const w = size.x + pad * 2, h = size.z + pad * 2, rr = 2.2;
    const shape = new THREE.Shape();
    const x0 = box.min.x - pad, z0 = box.min.z - pad;
    const P = (x, z) => [x, -z];
    shape.moveTo(...P(x0 + rr, z0));
    shape.lineTo(...P(x0 + w - rr, z0)); shape.quadraticCurveTo(...P(x0 + w, z0), ...P(x0 + w, z0 + rr));
    shape.lineTo(...P(x0 + w, z0 + h - rr)); shape.quadraticCurveTo(...P(x0 + w, z0 + h), ...P(x0 + w - rr, z0 + h));
    shape.lineTo(...P(x0 + rr, z0 + h)); shape.quadraticCurveTo(...P(x0, z0 + h), ...P(x0, z0 + h - rr));
    shape.lineTo(...P(x0, z0 + rr)); shape.quadraticCurveTo(...P(x0, z0), ...P(x0 + rr, z0));
    const layer = (depth, color, side, y, scale) => {
      const geo = new THREE.ExtrudeGeometry(shape, { depth, bevelEnabled: true, bevelThickness: 0.25, bevelSize: 0.3, bevelSegments: 4, curveSegments: 24 });
      geo.rotateX(-Math.PI / 2);
      const m = new THREE.Mesh(geo, [new THREE.MeshStandardMaterial({ color, roughness: 0.9 }), new THREE.MeshStandardMaterial({ color: side, roughness: 0.95 })]);
      m.position.y = y;
      m.scale.set(scale, 1, scale);
      m.position.x = center.x * (1 - scale);
      m.position.z = center.z * (1 - scale);
      m.receiveShadow = true;
      boardGroup.add(m);
    };
    layer(0.5, 0x7ccf4a, 0x9a6b3f, -0.75, 1);
    layer(0.9, 0x6bb83f, 0x7d5330, -1.95, 0.94);
    layer(0.8, 0x8a5a33, 0x6b4426, -3.0, 0.82);

    // Caminho de pedrinhas entre as casas
    const stoneMat = new THREE.MeshStandardMaterial({ color: 0xf3e3c3, roughness: 0.8 });
    for (let i = 0; i < positions.length - 1; i++) {
      const a = positions[i], b = positions[i + 1];
      const s = new THREE.Mesh(new THREE.CylinderGeometry(0.16, 0.18, 0.08, 12), stoneMat);
      s.position.copy(a).lerp(b, 0.5).setY(-0.2);
      s.receiveShadow = true;
      boardGroup.add(s);
    }

    // Casas
    board.forEach((sq, i) => {
      let color = '#ffffff', img = null, label = null;
      if (sq.type === 'cat') { color = categories[sq.cat].color; img = images[ART[sq.cat]]; }
      if (sq.type === 'all') { color = '#fff1a8'; img = images.todos; }
      if (sq.type === 'start') { color = '#ffffff'; img = images.largada; }
      if (sq.type === 'finish') { color = '#ffd23d'; img = images.trofeu; }
      if (sq.type === 'jump') { color = '#5ec8ff'; label = '+2'; }
      const big = sq.type === 'start' || sq.type === 'finish';
      const s = big ? 1.3 : 1;
      const g = new THREE.Group();
      const base = new THREE.Mesh(new RoundedBoxGeometry(TILE * s, 0.34, TILE * s, 4, 0.14),
        new THREE.MeshStandardMaterial({ color, roughness: 0.45, emissive: new THREE.Color(color), emissiveIntensity: 0 }));
      base.castShadow = true;
      base.receiveShadow = true;
      g.add(base);
      const top = new THREE.Mesh(new THREE.CircleGeometry(0.43 * s, 48),
        new THREE.MeshStandardMaterial({ map: tileTexture({ img, color, num: sq.type === 'cat' || sq.type === 'all' || sq.type === 'jump' ? i : null, label }), roughness: 0.6 }));
      top.rotation.x = -Math.PI / 2;
      top.position.y = 0.175;
      top.receiveShadow = true;
      g.add(top);
      g.position.copy(positions[i]);
      boardGroup.add(g);
      tiles.push({ group: g, base, pos: positions[i].clone() });
    });

    // Troféu na chegada
    const gold = new THREE.MeshStandardMaterial({ color: 0xffc928, metalness: 0.8, roughness: 0.25 });
    const cup = new THREE.Mesh(new THREE.LatheGeometry([
      new THREE.Vector2(0.0, 0), new THREE.Vector2(0.32, 0), new THREE.Vector2(0.3, 0.08), new THREE.Vector2(0.1, 0.14),
      new THREE.Vector2(0.08, 0.42), new THREE.Vector2(0.18, 0.5), new THREE.Vector2(0.38, 0.62), new THREE.Vector2(0.42, 0.95),
      new THREE.Vector2(0.38, 0.95), new THREE.Vector2(0.0, 0.7)], 32), gold);
    cup.castShadow = true;
    const trophy = new THREE.Group();
    trophy.add(cup);
    [-1, 1].forEach((sgn) => {
      const handle = new THREE.Mesh(new THREE.TorusGeometry(0.16, 0.04, 8, 20, Math.PI), gold);
      handle.position.set(0.42 * sgn, 0.75, 0);
      handle.rotation.z = sgn > 0 ? -Math.PI / 2 : Math.PI / 2;
      trophy.add(handle);
    });
    const last = tiles[tiles.length - 1].pos;
    const dirOut = last.clone().sub(tiles[tiles.length - 2].pos).normalize();
    trophy.position.copy(last).add(dirOut.multiplyScalar(1.1)).setY(-0.2);
    trophy.scale.setScalar(1.3);
    trophy.userData.spin = true;
    boardGroup.add(trophy);

    // Bandeirinha na largada
    const flagTex = (() => {
      const c = document.createElement('canvas'); c.width = 64; c.height = 40;
      const g = c.getContext('2d');
      for (let x = 0; x < 8; x++) for (let y = 0; y < 5; y++) { g.fillStyle = (x + y) % 2 ? '#123a7a' : '#fff'; g.fillRect(x * 8, y * 8, 8, 8); }
      const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.magFilter = THREE.NearestFilter; return t;
    })();
    const first = tiles[0].pos;
    const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.04, 0.04, 1.5, 8), new THREE.MeshStandardMaterial({ color: 0xffffff }));
    const back = first.clone().sub(tiles[1].pos).normalize();
    pole.position.copy(first).add(back.clone().multiplyScalar(0.95)).setY(0.5);
    pole.castShadow = true;
    const flag = new THREE.Mesh(new THREE.PlaneGeometry(0.7, 0.45, 8, 1), new THREE.MeshStandardMaterial({ map: flagTex, side: THREE.DoubleSide }));
    flag.position.set(0.35, 0.5, 0);
    flag.userData.wave = true;
    pole.add(flag);
    boardGroup.add(pole);

    // Decoração: árvores, flores, cogumelos (longe do caminho)
    const r = rng(board.length * 7919);
    const near = (x, z, d) => positions.some((p) => (p.x - x) ** 2 + (p.z - z) ** 2 < d * d);
    const leafMats = [0x4fae3b, 0x67c24a, 0x3f9a3a].map((c) => new THREE.MeshStandardMaterial({ color: c, roughness: 0.8 }));
    const trunkMat = new THREE.MeshStandardMaterial({ color: 0x8a5a33 });
    const flowerColors = [0xff6fb5, 0xffd23d, 0xffffff, 0xa26bff, 0xff8a3d, 0x5ec8ff];
    const nTrees = low ? 10 : 18;
    let placed = 0, tries = 0;
    while (placed < nTrees && tries++ < 400) {
      const x = x0 + 0.5 + r() * (w - 1), z = z0 + 0.5 + r() * (h - 1);
      if (near(x, z, 1.2)) continue;
      const edge = Math.min(x - x0, x0 + w - x, z - z0, z0 + h - z);
      if (edge > 1.6 && r() > 0.25) continue; // mais árvores na borda
      const t = new THREE.Group();
      const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.11, 0.5, 8), trunkMat);
      trunk.position.y = 0.0;
      t.add(trunk);
      const round = r() > 0.4;
      const leaves = new THREE.Mesh(round ? new THREE.SphereGeometry(0.42, 16, 12) : new THREE.ConeGeometry(0.42, 0.95, 12), leafMats[placed % 3]);
      leaves.position.y = round ? 0.55 : 0.7;
      t.add(leaves);
      t.traverse((o) => { o.castShadow = true; });
      t.position.set(x, -0.0, z);
      t.scale.setScalar(0.8 + r() * 0.6);
      boardGroup.add(t);
      placed++;
    }
    const flowerGeo = new THREE.SphereGeometry(0.07, 8, 6);
    const nFlowers = low ? 50 : 110;
    for (let k = 0, tries2 = 0; k < nFlowers && tries2 < 1500; tries2++) {
      const x = x0 + 0.2 + r() * (w - 0.4), z = z0 + 0.2 + r() * (h - 0.4);
      if (near(x, z, 0.85)) continue;
      const f = new THREE.Mesh(flowerGeo, new THREE.MeshStandardMaterial({ color: flowerColors[k % flowerColors.length], roughness: 0.6 }));
      f.position.set(x, -0.2, z);
      boardGroup.add(f);
      k++;
    }
    const capMat = new THREE.MeshStandardMaterial({ color: 0xe8453c, roughness: 0.5 });
    const stemMat = new THREE.MeshStandardMaterial({ color: 0xfff3dc });
    for (let k = 0, tries3 = 0; k < 6 && tries3 < 300; tries3++) {
      const x = x0 + 0.4 + r() * (w - 0.8), z = z0 + 0.4 + r() * (h - 0.8);
      if (near(x, z, 1.0)) continue;
      const m = new THREE.Group();
      const stem = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.08, 0.2, 8), stemMat);
      const cap = new THREE.Mesh(new THREE.SphereGeometry(0.17, 16, 8, 0, Math.PI * 2, 0, Math.PI / 2), capMat);
      cap.position.y = 0.1;
      m.add(stem, cap);
      m.traverse((o) => { o.castShadow = true; });
      m.position.set(x, -0.15, z);
      boardGroup.add(m);
      k++;
    }

    // Nuvens fofas
    const cloudMat = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 1, transparent: true, opacity: 0.95 });
    for (let k = 0; k < (low ? 3 : 5); k++) {
      const c = new THREE.Group();
      for (let j = 0; j < 4; j++) {
        const puff = new THREE.Mesh(new THREE.SphereGeometry(0.5 + r() * 0.35, 16, 12), cloudMat);
        puff.position.set(j * 0.55 - 0.8, r() * 0.25, r() * 0.3);
        c.add(puff);
      }
      c.position.set(center.x - radius + r() * radius * 2, 3.2 + r() * 1.5, center.z - radius * 0.9 + r() * radius * 0.6);
      c.userData.drift = 0.15 + r() * 0.2;
      c.userData.base = c.position.x;
      boardGroup.add(c);
    }

    // Sombra cobrindo a ilha
    const sc = sun.shadow.camera;
    sc.left = -radius - 2; sc.right = radius + 2; sc.top = radius + 2; sc.bottom = -radius - 2;
    sc.updateProjectionMatrix();
    sun.target.position.copy(center);
    sun.position.copy(center).add(new THREE.Vector3(-8, 16, 10));

    // Anel que marca quem está jogando
    ring = new THREE.Mesh(new THREE.TorusGeometry(0.42, 0.06, 10, 40), new THREE.MeshBasicMaterial({ color: 0xffffff }));
    ring.rotation.x = -Math.PI / 2;
    ring.visible = false;
    boardGroup.add(ring);
  }

  // ---------- Peões ----------
  function makePawn(color) {
    const g = new THREE.Group();
    const body = new THREE.Group();
    g.add(body);
    const mat = new THREE.MeshPhysicalMaterial({ color, roughness: 0.25, clearcoat: 1, clearcoatRoughness: 0.15 });
    const lathe = new THREE.Mesh(new THREE.LatheGeometry([
      new THREE.Vector2(0, 0), new THREE.Vector2(0.3, 0), new THREE.Vector2(0.32, 0.05), new THREE.Vector2(0.3, 0.12),
      new THREE.Vector2(0.2, 0.18), new THREE.Vector2(0.14, 0.4), new THREE.Vector2(0.2, 0.46), new THREE.Vector2(0.12, 0.5),
      new THREE.Vector2(0, 0.5)], 32), mat);
    lathe.castShadow = true;
    body.add(lathe);
    const head = new THREE.Mesh(new THREE.SphereGeometry(0.22, 32, 24), mat);
    head.position.y = 0.66;
    head.castShadow = true;
    body.add(head);
    // olhinhos fofos
    const white = new THREE.MeshBasicMaterial({ color: 0xffffff });
    const black = new THREE.MeshBasicMaterial({ color: 0x14213d });
    [-1, 1].forEach((s) => {
      const eye = new THREE.Mesh(new THREE.SphereGeometry(0.06, 16, 12), white);
      eye.position.set(0.075 * s, 0.7, 0.18);
      eye.scale.z = 0.6;
      const pupil = new THREE.Mesh(new THREE.SphereGeometry(0.035, 12, 10), black);
      pupil.position.set(0.075 * s, 0.7, 0.215);
      body.add(eye, pupil);
    });
    const cheek = new THREE.MeshBasicMaterial({ color: 0xff8fa3, transparent: true, opacity: 0.7 });
    [-1, 1].forEach((s) => {
      const c = new THREE.Mesh(new THREE.SphereGeometry(0.035, 10, 8), cheek);
      c.position.set(0.13 * s, 0.63, 0.17);
      c.scale.z = 0.4;
      body.add(c);
    });
    g.scale.setScalar(1.1);
    return { group: g, body };
  }

  function syncPawns(teams) {
    for (const t of teams) {
      if (!pawns.has(t.id)) {
        const p = makePawn(t.color);
        boardGroup.add(p.group);
        pawns.set(t.id, p);
      }
    }
    for (const [id, p] of pawns) {
      if (!teams.find((t) => t.id === id)) { p.group.parent?.remove(p.group); pawns.delete(id); }
    }
  }

  // ---------- Estado ----------
  let S = null;
  let offset = 0;
  let size = { w: 1, h: 1 };
  let lastHopKey = null;
  let lastDiceId = null;
  const camTarget = new THREE.Vector3();
  const camFocus = new THREE.Vector3();
  let camInit = false;

  function update(state, serverOffset = 0) {
    S = state;
    offset = serverOffset;
    const key = S.board.map((b) => b.type + (b.cat || '')).join(',');
    if (key !== boardKey) {
      boardKey = key;
      for (const [, p] of pawns) p.group.parent?.remove(p.group);
      pawns.clear();
      buildBoard(S.board, S.categories);
      camInit = false;
    }
    syncPawns(S.teams);
  }

  function slotOffset(k, n) {
    if (n <= 1) return new THREE.Vector3();
    const a = (k / n) * Math.PI * 2 + Math.PI / 4;
    return new THREE.Vector3(Math.cos(a) * 0.27, 0, Math.sin(a) * 0.27);
  }

  function tilePos(i) {
    return tiles[Math.max(0, Math.min(i, tiles.length - 1))].pos;
  }

  function resize() {
    const w = container.clientWidth || 1, h = container.clientHeight || 1;
    if (w === size.w && h === size.h) return;
    size = { w, h };
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
  }
  new ResizeObserver(resize).observe(container);
  resize();

  const tmp = new THREE.Vector3();
  const clock = new THREE.Clock();

  function frame() {
    requestAnimationFrame(frame);
    if (!S || !tiles.length) return;
    const time = clock.getElapsedTime();
    const now = Date.now() + offset;
    const mv = S.move;
    const mvT = mv ? now - mv.at : Infinity;
    const animating = mv && mvT < mv.dur;
    const diceEnd = mv ? (mv.kind === 'dice' ? DICE_MS : 400) : 0;

    // Onde cada peão está (o que se move segue o caminho casa a casa)
    const shown = new Map();
    for (const t of S.teams) shown.set(t.id, { pos: t.pos, hop: null });
    if (animating && shown.has(mv.teamId)) {
      const steps = mv.path;
      const tt = mvT - diceEnd;
      if (tt < 0) shown.get(mv.teamId).pos = mv.from;
      else {
        const k = Math.floor(tt / HOP_MS);
        if (k >= steps.length) shown.get(mv.teamId).pos = steps[steps.length - 1] ?? mv.from;
        else {
          const fromI = k === 0 ? mv.from : steps[k - 1];
          shown.get(mv.teamId).pos = fromI;
          shown.get(mv.teamId).hop = { from: fromI, to: steps[k], f: (tt - k * HOP_MS) / HOP_MS };
          const hopKey = mv.id + ':' + k;
          if (hopKey !== lastHopKey) { lastHopKey = hopKey; opts.onHop?.(k, steps.length); }
        }
      }
    }
    // agrupa por casa para não ficarem um em cima do outro
    const byTile = {};
    for (const [id, s] of shown) if (!s.hop) (byTile[s.pos] = byTile[s.pos] || []).push(id);

    const actingId = S.turn && S.phase !== 'lobby' && S.phase !== 'over' ? S.turn.actingId : null;
    for (const t of S.teams) {
      const p = pawns.get(t.id);
      if (!p) continue;
      const s = shown.get(t.id);
      let y = 0.17;
      if (s.hop) {
        const a = tilePos(s.hop.from), b = tilePos(s.hop.to);
        const f = clamp01(s.hop.f);
        p.group.position.lerpVectors(a, b, f);
        y += Math.sin(f * Math.PI) * 0.75;
        const dir = tmp.copy(b).sub(a);
        p.group.rotation.y = Math.atan2(dir.x, dir.z);
        const squash = f > 0.85 ? 1 - (f - 0.85) * 1.6 : 1 + Math.sin(f * Math.PI) * 0.08;
        p.body.scale.set(1 / Math.sqrt(squash), squash, 1 / Math.sqrt(squash));
      } else {
        const list = byTile[s.pos] || [t.id];
        const o = slotOffset(list.indexOf(t.id), list.length);
        p.group.position.copy(tilePos(s.pos)).add(o);
        p.group.rotation.y += (0 - p.group.rotation.y) * 0.15;
        const bob = t.id === actingId && !animating ? Math.abs(Math.sin(time * 3.2)) * 0.18 : 0;
        y += bob;
        p.body.scale.lerp(new THREE.Vector3(1, 1, 1), 0.2);
      }
      p.group.position.y = y;
    }

    // Anel e brilho da casa da equipe da vez
    tiles.forEach((tl, i) => { tl.base.material.emissiveIntensity = 0; tl.group.position.y = tl.pos.y; tl.group.scale.setScalar(1); });
    if (actingId && pawns.get(actingId)) {
      const team = S.teams.find((t) => t.id === actingId);
      const tl = tiles[Math.min(team.pos, tiles.length - 1)];
      if (!animating) {
        tl.base.material.emissiveIntensity = 0.25 + Math.sin(time * 4) * 0.15;
        ring.visible = true;
        ring.material.color.set(team.color);
        ring.position.copy(tl.pos).setY(0.2);
        ring.scale.setScalar(1 + Math.sin(time * 4) * 0.12);
      } else ring.visible = false;
    } else if (ring) ring.visible = false;
    // casa que acabou de receber o peão dá um pulinho
    if (mv && mvT > mv.dur - 300 && mvT < mv.dur + 300 && mv.path.length) {
      const tl = tiles[mv.path[mv.path.length - 1]];
      const f = (mvT - (mv.dur - 300)) / 600;
      tl.group.position.y = tl.pos.y + Math.sin(f * Math.PI) * 0.18;
    }

    // Dado
    if (mv && mv.kind === 'dice' && mvT < DICE_MS + 150) {
      if (lastDiceId !== mv.id) { lastDiceId = mv.id; opts.onDice?.(); }
      const r = rng(mv.id * 977 + mv.value);
      const fall = clamp01(mvT / 1250);
      const pawnAt = tilePos(mv.from);
      const land = tmp.copy(pawnAt).lerp(center, 0.35);
      dice.visible = true;
      // quique
      const bounce = Math.abs(Math.cos(fall * Math.PI * 2.5)) * (1 - fall) * 3.2;
      dice.position.set(land.x + (1 - fall) * 2.5, 0.65 + bounce, land.z + (1 - fall) * 1.5);
      const target = new THREE.Quaternion().setFromUnitVectors(faceNormals[diceFaces.indexOf(mv.value)], new THREE.Vector3(0, 1, 0));
      target.premultiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), r() * Math.PI * 2));
      const axis = new THREE.Vector3(r() - 0.5, r() - 0.5, r() - 0.5).normalize();
      const spin = new THREE.Quaternion().setFromAxisAngle(axis, (1 - ease(fall)) * Math.PI * 6);
      dice.quaternion.copy(spin).multiply(target);
      const fade = mvT > DICE_MS - 150 ? 1 - (mvT - (DICE_MS - 150)) / 300 : 1;
      dice.scale.setScalar(Math.max(0.01, fade) * 1.1);
    } else dice.visible = false;

    // Enfeites
    boardGroup.children.forEach((o) => {
      if (o.userData.spin) o.rotation.y = time * 0.8;
      if (o.userData.drift) o.position.x = o.userData.base + Math.sin(time * o.userData.drift) * 1.5;
    });
    boardGroup.traverse((o) => {
      if (o.userData.wave) {
        const pos = o.geometry.attributes.position;
        for (let i = 0; i < pos.count; i++) pos.setZ(i, Math.sin(pos.getX(i) * 6 + time * 5) * 0.05 * (pos.getX(i) + 0.35));
        pos.needsUpdate = true;
      }
    });

    // Câmera: visão geral que se aproxima um pouco de quem joga
    let focus = center.clone();
    // distância que cabe a ilha inteira na tela (mais longe em tela em pé)
    const fit = radius / Math.tan(THREE.MathUtils.degToRad(camera.fov / 2));
    let dist = fit * (camera.aspect < 1 ? 1.25 / camera.aspect : 0.95);
    if (actingId && pawns.get(actingId)) {
      const pp = pawns.get(actingId).group.position;
      focus.lerp(pp, animating ? 0.45 : 0.25);
      dist *= animating ? 0.85 : 0.97;
    }
    if (opts.zoom) dist *= opts.zoom;
    const sway = Math.sin(time * 0.25) * 0.08;
    const want = new THREE.Vector3(focus.x + Math.sin(sway) * dist * 0.3, dist * 0.82, focus.z + dist * 0.55);
    if (!camInit) { camTarget.copy(want); camFocus.copy(focus); camInit = true; }
    camTarget.lerp(want, 0.04);
    camFocus.lerp(focus, 0.05);
    camera.position.copy(camTarget);
    camera.lookAt(camFocus);
    renderer.render(scene, camera);
  }
  requestAnimationFrame(frame);

  return { update, resize };
}
