// Tabuleiro 3D do Mimicaço da Turma do Rawzinho (Three.js).
// Tudo que se mexe é calculado a partir do horário do servidor, então a TV e os celulares mostram o mesmo movimento.
import * as THREE from './vendor/three.module.min.js';
import { RoundedBoxGeometry } from './vendor/RoundedBoxGeometry.js';
import { GLTFLoader } from './vendor/GLTFLoader.js';
import { RoomEnvironment } from './vendor/RoomEnvironment.js';

// Cada nível é um mundo: cores da ilha, luz, enfeites e o Rawzinho que passeia por ali.
const THEMES = {
  kids: {
    hemi: [0xeaf6ff, 0x6aa848, 1.05], sun: [0xffe6b8, 2.6], exposure: 1.06,
    layers: [[0x62b83a, 0x9a6b3f], [0x5aa835, 0x7d5330], [0x8a5a33, 0x6b4426]],
    tufts: [0x5fb83a, 0x7ad24e, 0x4a9e30, 0x8fdc5a], fill: 0xd6ecff, rim: 0xfff2c8, env: 0.22,
    stone: 0xf3e3c3, deco: 'garden', clouds: true, mascots: [['model/rawzinho.glb', 2.0], ['model/burrinho.glb', 1.9]],
  },
  familia: {
    hemi: [0xffe9cc, 0x3aa7b8, 1.0], sun: [0xffcf8a, 2.4], exposure: 1.0,
    layers: [[0xe8c376, 0xd9ab5e], [0x7ccf4a, 0xc79a5a], [0x9a6b3f, 0x7d5330]],
    stone: 0xffffff, deco: 'tropical', clouds: true, water: 0x29c3d6, mascots: [['model/rawzinho.glb', 2.0], ['model/burrinho.glb', 1.9]], fill: 0xffe2c0, rim: 0xffb070,
  },
  adulto: {
    hemi: [0xffd2b0, 0x3c5a40, 1.15], sun: [0xffb07a, 2.5], exposure: 1.04,
    layers: [[0x5f9a3a, 0x6a4430], [0x4a7a32, 0x3f2a22], [0x2c1e1a, 0x1e1412]],
    tufts: [0x4a7a32, 0x5f9a3a, 0x3a6428], stone: 0x8a7a6e, deco: 'jurassic', clouds: false, lava: true, mascots: [['model/rawadulto.glb', 2.6], ['model/burrinho.glb', 2.0]], fill: 0xb8c8ff, rim: 0xff7a3a, env: 0.25,
  },
};
export const CAT_FACES = ['acao', 'objeto', 'gente', 'bicho', 'lugar', 'casa'];

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

  // luz ambiente de estúdio (reflexos suaves) + céu/chão + sol + luz de preenchimento e contorno
  const pmrem = new THREE.PMREMGenerator(renderer);
  scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
  scene.environmentIntensity = 0.45;
  const hemi = new THREE.HemisphereLight(0xfff4d6, 0x5f9e3a, 1.25);
  scene.add(hemi);
  const fill = new THREE.DirectionalLight(0xdfeaff, 0.45);
  fill.position.set(6, 8, 14);
  scene.add(fill);
  const rim = new THREE.DirectionalLight(0xffffff, 0.9);
  rim.position.set(4, 6, -12);
  scene.add(rim);
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
  // Textura pintada à mão para o chão da ilha: grama com tufinhos ou terra com camadas e pedrinhas.
  const groundCache = {};
  function groundTexture(hex, kind) {
    const key = hex + kind;
    if (groundCache[key]) return groundCache[key];
    const c = document.createElement('canvas');
    c.width = c.height = 256;
    const g = c.getContext('2d');
    const base = new THREE.Color(hex);
    const shade = (k) => { const q = base.clone(); q.offsetHSL(0, 0, k); return q.getStyle(); };
    g.fillStyle = base.getStyle(); g.fillRect(0, 0, 256, 256);
    let seed = 7;
    const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
    // manchas suaves
    for (let i = 0; i < 40; i++) {
      const x = rnd() * 256, y = rnd() * 256, r = 18 + rnd() * 40;
      const grd = g.createRadialGradient(x, y, 0, x, y, r);
      grd.addColorStop(0, shade(rnd() < 0.5 ? 0.03 : -0.03)); grd.addColorStop(1, 'rgba(0,0,0,0)');
      g.fillStyle = grd;
      for (const dx of [-256, 0, 256]) for (const dy of [-256, 0, 256]) { g.save(); g.translate(dx, dy); g.fillRect(x - r, y - r, r * 2, r * 2); g.restore(); }
    }
    if (kind === 'grass') {
      g.lineCap = 'round';
      for (let i = 0; i < 520; i++) {
        const x = rnd() * 256, y = rnd() * 256, l = 3 + rnd() * 5, a = -Math.PI / 2 + (rnd() - 0.5) * 0.9;
        g.strokeStyle = shade(rnd() < 0.4 ? 0.03 + rnd() * 0.03 : -0.04 - rnd() * 0.04);
        g.lineWidth = 1 + rnd() * 1.4;
        g.beginPath(); g.moveTo(x, y); g.lineTo(x + Math.cos(a) * l, y + Math.sin(a) * l); g.stroke();
      }
      for (let i = 0; i < 14; i++) { // florzinhas miúdas
        g.fillStyle = ['#fff6d8', '#ffe066', '#ffb3d1'][i % 3];
        const x = rnd() * 256, y = rnd() * 256;
        for (let k = 0; k < 4; k++) { g.beginPath(); g.arc(x + Math.cos(k * 1.57) * 1.6, y + Math.sin(k * 1.57) * 1.6, 1.3, 0, 7); g.fill(); }
      }
    } else if (kind === 'sand') {
      for (let i = 0; i < 2600; i++) { g.fillStyle = shade((rnd() - 0.5) * 0.14); g.fillRect(rnd() * 256, rnd() * 256, 1.4, 1.4); }
    } else { // terra: faixas horizontais e pedrinhas
      for (let y = 0; y < 256; y += 10 + rnd() * 18) {
        g.fillStyle = shade((rnd() - 0.5) * 0.08);
        g.beginPath(); g.moveTo(0, y);
        for (let x = 0; x <= 256; x += 32) g.lineTo(x, y + Math.sin(x * 0.05 + y) * 3);
        g.lineTo(256, y + 6); g.lineTo(0, y + 6); g.fill();
      }
      for (let i = 0; i < 70; i++) {
        const x = rnd() * 256, y = rnd() * 256, r = 1.5 + rnd() * 3.5;
        g.fillStyle = shade(-0.1); g.beginPath(); g.ellipse(x + 0.8, y + 0.8, r, r * 0.7, 0, 0, 7); g.fill();
        g.fillStyle = shade(0.1); g.beginPath(); g.ellipse(x, y, r, r * 0.7, 0, 0, 7); g.fill();
      }
    }
    const t = new THREE.CanvasTexture(c);
    t.colorSpace = THREE.SRGBColorSpace;
    t.wrapS = t.wrapT = THREE.RepeatWrapping;
    t.repeat.set(kind === 'dirt' ? 0.45 : 0.28, kind === 'dirt' ? 0.45 : 0.28);
    t.anisotropy = 8;
    groundCache[key] = t;
    return t;
  }

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
      g.strokeText(label, 128, 92); g.fillText(label, 128, 92);
      g.font = '34px "Lilita One", sans-serif';
      g.lineWidth = 7; g.strokeText('PULO!', 128, 140); g.fillText('PULO!', 128, 140);
    }
    g.restore();
    if (num) { // número grande, legível de longe
      g.fillStyle = '#ffffff';
      g.beginPath(); g.arc(128, 196, 50, 0, Math.PI * 2); g.fill();
      g.fillStyle = '#123a7a';
      g.beginPath(); g.arc(128, 196, 43, 0, Math.PI * 2); g.fill();
      g.fillStyle = '#fff';
      g.font = `${num >= 10 ? 54 : 64}px "Lilita One", sans-serif`;
      g.textAlign = 'center'; g.textBaseline = 'middle';
      g.fillText(String(num), 128, 200);
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

  // Dado de categoria: cinco categorias e a estrela (usa a categoria da casa)
  function catFaceTexture(face, categories) {
    const c = document.createElement('canvas');
    c.width = c.height = 128;
    const g = c.getContext('2d');
    const cat = categories?.[face];
    g.fillStyle = cat ? cat.color : '#ffd23d';
    g.fillRect(0, 0, 128, 128);
    g.fillStyle = 'rgba(255,255,255,.9)';
    g.beginPath(); g.arc(64, 52, 36, 0, Math.PI * 2); g.fill();
    g.textAlign = 'center'; g.textBaseline = 'middle';
    g.font = '44px sans-serif';
    g.fillStyle = '#123a7a';
    g.fillText(cat ? cat.emoji : '⭐', 64, 54);
    g.font = '22px "Lilita One", sans-serif';
    g.fillStyle = '#fff';
    g.lineWidth = 5; g.strokeStyle = 'rgba(18,58,122,.85)';
    const label = cat ? cat.name.split(' ')[0].toUpperCase() : 'CASA';
    g.strokeText(label, 64, 106); g.fillText(label, 64, 106);
    const t = new THREE.CanvasTexture(c);
    t.colorSpace = THREE.SRGBColorSpace;
    return t;
  }
  const catDice = new THREE.Mesh(new RoundedBoxGeometry(0.95, 0.95, 0.95, 5, 0.18),
    CAT_FACES.map(() => new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.35 })));
  catDice.castShadow = true;
  catDice.visible = false;
  scene.add(catDice);
  let catDiceReady = false;

  // ---------- Partículas (poeira, brilhos, fogos, brasas) ----------
  const partGeo = new THREE.SphereGeometry(0.06, 6, 4);
  const parts = [];
  function burst(pos, { n = 12, colors = [0xffffff], speed = 2, up = 2, gravity = 6, life = 0.8, size = 1, spread = 1 } = {}) {
    for (let i = 0; i < n; i++) {
      if (parts.length > (low ? 160 : 320)) parts.shift().mesh.removeFromParent();
      const mat = new THREE.MeshBasicMaterial({ color: colors[i % colors.length], transparent: true });
      const m = new THREE.Mesh(partGeo, mat);
      m.position.copy(pos);
      m.scale.setScalar(size * (0.6 + Math.random() * 0.8));
      const a = Math.random() * Math.PI * 2;
      const sp = speed * (0.4 + Math.random() * 0.6);
      scene.add(m);
      parts.push({ mesh: m, v: new THREE.Vector3(Math.cos(a) * sp * spread, up * (0.5 + Math.random() * 0.8), Math.sin(a) * sp * spread),
        g: gravity, life, t: 0, s0: m.scale.x });
    }
  }
  function stepParticles(dt) {
    for (let i = parts.length - 1; i >= 0; i--) {
      const p = parts[i];
      p.t += dt;
      if (p.t >= p.life) { p.mesh.removeFromParent(); p.mesh.material.dispose(); parts.splice(i, 1); continue; }
      p.v.y -= p.g * dt;
      p.mesh.position.addScaledVector(p.v, dt);
      const k = 1 - p.t / p.life;
      p.mesh.material.opacity = Math.min(1, k * 1.6);
      p.mesh.scale.setScalar(p.s0 * (0.4 + k * 0.6));
    }
  }
  let shake = 0;

  // ---------- Rawzinho 3D que passeia pelo cenário ----------
  const loader = new GLTFLoader();
  const mascotCache = {};
  let mascots = []; // [{ root, mixer, action, url, big, st }]
  function loadMascot(url, height) {
    if (!mascotCache[url]) {
      mascotCache[url] = loader.loadAsync(url).then((gltf) => {
        const root = gltf.scene;
        root.traverse((o) => { if (o.isMesh) { o.castShadow = true; o.frustumCulled = false; } });
        const box = new THREE.Box3().setFromObject(root);
        const h = box.max.y - box.min.y || 1;
        const wrap = new THREE.Group();
        root.scale.setScalar(height / h);
        root.position.y = -box.min.y * (height / h);
        wrap.add(root);
        const mixer = new THREE.AnimationMixer(root);
        const action = gltf.animations[0] ? mixer.clipAction(gltf.animations[0]) : null;
        action?.play();
        return { root: wrap, mixer, action, url };
      }).catch(() => null);
    }
    return mascotCache[url];
  }

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

  // ---------- Enfeites de cada mundo ----------
  let islandBox = null;
  let volcano = null;
  // ---------- Modelos do cenário (Envato), carregados uma vez e clonados ----------
  const PROPS = {
    hibisco: { h: 1.1 }, flor_azul: { h: 0.8 }, flor_rosa: { h: 1.0 },
    palmeira: { h: 2.6 }, coqueiro: { h: 2.4, recolor: true }, bananeira: { h: 1.9, recolor: true },
    samambaia: { h: 0.75, recolor: true, bush: true }, vulcao: { h: 4.2 },
    arvore_rosa: { h: 1.7, recolor: true }, arvore_redonda: { h: 1.7 }, carvalho: { h: 1.8 },
    pinheiro: { h: 1.6, recolor: true, leaf: 0x2f8f45 }, tufo: { h: 0.45 }, toco: { h: 0.42 }, cogumelo: { h: 0.62 },
  };
  const propCache = {};
  const greenMat = new THREE.MeshStandardMaterial({ color: 0x4caf3a, roughness: 0.7, side: THREE.DoubleSide });
  const trunkMat2 = new THREE.MeshStandardMaterial({ color: 0x9a6a3e, roughness: 0.9 });
  function loadProp(name) {
    if (!propCache[name]) {
      const cfg = PROPS[name];
      propCache[name] = loader.loadAsync(`model/cenario/${name}.glb`).then((gltf) => {
        const root = gltf.scene;
        root.updateMatrixWorld(true);
        const all = new THREE.Box3().setFromObject(root);
        const W = Math.max(all.max.x - all.min.x, all.max.z - all.min.z);
        const kill = [];
        root.traverse((o) => {
          if (!o.isMesh) return;
          const b = new THREE.Box3().setFromObject(o);
          const sz = b.getSize(new THREE.Vector3());
          // tira o "chão" que alguns modelos trazem
          if (sz.y < 0.02 * Math.max(sz.x, sz.z) && Math.max(sz.x, sz.z) > 0.5 * W) { kill.push(o); return; }
          o.castShadow = true;
          if (cfg.recolor) {
            const c = o.material?.color;
            if (!c || (c.r > 0.9 && c.g > 0.9 && c.b > 0.9)) {
              const narrow = Math.max(sz.x, sz.z) < sz.y * 0.4;
              o.material = narrow && !cfg.bush ? trunkMat2 : cfg.leaf ? new THREE.MeshStandardMaterial({ color: cfg.leaf, roughness: 0.75 }) : greenMat;
            }
          }
        });
        kill.forEach((o) => o.removeFromParent());
        root.updateMatrixWorld(true);
        const box = new THREE.Box3().setFromObject(root);
        const k = cfg.h / (box.max.y - box.min.y || 1);
        const c = box.getCenter(new THREE.Vector3());
        const wrap = new THREE.Group();
        root.scale.multiplyScalar(k);
        root.position.set(-c.x * k, -box.min.y * k, -c.z * k);
        if (cfg.bush) {
          // a folhagem é um galho só: junta alguns girados para virar uma moita
          for (let i = 0; i < 4; i++) {
            const b = root.clone();
            const g = new THREE.Group();
            g.add(b);
            g.rotation.set(0.35, (i / 4) * Math.PI * 2, 0);
            wrap.add(g);
          }
        } else wrap.add(root);
        return wrap;
      }).catch(() => null);
    }
    return propCache[name];
  }
  function placeProp(name, x, z, scale = 1, rotY = 0, y = -0.2) {
    const token = boardGroup;
    loadProp(name).then((tpl) => {
      if (!tpl || token !== boardGroup) return;
      const o = tpl.clone();
      o.position.set(x, y, z);
      o.scale.setScalar(scale);
      o.rotation.y = rotY;
      o.userData.sway = name === 'vulcao' ? undefined : Math.random() * 6;
      if (name === 'vulcao') delete o.userData.sway;
      boardGroup.add(o);
    });
  }

  let flyers = [];
  // bichinhos voando: borboletas no jardim, gaivotas na ilha, pterodáctilos no vulcão
  function makeFlyer(kind, color) {
    const g = new THREE.Group();
    const wingMat = new THREE.MeshStandardMaterial({ color, side: THREE.DoubleSide, roughness: 0.6 });
    const size = kind === 'ptero' ? 0.9 : kind === 'bird' ? 0.45 : 0.18;
    const shape = new THREE.Shape();
    if (kind === 'butterfly') { shape.moveTo(0, 0); shape.bezierCurveTo(0.2, 0.35, 1, 0.5, 1, 0.1); shape.bezierCurveTo(1, -0.3, 0.4, -0.5, 0, 0); }
    else { shape.moveTo(0, 0.12); shape.lineTo(1, -0.05); shape.lineTo(0.55, -0.12); shape.lineTo(0, -0.15); }
    const geo = new THREE.ShapeGeometry(shape);
    geo.rotateX(-Math.PI / 2);
    geo.scale(size, size, size);
    const L = new THREE.Mesh(geo, wingMat), R = new THREE.Mesh(geo, wingMat);
    R.scale.x = -1;
    const body = new THREE.Mesh(new THREE.CapsuleGeometry(size * 0.08, size * 0.5, 4, 8),
      new THREE.MeshStandardMaterial({ color: kind === 'bird' ? 0xffffff : 0x3a2a24 }));
    body.rotation.x = Math.PI / 2;
    g.add(L, R, body);
    if (kind === 'ptero') {
      const beak = new THREE.Mesh(new THREE.ConeGeometry(size * 0.06, size * 0.5, 6), body.material);
      beak.rotation.x = Math.PI / 2; beak.position.z = size * 0.45;
      const crest = new THREE.Mesh(new THREE.ConeGeometry(size * 0.05, size * 0.35, 6), body.material);
      crest.rotation.x = -Math.PI / 2.5; crest.position.set(0, size * 0.08, -size * 0.05);
      g.add(beak, crest);
    }
    g.traverse((o) => { o.castShadow = true; });
    g.userData = { L, R, kind };
    return g;
  }
  function decorate(TH, r, near, x0, z0, w, h) {
    const taken = []; // [x, z, raio] dos enfeites grandes, pra não ficarem um dentro do outro
    volcano = null;
    flyers = [];
    const kind = TH.deco === 'garden' ? 'butterfly' : TH.deco === 'tropical' ? 'bird' : 'ptero';
    const colors = kind === 'butterfly' ? [0xff6fb5, 0xffd23d, 0x5ec8ff, 0xa26bff, 0xff8a3d] : kind === 'bird' ? [0xffffff, 0xf2f2f2] : [0x8a5a44, 0x6a4a3a];
    const n = kind === 'butterfly' ? (low ? 5 : 9) : kind === 'bird' ? (low ? 3 : 5) : (low ? 2 : 3);
    for (let i = 0; i < n; i++) {
      const f = makeFlyer(kind, colors[i % colors.length]);
      f.userData.cx = x0 + w * (0.2 + r() * 0.6);
      f.userData.cz = z0 + h * (0.2 + r() * 0.6);
      f.userData.rad = kind === 'butterfly' ? 0.6 + r() * 1.4 : 2 + r() * Math.max(w, h) * 0.35;
      f.userData.alt = kind === 'butterfly' ? 0.4 + r() * 0.8 : kind === 'bird' ? 2.6 + r() * 1.2 : 3.4 + r() * 1.5;
      f.userData.sp = (kind === 'butterfly' ? 0.5 : 0.25) * (0.7 + r() * 0.6) * (r() < 0.5 ? 1 : -1);
      f.userData.ph = r() * 6.28;
      boardGroup.add(f);
      flyers.push(f);
    }
    if (TH.tufts) grassTufts(TH.tufts);
    if (TH.deco === 'garden') {
      garden();
      // árvores de verdade na borda do jardim
      const trees = ['arvore_redonda', 'carvalho', 'arvore_rosa', 'pinheiro', 'arvore_redonda', 'carvalho'];
      // só nas bordas de trás e dos lados, pra não tampar as casas
      for (let n = 0; n < (low ? 7 : 12); n++) {
        const p = edgeSpot(1.3, 0.7);
        if (p) placeProp(trees[n % trees.length], p[0], p[1], 0.7 + r() * 0.35, r() * 6);
      }
      for (let i = 0; i < (low ? 3 : 6); i++) {
        const p = spot(0.8, 0, 0.35);
        if (p) placeProp(i % 3 === 2 ? 'toco' : 'cogumelo', p[0], p[1], 0.75 + r() * 0.5, r() * 6);
      }
      for (let i = 0; i < (low ? 8 : 18); i++) {
        const p = spot(0.7);
        if (p) placeProp('tufo', p[0], p[1], 0.7 + r() * 0.7, r() * 6);
      }
      for (let i = 0; i < (low ? 8 : 16); i++) {
        const p = spot(0.9);
        if (p) placeProp(['hibisco', 'flor_azul', 'flor_rosa'][i % 3], p[0], p[1], 0.8 + r() * 0.6, r() * 6);
      }
    } else if (TH.deco === 'tropical') {
      tropical();
      for (let i = 0; i < (low ? 5 : 8); i++) {
        const p = edgeSpot(1.3, 0.8);
        if (p) placeProp(['palmeira', 'coqueiro', 'bananeira'][i % 3], p[0], p[1], 0.7 + r() * 0.35, r() * 6);
      }
      for (let i = 0; i < 8; i++) {
        const p = spot(0.9);
        if (p) placeProp(i % 2 ? 'hibisco' : 'flor_rosa', p[0], p[1], 0.8 + r() * 0.4, r() * 6);
      }
    } else {
      jurassic();
      for (let i = 0; i < (low ? 8 : 14); i++) {
        const p = spot(1.0, 0.5);
        if (p) placeProp('samambaia', p[0], p[1], 0.9 + r() * 0.8, r() * 6);
      }
    }

    // Tufinhos de grama espalhados (um só draw call)
    function grassTufts(colors) {
      const blade = new THREE.ConeGeometry(0.035, 0.22, 4);
      blade.translate(0, 0.11, 0);
      const n = low ? 120 : 260;
      const mesh = new THREE.InstancedMesh(blade, new THREE.MeshStandardMaterial({ roughness: 0.85 }), n);
      const m = new THREE.Matrix4(), q = new THREE.Quaternion(), e = new THREE.Euler(), col = new THREE.Color();
      let k = 0;
      for (let tries = 0; k < n && tries < n * 6; tries++) {
        const cx = x0 + 0.3 + r() * (w - 0.6), cz = z0 + 0.3 + r() * (h - 0.6);
        if (near(cx, cz, 0.62)) continue;
        for (let b = 0; b < 5 && k < n; b++, k++) {
          e.set((r() - 0.5) * 0.7, r() * 6.28, (r() - 0.5) * 0.7);
          q.setFromEuler(e);
          const sc = 0.6 + r() * 0.8;
          m.compose(new THREE.Vector3(cx + (r() - 0.5) * 0.12, -0.25, cz + (r() - 0.5) * 0.12), q, new THREE.Vector3(sc, sc * (0.8 + r() * 0.6), sc));
          mesh.setMatrixAt(k, m);
          mesh.setColorAt(k, col.set(colors[Math.floor(r() * colors.length)]));
        }
      }
      mesh.count = k;
      mesh.castShadow = false;
      mesh.receiveShadow = true;
      boardGroup.add(mesh);
    }

    function spot(minD, edgeBias = 0, room = 0) {
      for (let k = 0; k < 80; k++) {
        const x = x0 + 0.4 + r() * (w - 0.8), z = z0 + 0.4 + r() * (h - 0.8);
        if (near(x, z, minD)) continue;
        if (room && taken.some(([tx, tz, tr]) => (tx - x) ** 2 + (tz - z) ** 2 < (tr + room) ** 2)) continue;
        const edge = Math.min(x - x0, x0 + w - x, z - z0, z0 + h - z);
        if (edgeBias && edge > 1.6 && r() < edgeBias) continue;
        if (room) taken.push([x, z, room]);
        return [x, z];
      }
      return null;
    }

    // lugar na borda de trás ou dos lados (enfeite alto não tampa as casas)
    function edgeSpot(minD, room) {
      for (let i = 0; i < 80; i++) {
        const p = spot(minD, 0, room);
        if (!p) continue;
        const edge = Math.min(p[0] - x0, x0 + w - p[0], p[1] - z0);
        if (edge > 1.1 || p[1] > z0 + h * 0.7) { taken.pop(); continue; }
        return p;
      }
      return null;
    }

    function garden() {
      const leafMats = [0x4fae3b, 0x67c24a, 0x3f9a3a].map((c) => new THREE.MeshStandardMaterial({ color: c, roughness: 0.75 }));
      const trunkMat = new THREE.MeshStandardMaterial({ color: 0x8a5a33, roughness: 0.9 });
      const blobGeo = new THREE.IcosahedronGeometry(0.4, 2);
      { // amassa um pouco a bolha pra não ficar perfeita
        const pa = blobGeo.attributes.position;
        for (let i = 0; i < pa.count; i++) {
          const v = new THREE.Vector3().fromBufferAttribute(pa, i);
          v.multiplyScalar(1 + Math.sin(v.x * 9) * Math.cos(v.z * 8) * 0.06 + Math.sin(v.y * 11) * 0.04);
          pa.setXYZ(i, v.x, v.y, v.z);
        }
        blobGeo.computeVertexNormals();
      }
      const flowerColors = [0xff6fb5, 0xffd23d, 0xffffff, 0xa26bff, 0xff8a3d, 0x5ec8ff];
      const nTrees = low ? 2 : 4;
      let placed = 0, tries = 0;
      while (placed < nTrees && tries++ < 400) {
        const x = x0 + 0.5 + r() * (w - 1), z = z0 + 0.5 + r() * (h - 1);
        if (near(x, z, 1.2)) continue;
        const edge = Math.min(x - x0, x0 + w - x, z - z0, z0 + h - z);
        if (edge > 1.6 && r() > 0.25) continue; // mais árvores na borda
        const t = new THREE.Group();
        const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.12, 0.62, 8), trunkMat);
        trunk.position.y = 0.06;
        t.add(trunk);
        const round = r() > 0.35;
        if (round) { // copa fofinha feita de várias bolhas
          const mat = leafMats[placed % 3];
          const blobs = [[0, 0.62, 0, 0.36], [0.2, 0.52, 0.08, 0.26], [-0.18, 0.54, -0.06, 0.27], [0.04, 0.84, -0.04, 0.25], [-0.04, 0.5, 0.2, 0.22]];
          for (const [bx, by, bz, br] of blobs) {
            const b = new THREE.Mesh(blobGeo, mat);
            b.position.set(bx, by, bz);
            b.scale.setScalar(br / 0.4);
            t.add(b);
          }
        } else { // pinheirinho em andares
          for (let k = 0; k < 3; k++) {
            const c = new THREE.Mesh(new THREE.ConeGeometry(0.42 - k * 0.1, 0.5, 12), leafMats[(placed + k) % 3]);
            c.position.y = 0.45 + k * 0.26;
            t.add(c);
          }
        }
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

    }

    function palm(x, z, s) {
      const g = new THREE.Group();
      const trunkMat = new THREE.MeshStandardMaterial({ color: 0xb07a45, roughness: 0.9 });
      const lean = (r() - 0.5) * 0.5;
      let y = 0;
      for (let i = 0; i < 6; i++) {
        const seg = new THREE.Mesh(new THREE.CylinderGeometry(0.075 - i * 0.006, 0.09 - i * 0.006, 0.26, 8), trunkMat);
        seg.position.set(lean * i * i * 0.03, y + 0.13, 0);
        g.add(seg);
        y += 0.24;
      }
      const top = new THREE.Vector3(lean * 36 * 0.03, y, 0);
      const leafMat = new THREE.MeshStandardMaterial({ color: 0x3fae3b, roughness: 0.7, side: THREE.DoubleSide });
      for (let i = 0; i < 7; i++) {
        const leaf = new THREE.Mesh(new THREE.ConeGeometry(0.13, 0.9, 4, 1, true), leafMat);
        leaf.geometry.translate(0, 0.45, 0);
        leaf.scale.z = 0.3;
        leaf.position.copy(top);
        leaf.rotation.set(0, (i / 7) * Math.PI * 2, 1.9);
        leaf.rotation.order = 'YXZ';
        g.add(leaf);
      }
      const coco = new THREE.MeshStandardMaterial({ color: 0x6b4426 });
      for (let i = 0; i < 3; i++) {
        const c = new THREE.Mesh(new THREE.SphereGeometry(0.06, 8, 6), coco);
        c.position.copy(top).add(new THREE.Vector3(Math.cos(i * 2.1) * 0.08, -0.08, Math.sin(i * 2.1) * 0.08));
        g.add(c);
      }
      g.traverse((o) => { o.castShadow = true; });
      g.position.set(x, -0.2, z);
      g.scale.setScalar(s);
      g.userData.sway = r() * 6;
      boardGroup.add(g);
    }

    function tropical() {
      for (let i = 0; i < (low ? 2 : 4); i++) {
        const p = edgeSpot(1.3, 0.8);
        if (p) palm(p[0], p[1], 0.9 + r() * 0.4);
      }
      const hib = [0xff4f7a, 0xffb02e, 0xff6fb5, 0xffffff];
      const fg = new THREE.SphereGeometry(0.08, 8, 6);
      for (let i = 0; i < (low ? 40 : 80); i++) {
        const p = spot(0.85);
        if (!p) continue;
        const f = new THREE.Mesh(fg, new THREE.MeshStandardMaterial({ color: hib[i % hib.length] }));
        f.position.set(p[0], -0.2, p[1]);
        boardGroup.add(f);
      }
      // conchas e pedras de praia
      const shellMat = new THREE.MeshStandardMaterial({ color: 0xffd2c2, roughness: 0.5 });
      const rockMat = new THREE.MeshStandardMaterial({ color: 0xb5a89a, roughness: 0.9 });
      for (let i = 0; i < 14; i++) {
        const p = spot(1.0);
        if (!p) continue;
        const shell = i % 2 === 0;
        const m = new THREE.Mesh(shell ? new THREE.ConeGeometry(0.12, 0.08, 9) : new THREE.SphereGeometry(0.14 + r() * 0.1, 10, 7), shell ? shellMat : rockMat);
        m.position.set(p[0], shell ? -0.2 : -0.15, p[1]);
        m.rotation.y = r() * 6;
        m.castShadow = true;
        boardGroup.add(m);
      }
      // guarda-sol listrado
      const p = spot(1.6, 0.5);
      if (p) {
        const g = new THREE.Group();
        const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.03, 1.2, 6), new THREE.MeshStandardMaterial({ color: 0xffffff }));
        pole.position.y = 0.4;
        const c = document.createElement('canvas'); c.width = 128; c.height = 8;
        const cg = c.getContext('2d');
        for (let i = 0; i < 8; i++) { cg.fillStyle = i % 2 ? '#ff4f7a' : '#ffffff'; cg.fillRect(i * 16, 0, 16, 8); }
        const tx = new THREE.CanvasTexture(c); tx.colorSpace = THREE.SRGBColorSpace;
        const top = new THREE.Mesh(new THREE.ConeGeometry(0.7, 0.3, 16, 1, true), new THREE.MeshStandardMaterial({ map: tx, side: THREE.DoubleSide }));
        top.position.y = 1.05;
        g.add(pole, top);
        g.traverse((o) => { o.castShadow = true; });
        g.position.set(p[0], -0.2, p[1]);
        boardGroup.add(g);
      }
    }

    function jurassic() {
      const fernMat = [0x2f6a2a, 0x3d7d33, 0x285a24].map((c) => new THREE.MeshStandardMaterial({ color: c, roughness: 0.8, side: THREE.DoubleSide }));
      for (let i = 0; i < (low ? 14 : 24); i++) {
        const p = spot(1.0, 0.5);
        if (!p) continue;
        const g = new THREE.Group();
        for (let k = 0; k < 6; k++) {
          const leaf = new THREE.Mesh(new THREE.ConeGeometry(0.1, 0.7, 4, 1, true), fernMat[k % 3]);
          leaf.geometry.translate(0, 0.35, 0);
          leaf.scale.z = 0.35;
          leaf.rotation.order = 'YXZ';
          leaf.rotation.set(0, (k / 6) * Math.PI * 2, 0.9);
          g.add(leaf);
        }
        g.traverse((o) => { o.castShadow = true; });
        g.position.set(p[0], -0.2, p[1]);
        g.scale.setScalar(0.8 + r() * 0.7);
        boardGroup.add(g);
      }
      // árvores pré-históricas altas
      const trunkMat = new THREE.MeshStandardMaterial({ color: 0x5a3e2a, roughness: 0.95 });
      const crownMat = new THREE.MeshStandardMaterial({ color: 0x2c5a26, roughness: 0.9, flatShading: true });
      for (let i = 0; i < (low ? 6 : 10); i++) {
        const p = spot(1.4, 0.85);
        if (!p) continue;
        const g = new THREE.Group();
        const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.14, 1.6, 7), trunkMat);
        trunk.position.y = 0.6;
        const crown = new THREE.Mesh(new THREE.SphereGeometry(0.55, 8, 5), crownMat);
        crown.scale.y = 0.45;
        crown.position.y = 1.45;
        g.add(trunk, crown);
        g.traverse((o) => { o.castShadow = true; });
        g.position.set(p[0], -0.2, p[1]);
        g.scale.setScalar(0.8 + r() * 0.5);
        boardGroup.add(g);
      }
      // pedras e rachaduras de lava
      const rockMat = new THREE.MeshStandardMaterial({ color: 0x3a302c, roughness: 0.95, flatShading: true });
      const lavaMat = new THREE.MeshStandardMaterial({ color: 0xff5a1a, emissive: 0xff4a0a, emissiveIntensity: 1.6 });
      for (let i = 0; i < 12; i++) {
        const p = spot(0.95);
        if (!p) continue;
        if (i % 3 === 0) {
          const crack = new THREE.Mesh(new THREE.BoxGeometry(0.7 + r() * 0.6, 0.02, 0.07), lavaMat);
          crack.position.set(p[0], -0.19, p[1]);
          crack.rotation.y = r() * 6;
          crack.userData.glow = r() * 6;
          boardGroup.add(crack);
        } else {
          const m = new THREE.Mesh(new THREE.DodecahedronGeometry(0.2 + r() * 0.25), rockMat);
          m.position.set(p[0], -0.1, p[1]);
          m.castShadow = true;
          boardGroup.add(m);
        }
      }
      // ossinhos de dinossauro
      const boneMat = new THREE.MeshStandardMaterial({ color: 0xf2ead8 });
      for (let i = 0; i < 3; i++) {
        const p = spot(1.0);
        if (!p) continue;
        const b = new THREE.Group();
        const shaft = new THREE.Mesh(new THREE.CylinderGeometry(0.035, 0.035, 0.4, 6), boneMat);
        shaft.rotation.z = Math.PI / 2;
        b.add(shaft);
        [-1, 1].forEach((sx) => [-1, 1].forEach((sz) => {
          const k = new THREE.Mesh(new THREE.SphereGeometry(0.05, 8, 6), boneMat);
          k.position.set(0.2 * sx, 0, 0.035 * sz);
          b.add(k);
        }));
        b.position.set(p[0], -0.16, p[1]);
        b.rotation.y = r() * 6;
        boardGroup.add(b);
      }
      // vulcão atrás da ilha, soltando fumaça e brasas
      const v = new THREE.Group();
      const cone = new THREE.Mesh(new THREE.CylinderGeometry(0.6, 3.2, 3.6, 18, 4, true),
        new THREE.MeshStandardMaterial({ color: 0x3a2a24, roughness: 1, flatShading: true }));
      cone.position.y = 1.8;
      const lava = new THREE.Mesh(new THREE.CircleGeometry(0.6, 18), lavaMat);
      lava.rotation.x = -Math.PI / 2;
      lava.position.y = 3.55;
      for (let k = 0; k < 4; k++) {
        const flow = new THREE.Mesh(new THREE.BoxGeometry(0.12, 2.6, 0.04), lavaMat);
        const a = -0.6 + k * 0.4;
        flow.position.set(Math.sin(a) * 1.55, 2.0, Math.cos(a) * 1.55);
        flow.lookAt(0, 2.0, 0);
        flow.rotateX(-0.6);
        v.add(flow);
      }
      cone.visible = false; lava.visible = false; // o vulcão de verdade vem do modelo
      v.children.forEach((c) => { if (c.isMesh) c.visible = false; });
      v.add(cone, lava);
      loadProp('vulcao').then((tpl) => { if (tpl && volcano === v) { const m = tpl.clone(); m.scale.setScalar(1 / 0.75 * 0.9); v.add(m); } });
      const glow = new THREE.PointLight(0xff5a1a, 18, 14, 1.6);
      glow.position.y = 4;
      v.add(glow);
      v.position.set(x0 + w + 2.2, -1.6, z0 - 1.2);
      v.scale.setScalar(0.75);
      v.userData.light = glow;
      boardGroup.add(v);
      volcano = v;
    }
  }

  function buildBoard(board, categories, level) {
    const TH = THEMES[level] || THEMES.kids;
    hemi.color.set(TH.hemi[0]); hemi.groundColor.set(TH.hemi[1]); hemi.intensity = TH.hemi[2];
    sun.color.set(TH.sun[0]); sun.intensity = TH.sun[1];
    renderer.toneMappingExposure = TH.exposure;
    fill.color.set(TH.fill || 0xdfeaff);
    rim.color.set(TH.rim || 0xffffff);
    scene.environmentIntensity = TH.env ?? 0.18;
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
      const kindOf = (c) => { const q = new THREE.Color(c); return q.g > q.r * 1.15 ? 'grass' : q.r > 0.6 ? 'sand' : 'dirt'; };
      const kindTop = kindOf(color);
      const m = new THREE.Mesh(geo, [
        // grama em cor lisa: as casas se destacam melhor
        kindTop !== 'dirt' ? new THREE.MeshStandardMaterial({ color, roughness: 0.95 }) : new THREE.MeshStandardMaterial({ map: groundTexture(color, kindTop), roughness: 0.92 }),
        new THREE.MeshStandardMaterial({ map: groundTexture(side, new THREE.Color(side).r > 0.6 ? 'sand' : 'dirt'), roughness: 0.95 })]);
      m.position.y = y;
      m.scale.set(scale, 1, scale);
      m.position.x = center.x * (1 - scale);
      m.position.z = center.z * (1 - scale);
      m.receiveShadow = true;
      boardGroup.add(m);
    };
    layer(0.5, TH.layers[0][0], TH.layers[0][1], -0.75, 1);
    layer(0.9, TH.layers[1][0], TH.layers[1][1], -1.95, 0.94);
    layer(0.8, TH.layers[2][0], TH.layers[2][1], -3.0, 0.82);
    islandBox = { x0, z0, w, h };

    // Mar em volta da ilha tropical
    if (TH.water) {
      // mar em volta que some aos poucos, pra emendar com o vídeo de fundo
      const ac = document.createElement('canvas'); ac.width = ac.height = 256;
      const ag = ac.getContext('2d');
      const grd = ag.createRadialGradient(128, 128, 40, 128, 128, 128);
      grd.addColorStop(0, '#fff'); grd.addColorStop(0.55, '#fff'); grd.addColorStop(1, '#000');
      ag.fillStyle = grd; ag.fillRect(0, 0, 256, 256);
      const water = new THREE.Mesh(new THREE.CircleGeometry(radius * 1.35, 64),
        new THREE.MeshStandardMaterial({ color: TH.water, roughness: 0.15, metalness: 0.1, transparent: true, opacity: 0.85, alphaMap: new THREE.CanvasTexture(ac), depthWrite: false }));
      water.rotation.x = -Math.PI / 2;
      water.position.set(center.x, -1.6, center.z);
      water.userData.water = true;
      water.receiveShadow = true;
      boardGroup.add(water);
      const foam = new THREE.Mesh(new THREE.RingGeometry(0.1, 1, 64), new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.5 }));
      foam.rotation.x = -Math.PI / 2;
      foam.scale.set(w * 0.56, h * 0.6, 1);
      foam.position.set(center.x, -1.55, center.z);
      foam.userData.foam = true;
      boardGroup.add(foam);
    }

    // Caminho de pedrinhas entre as casas
    const stoneMat = new THREE.MeshStandardMaterial({ color: TH.stone, roughness: 0.8 });
    for (let i = 0; i < positions.length - 1; i++) {
      const a = positions[i], b = positions[i + 1];
      const s = new THREE.Mesh(new THREE.CylinderGeometry(0.16, 0.18, 0.08, 12), stoneMat);
      s.position.copy(a).lerp(b, 0.5).setY(-0.2);
      s.receiveShadow = true;
      boardGroup.add(s);
    }

    // Casas
    const edgeMat = new THREE.MeshStandardMaterial({ color: 0x2a2550, roughness: 0.7 });
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
      // contorno escuro em volta da casa, pra destacar da grama
      const edge = new THREE.Mesh(new RoundedBoxGeometry(TILE * s + 0.12, 0.2, TILE * s + 0.12, 3, 0.16), edgeMat);
      edge.position.y = -0.1;
      g.add(edge);
      const top = new THREE.Mesh(new THREE.CircleGeometry(0.45 * s, 48),
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

    // Decoração de cada mundo (longe do caminho)
    const r = rng(board.length * 7919);
    const near = (x, z, d) => positions.some((p) => (p.x - x) ** 2 + (p.z - z) ** 2 < d * d);
    decorate(TH, r, near, x0, z0, w, h);

    // Nuvens fofas
    const cloudMat = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 1, transparent: true, opacity: 0.95 });
    for (let k = 0; k < (TH.clouds ? (low ? 3 : 5) : 0); k++) {
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
    ring = new THREE.Mesh(new THREE.TorusGeometry(0.5, 0.085, 12, 48), new THREE.MeshBasicMaterial({ color: 0xffffff }));
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
  let landedId = null;
  let catShownId = null;
  const camTarget = new THREE.Vector3();
  const camFocus = new THREE.Vector3();
  let camInit = false;

  function update(state, serverOffset = 0) {
    S = state;
    offset = serverOffset;
    const level = S.settings?.level || 'kids';
    const key = level + '|' + S.board.map((b) => b.type + (b.cat || '')).join(',');
    if (key !== boardKey) {
      boardKey = key;
      for (const [, p] of pawns) p.group.parent?.remove(p.group);
      pawns.clear();
      buildBoard(S.board, S.categories, level);
      camInit = false;
      setMascot(level);
    }
    if (!catDiceReady && S.categories) {
      catDiceReady = true;
      CAT_FACES.forEach((f, i) => { catDice.material[i].map = catFaceTexture(f, S.categories); catDice.material[i].needsUpdate = true; });
    }
    syncPawns(S.teams);
  }

  let mascotToken = 0;
  async function setMascot(level) {
    const TH = THEMES[level] || THEMES.kids;
    const token = ++mascotToken;
    mascots.forEach((m) => m.root.removeFromParent());
    mascots = [];
    TH.mascots.forEach(async ([url, h], i) => {
      const m = await loadMascot(url, h);
      if (!m || token !== mascotToken) return;
      m.big = url.includes('rawadulto');
      m.slot = i;
      m.st = { target: new THREE.Vector3(), wait: 1 + i * 2, mode: 'wander', look: null, cheer: 0, lastFollow: null, lastStomp: 0 };
      boardGroup.add(m.root);
      const p = randomSpot();
      m.root.position.copy(p);
      m.st.target.copy(p);
      mascots.push(m);
    });
  }

  // ponto livre na ilha, longe do caminho, para o Rawzinho passear
  function randomSpot() {
    const b = islandBox;
    for (let k = 0; k < 80; k++) {
      const x = b.x0 + b.w * 0.15 + Math.random() * b.w * 0.7, z = b.z0 + b.h * 0.35 + Math.random() * (b.h * 0.6 - 0.8);
      if (!tiles.some((t) => (t.pos.x - x) ** 2 + (t.pos.z - z) ** 2 < 0.8)) return new THREE.Vector3(x, -0.2, z);
    }
    return new THREE.Vector3(b.x0 + 0.8, -0.2, b.z0 + 0.8);
  }

  function stepMascots(dt, time, actingPos, moveId, animating) {
    for (const m of mascots) stepMascot(m, dt, time, actingPos, moveId, animating);
  }
  function stepMascot(mascot, dt, time, actingPos, moveId, animating) {
    const st = mascot.st;
    const root = mascot.root;
    // quando alguém anda, ele vai até perto do pino da vez para ver
    if (moveId && moveId !== st.lastFollow && actingPos) {
      st.lastFollow = moveId;
      const dir = new THREE.Vector3(root.position.x - actingPos.x, 0, root.position.z - actingPos.z);
      if (dir.lengthSq() < 0.01) dir.set(1, 0, 0);
      dir.normalize().applyAxisAngle(new THREE.Vector3(0, 1, 0), mascot.slot ? 1.1 : 0).multiplyScalar(mascot.big ? 1.9 : 1.4);
      st.target.set(actingPos.x + dir.x, -0.2, actingPos.z + dir.z);
      st.mode = 'watch';
      st.look = actingPos.clone();
      st.wait = 0;
    }
    const to = new THREE.Vector3(st.target.x - root.position.x, 0, st.target.z - root.position.z);
    const d = to.length();
    const speed = mascot.big ? 1.1 : 0.9;
    let walking = false;
    if (d > 0.08) {
      walking = true;
      root.position.addScaledVector(to.normalize(), Math.min(d, speed * dt));
      const want = Math.atan2(to.x, to.z);
      root.rotation.y += Math.atan2(Math.sin(want - root.rotation.y), Math.cos(want - root.rotation.y)) * Math.min(1, dt * 6);
      if (mascot.big && time - st.lastStomp > 0.55) { st.lastStomp = time; shake = Math.max(shake, 0.05); burst(root.position.clone().setY(-0.15), { n: 4, colors: [0x8a7a6e, 0x5a4a40], speed: 1, up: 0.8, gravity: 4, life: 0.5 }); }
    } else {
      st.wait -= dt;
      if (st.look) {
        const lk = new THREE.Vector3(st.look.x - root.position.x, 0, st.look.z - root.position.z);
        const want = Math.atan2(lk.x, lk.z);
        root.rotation.y += Math.atan2(Math.sin(want - root.rotation.y), Math.cos(want - root.rotation.y)) * Math.min(1, dt * 4);
      }
      if (st.wait <= 0 && !animating) {
        if (st.mode === 'watch') { st.mode = 'idle'; st.wait = 2.5 + Math.random() * 2; }
        else { st.mode = 'wander'; st.look = null; st.target.copy(randomSpot()); st.wait = 1.5 + Math.random() * 3; }
      }
    }
    if (mascot.action) mascot.action.timeScale = walking ? 1 : 0.0;
    if (!walking && mascot.action) mascot.action.time = 0; // parado em pé
    // sem animação no modelo: anda gingando
    const inner = mascot.root.children[0];
    if (!mascot.action && inner) {
      st.walkT = (st.walkT || 0) + (walking ? dt * 7 : 0);
      const k = walking ? 1 : 0;
      inner.rotation.z += ((Math.sin(st.walkT) * 0.12 * k) - inner.rotation.z) * 0.3;
      inner.rotation.x += ((walking ? 0.08 : 0) - inner.rotation.x) * 0.1;
      inner.userData.bob = Math.abs(Math.sin(st.walkT)) * 0.08 * k;
    }
    // pulinho de comemoração
    if (st.cheer > 0) {
      st.cheer -= dt;
      root.position.y = -0.2 + Math.abs(Math.sin(st.cheer * 9)) * (mascot.big ? 0.25 : 0.45);
    } else root.position.y = -0.2 + (walking ? (mascot.root.children[0]?.userData.bob || 0) : Math.sin(time * 2) * 0.015);
    mascot.mixer.update(dt);
  }
  function cheer() { mascots.forEach((m) => (m.st.cheer = 1.4)); }
  function celebrate(color) {
    const tl = tiles[tiles.length - 1].pos;
    burst(tl.clone().setY(2.5 + Math.random()).add(new THREE.Vector3((Math.random() - 0.5) * radius, 0, (Math.random() - 0.5) * radius * 0.6)),
      { n: 30, colors: [color, 0xffd23d, 0xffffff, 0xff6fb5, 0x5ec8ff], speed: 3.5, up: 1.5, gravity: 2.5, life: 1.6, size: 1.2 });
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
    const dt = Math.min(0.05, time - (frame.lt ?? time));
    frame.lt = time;
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
          if (hopKey !== lastHopKey) {
            lastHopKey = hopKey;
            opts.onHop?.(k, steps.length);
            if (k > 0) burst(tilePos(steps[k - 1]).clone().setY(0.2), { n: 6, colors: [0xf3e3c3, 0xffffff], speed: 1.2, up: 0.9, gravity: 5, life: 0.45 });
          }
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
    if (mv && mvT > mv.dur - 300 && mv.path.length && landedId !== mv.id && mvT < mv.dur + 1500) {
      landedId = mv.id;
      const team = S.teams.find((t) => t.id === mv.teamId);
      const at = tiles[mv.path[mv.path.length - 1]].pos.clone().setY(0.5);
      burst(at, { n: 26, colors: [team ? new THREE.Color(team.color).getHex() : 0xffffff, 0xffd23d, 0xffffff], speed: 2.4, up: 3, gravity: 7, life: 0.9 });
      shake = Math.max(shake, mv.jumped ? 0.18 : 0.08);
      opts.onLand?.(mv);
      cheer();
    }
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
    if (mv && mv.kind === 'dice' && mv.catFace && mvT < DICE_MS + 150) {
      const r = rng(mv.id * 131 + 7);
      const fall = clamp01((mvT - 120) / 1250);
      const pawnAt = tilePos(mv.from);
      const land = tmp.copy(pawnAt).lerp(center, 0.35);
      catDice.visible = true;
      const bounce = Math.abs(Math.cos(fall * Math.PI * 2.5)) * (1 - fall) * 3.2;
      catDice.position.set(land.x + 1.25 + (1 - fall) * 2.8, 0.65 + bounce, land.z + 0.5 + (1 - fall) * 1.2);
      const target = new THREE.Quaternion().setFromUnitVectors(faceNormals[CAT_FACES.indexOf(mv.catFace)], new THREE.Vector3(0, 1, 0));
      target.premultiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), -0.35 + r() * 0.2));
      const axis = new THREE.Vector3(r() - 0.5, r() - 0.5, r() - 0.5).normalize();
      catDice.quaternion.copy(new THREE.Quaternion().setFromAxisAngle(axis, (1 - ease(fall)) * Math.PI * 6)).multiply(target);
      const fade = mvT > DICE_MS - 150 ? 1 - (mvT - (DICE_MS - 150)) / 300 : 1;
      catDice.scale.setScalar(Math.max(0.01, fade) * 1.1);
      if (fall >= 1 && catShownId !== mv.id) { catShownId = mv.id; opts.onCatDie?.(mv.catFace); burst(catDice.position.clone(), { n: 14, colors: [0xffd23d, 0xffffff], speed: 1.6, up: 1.5, gravity: 3, life: 0.7 }); }
    } else catDice.visible = false;

    // Enfeites
    boardGroup.children.forEach((o) => {
      if (o.userData.spin) o.rotation.y = time * 0.8;
      if (o.userData.drift) o.position.x = o.userData.base + Math.sin(time * o.userData.drift) * 1.5;
      if (o.userData.sway !== undefined) o.rotation.z = Math.sin(time * 1.2 + o.userData.sway) * 0.04;
      if (o.userData.water) o.position.y = -1.6 + Math.sin(time * 0.8) * 0.05;
      if (o.userData.foam) { const k = 1 + Math.sin(time * 1.1) * 0.03; o.scale.x = islandBox.w * 0.56 * k; o.scale.y = islandBox.h * 0.6 * k; }
      if (o.userData.glow !== undefined) o.material.emissiveIntensity = 1.2 + Math.sin(time * 2 + o.userData.glow) * 0.5;
    });
    if (volcano) {
      volcano.userData.light.intensity = 16 + Math.sin(time * 3) * 5 + Math.sin(time * 7.3) * 2;
      const top = volcano.position.clone().add(new THREE.Vector3(0, 3.6 * volcano.scale.y, 0));
      if (Math.random() < dt * 6) burst(top, { n: 1, colors: [0x6a5e58, 0x8a7e78], speed: 0.3, up: 1.2, gravity: -0.4, life: 3, size: 4 });
      if (Math.random() < dt * 10) burst(top, { n: 1, colors: [0xff7a1a, 0xffb02e], speed: 1.2, up: 3, gravity: 2, life: 1.6 });
      // brasas flutuando pela ilha
      if (Math.random() < dt * 4) burst(new THREE.Vector3(islandBox.x0 + Math.random() * islandBox.w, 0, islandBox.z0 + Math.random() * islandBox.h),
        { n: 1, colors: [0xff8a2e], speed: 0.2, up: 0.6, gravity: -0.15, life: 3, size: 0.6 });
    }
    // vitória: fogos sem parar
    if (S.phase === 'over' && Math.random() < dt * 2.5) {
      const win = S.teams.find((t) => t.id === S.winner);
      celebrate(win ? new THREE.Color(win.color).getHex() : 0xffd23d);
    }
    const actingPos = actingId && pawns.get(actingId) ? pawns.get(actingId).group.position : null;
    stepMascots(dt, time, actingPos, mv && mvT < mv.dur + 500 ? mv.id : null, animating);
    for (const f of flyers) {
      const u = f.userData;
      const a = u.ph + time * u.sp;
      const wob = u.kind === 'butterfly' ? Math.sin(time * 2.3 + u.ph) * 0.4 : 0;
      f.position.set(u.cx + Math.cos(a) * u.rad + wob, u.alt + Math.sin(time * 1.3 + u.ph) * (u.kind === 'butterfly' ? 0.25 : 0.3), u.cz + Math.sin(a) * u.rad * 0.7);
      f.rotation.y = Math.atan2(-Math.sin(a) * u.sp, Math.cos(a) * u.sp * 0.7) ;
      const flapSpeed = u.kind === 'butterfly' ? 18 : u.kind === 'bird' ? 9 : 4;
      const flap = Math.sin(time * flapSpeed + u.ph) * (u.kind === 'ptero' ? 0.45 : 0.8);
      u.L.rotation.z = flap; u.R.rotation.z = -flap;
    }
    stepParticles(dt);
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
    if (shake > 0.001) {
      camera.position.x += (Math.random() - 0.5) * shake;
      camera.position.y += (Math.random() - 0.5) * shake;
      shake *= Math.pow(0.02, dt);
    }
    renderer.render(scene, camera);
  }
  requestAnimationFrame(frame);

  return { update, resize, cheer, celebrate: () => celebrate(0xffd23d), shake: (v) => { shake = Math.max(shake, v); } };
}
