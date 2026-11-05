class_name Tabuleiro3D
extends Node3D
## Tabuleiro 3D do Mimicaço (port do board3d.js do jogo web).
## Tudo que se mexe é calculado a partir do relógio da sala (move.at + tempo), então a animação
## é a mesma no modo passa-e-joga e no modo com celulares.

signal dado_rolou
signal pulou(k: int, total: int)
signal pousou(mv: Dictionary)
signal dado_categoria(face: String)

const DICE_MS := 1700.0
const HOP_MS := 330.0
const SPACING := 1.42
const TILE := 1.08
const CAT_FACES := ["acao", "objeto", "gente", "bicho", "lugar", "casa"]
const DICE_FACES := [3, 4, 1, 6, 2, 5] # +x, -x, +y, -y, +z, -z
const FACE_NORMALS := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]

# Cada nível é um mundo: cores da ilha, luz, enfeites e quem passeia por ali.
const THEMES := {
	"kids": {
		"ceu": Color("#eaf6ff"), "chao": Color("#6aa848"), "hemi": 1.05, "sol": Color("#ffe6b8"), "sol_e": 1.55, "exposicao": 1.0,
		"camadas": [[Color("#62b83a"), Color("#9a6b3f")], [Color("#5aa835"), Color("#7d5330")], [Color("#8a5a33"), Color("#6b4426")]],
		"tufos": [Color("#5fb83a"), Color("#7ad24e"), Color("#4a9e30"), Color("#8fdc5a")],
		"preench": Color("#d6ecff"), "contorno": Color("#fff2c8"), "pedra": Color("#f3e3c3"), "deco": "jardim", "nuvens": true,
		"mascotes": [["rawzinho", 2.0], ["burrinho", 1.9]],
	},
	"familia": {
		"ceu": Color("#ffe9cc"), "chao": Color("#3aa7b8"), "hemi": 1.0, "sol": Color("#ffcf8a"), "sol_e": 1.45, "exposicao": 1.0,
		"camadas": [[Color("#e8c376"), Color("#d9ab5e")], [Color("#7ccf4a"), Color("#c79a5a")], [Color("#9a6b3f"), Color("#7d5330")]],
		"tufos": [],
		"preench": Color("#ffe2c0"), "contorno": Color("#ffb070"), "pedra": Color("#ffffff"), "deco": "praia", "nuvens": true, "mar": Color("#29c3d6"),
		"mascotes": [["rawzinho", 2.0], ["burrinho", 1.9]],
	},
	"adulto": {
		"ceu": Color("#ffd2b0"), "chao": Color("#3c5a40"), "hemi": 1.15, "sol": Color("#ffb07a"), "sol_e": 1.5, "exposicao": 1.0,
		"camadas": [[Color("#5f9a3a"), Color("#6a4430")], [Color("#4a7a32"), Color("#3f2a22")], [Color("#2c1e1a"), Color("#1e1412")]],
		"tufos": [Color("#4a7a32"), Color("#5f9a3a"), Color("#3a6428")],
		"preench": Color("#b8c8ff"), "contorno": Color("#ff7a3a"), "pedra": Color("#8a7a6e"), "deco": "jurassico", "nuvens": false, "lava": true,
		"mascotes": [["rawadulto", 2.6], ["burrinho", 2.0]],
	},
}

# Modelos do cenário: altura, se precisa repintar o branco e se a folhagem vira moita.
const PROPS := {
	"hibisco": {"h": 1.1}, "flor_azul": {"h": 0.8}, "flor_rosa": {"h": 1.0},
	"palmeira": {"h": 2.6}, "coqueiro": {"h": 2.4, "recolor": true}, "bananeira": {"h": 1.9, "recolor": true},
	"samambaia": {"h": 0.75, "recolor": true, "bush": true}, "vulcao": {"h": 4.2},
	"arvore_rosa": {"h": 1.7, "recolor": true}, "arvore_redonda": {"h": 1.7}, "carvalho": {"h": 1.8},
	"pinheiro": {"h": 1.6, "recolor": true, "leaf": Color("#2f8f45")}, "tufo": {"h": 0.45}, "toco": {"h": 0.42}, "cogumelo": {"h": 0.62},
}

var relogio: Callable = func() -> float: return SalaLocal.agora_ms()
var leve := false # celular/tablet fraco: menos enfeites e partículas
var zoom := 1.0

var S: Dictionary = {}
var camera: Camera3D
var _env: Environment
var _sol: DirectionalLight3D
var _preench: DirectionalLight3D
var _contorno: DirectionalLight3D
var _rebate: DirectionalLight3D
var _grupo: Node3D
var _tiles: Array = [] # [{group, mat, pos}]
var _centro := Vector3.ZERO
var _raio := 8.0
var _ilha := {} # x0, z0, w, h
var _peoes := {} # teamId -> {group, body}
var _anel: MeshInstance3D
var _dado: MeshInstance3D
var _dado_cat: MeshInstance3D
var _vulcao: Node3D
var _luz_vulcao: OmniLight3D
var _voadores: Array = []
var _mascotes: Array = []
var _particulas: Array = []
var _bolinha: SphereMesh
var _tremor := 0.0
var _chave := ""
var _ultimo_pulo := ""
var _ultimo_dado = null
var _pousou_id = null
var _cat_mostrada = null
var _cam_alvo := Vector3.ZERO
var _cam_foco := Vector3.ZERO
var _cam_ok := false
var _t := 0.0
var _props_cache := {}
var _mascote_cache := {}
var _rng := RandomNumberGenerator.new()
var _anim: Array = [] # enfeites animados: [node, tipo, dado]


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 38.0
	camera.near = 0.1
	camera.far = 200.0
	add_child(camera)
	camera.make_current()

	var we := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_CLEAR_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_white = 6.0
	we.environment = _env
	add_child(we)

	_sol = DirectionalLight3D.new()
	_sol.shadow_enabled = true
	_sol.shadow_bias = 0.03
	_sol.shadow_normal_bias = 1.0
	_sol.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sol.directional_shadow_max_distance = 80.0
	add_child(_sol)
	_preench = _luz(Vector3(6, 8, 14), 0.3)
	_contorno = _luz(Vector3(4, 6, -12), 0.55)
	_rebate = _luz(Vector3(0, -10, 0), 0.25) # luz que vem do chão (como a HemisphereLight)

	_bolinha = SphereMesh.new()
	_bolinha.radius = 0.06
	_bolinha.height = 0.12
	_bolinha.radial_segments = 6
	_bolinha.rings = 4

	_dado = MeshInstance3D.new()
	_dado.mesh = Malhas.cubo_atlas(0.95)
	var md := StandardMaterial3D.new()
	md.albedo_texture = Malhas.textura_dado(DICE_FACES)
	md.roughness = 0.35
	_dado.material_override = md
	_dado.visible = false
	add_child(_dado)
	_dado_cat = MeshInstance3D.new()
	_dado_cat.mesh = _dado.mesh
	var mc := StandardMaterial3D.new()
	mc.albedo_texture = Malhas.textura_dado_categoria(CAT_FACES)
	mc.roughness = 0.35
	_dado_cat.material_override = mc
	_dado_cat.visible = false
	add_child(_dado_cat)


func _luz(de: Vector3, energia: float) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.light_energy = energia
	add_child(l)
	l.look_at_from_position(de, Vector3.ZERO, Vector3.UP if absf(de.normalized().y) < 0.99 else Vector3.FORWARD)
	return l


# ---------- Estado ----------
func atualizar(estado: Dictionary) -> void:
	S = estado
	var nivel: String = S.get("settings", {}).get("level", "kids")
	var partes := [nivel]
	for b in S["board"]:
		partes.append(String(b["type"]) + String(b.get("cat", "")))
	var chave := ",".join(partes)
	if chave != _chave:
		_chave = chave
		for id in _peoes:
			_peoes[id]["group"].queue_free()
		_peoes.clear()
		_montar(S["board"], nivel)
		_cam_ok = false
		_trocar_mascotes(nivel)
	_sincronizar_peoes(S["teams"])


func _sincronizar_peoes(teams: Array) -> void:
	var ids := {}
	for t in teams:
		ids[t["id"]] = true
		if not _peoes.has(t["id"]):
			var p := _fazer_peao(Color(t["color"]))
			_grupo.add_child(p["group"])
			p["group"].position = _pos_casa(int(t["pos"])) + Vector3(0, 0.17, 0)
			_peoes[t["id"]] = p
	for id in _peoes.keys():
		if not ids.has(id):
			_peoes[id]["group"].queue_free()
			_peoes.erase(id)


# ---------- Caminho das casas ----------
func _layout(n: int) -> Array:
	var linhas := 3 if n <= 21 else (4 if n <= 31 else 5)
	var W := maxf(5.0, ((n - 1) * SPACING - (linhas - 1) * 3.4) / linhas)
	var gap := 2.5
	var pts: Array = []
	for r in linhas:
		var z := (linhas - 1) * gap / 2.0 - r * gap
		var dir := 1.0 if r % 2 == 0 else -1.0
		var xs := [-W / 2.0, -W / 6.0, W / 6.0, W / 2.0]
		for i in 4:
			pts.append(Vector3(xs[i] * dir, 0, z + (0.35 if i % 2 else -0.15) * (-1.0 if r % 2 else 1.0)))
	# curva Catmull-Rom centrípeta e pontos igualmente espaçados (como o CatmullRomCurve3)
	var amostras: Array = []
	var seg := pts.size() - 1
	var dens := 60
	for s in seg:
		var p0: Vector3 = pts[s - 1] if s > 0 else pts[0] * 2.0 - pts[1]
		var p1: Vector3 = pts[s]
		var p2: Vector3 = pts[s + 1]
		var p3: Vector3 = pts[s + 2] if s + 2 < pts.size() else pts[s + 1] * 2.0 - pts[s]
		for k in dens:
			amostras.append(_catmull(p0, p1, p2, p3, float(k) / dens))
	amostras.append(pts[pts.size() - 1])
	var acum: Array = [0.0]
	for i in range(1, amostras.size()):
		acum.append(acum[i - 1] + (amostras[i] as Vector3).distance_to(amostras[i - 1]))
	var total: float = acum[acum.size() - 1]
	var out: Array = []
	var j := 0
	for i in n:
		var alvo := total * i / float(n - 1)
		while j < acum.size() - 2 and acum[j + 1] < alvo:
			j += 1
		var f: float = (alvo - acum[j]) / maxf(acum[j + 1] - acum[j], 0.00001)
		out.append((amostras[j] as Vector3).lerp(amostras[j + 1], clampf(f, 0.0, 1.0)))
	return out


static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var dt0 := pow(p0.distance_squared_to(p1), 0.25)
	var dt1 := pow(p1.distance_squared_to(p2), 0.25)
	var dt2 := pow(p2.distance_squared_to(p3), 0.25)
	if dt1 < 1e-4:
		dt1 = 1.0
	if dt0 < 1e-4:
		dt0 = dt1
	if dt2 < 1e-4:
		dt2 = dt1
	var out := Vector3.ZERO
	for a in 3:
		var x0 := p0[a]
		var x1 := p1[a]
		var x2 := p2[a]
		var x3 := p3[a]
		var t1 := ((x1 - x0) / dt0 - (x2 - x0) / (dt0 + dt1) + (x2 - x1) / dt1) * dt1
		var t2 := ((x2 - x1) / dt1 - (x3 - x1) / (dt1 + dt2) + (x3 - x2) / dt2) * dt1
		var c2 := -3.0 * x1 + 3.0 * x2 - 2.0 * t1 - t2
		var c3 := 2.0 * x1 - 2.0 * x2 + t1 + t2
		out[a] = x1 + t1 * t + c2 * t * t + c3 * t * t * t
	return out


func _pos_casa(i: int) -> Vector3:
	if _tiles.is_empty():
		return Vector3.ZERO
	return _tiles[clampi(i, 0, _tiles.size() - 1)]["pos"]


# ---------- Materiais ----------
func _mat(cor: Color, rug := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = rug
	m.metallic = metal
	return m


func _mat_terra(cor: Color, escala := 0.45) -> StandardMaterial3D:
	var ruido := FastNoiseLite.new()
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.frequency = 0.03
	ruido.fractal_octaves = 3
	var tx := NoiseTexture2D.new()
	tx.width = 256
	tx.height = 256
	tx.seamless = true
	tx.noise = ruido
	var g := Gradient.new()
	g.set_color(0, cor.darkened(0.12))
	g.set_color(1, cor.lightened(0.07))
	tx.color_ramp = g
	var m := StandardMaterial3D.new()
	m.albedo_texture = tx
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * escala
	m.roughness = 0.95
	return m


func _malha(mesh: Mesh, mat: Material, pos := Vector3.ZERO, sombra := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sombra else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ---------- Montagem do mundo ----------
func _montar(board: Array, nivel: String) -> void:
	var TH: Dictionary = THEMES.get(nivel, THEMES["kids"])
	_sol.light_color = TH["sol"]
	_sol.light_energy = TH["sol_e"]
	_preench.light_color = TH["preench"]
	_contorno.light_color = TH["contorno"]
	_rebate.light_color = TH["chao"]
	_env.ambient_light_color = (TH["ceu"] as Color).lerp(TH["chao"], 0.35)
	_env.ambient_light_energy = 0.55 * TH["hemi"]
	_env.tonemap_exposure = TH["exposicao"]

	if _grupo:
		_grupo.queue_free()
	_grupo = Node3D.new()
	add_child(_grupo)
	_tiles.clear()
	_anim.clear()
	_voadores.clear()
	_vulcao = null
	_luz_vulcao = null
	_rng.seed = board.size() * 7919

	var pos := _layout(board.size())
	var mn := Vector3(INF, 0, INF)
	var mx := Vector3(-INF, 0, -INF)
	for p in pos:
		mn = mn.min(p)
		mx = mx.max(p)
	_centro = (mn + mx) / 2.0
	var tam := mx - mn
	_raio = maxf(tam.x, tam.z) / 2.0 + 2.5

	# Ilha em camadas, como um bolo de brinquedo
	var pad := 1.6
	var w := tam.x + pad * 2.0
	var h := tam.z + pad * 2.0
	var x0 := mn.x - pad
	var z0 := mn.z - pad
	_ilha = {"x0": x0, "z0": z0, "w": w, "h": h}
	var camadas: Array = TH["camadas"]
	var dados := [[0.0, -1.0, 1.0], [-0.8, -2.2, 0.94], [-1.95, -3.25, 0.82]]
	for k in 3:
		var d: Array = dados[k]
		var esc: float = d[2]
		var mesh := Malhas.placa_retangular(_centro.x, _centro.z, (w + 0.6) * esc, (h + 0.6) * esc, 2.5 * esc, d[0], d[1], 0.25)
		var mi := _malha(mesh, null, Vector3.ZERO, false)
		var topo: Color = camadas[k][0]
		var lado: Color = camadas[k][1]
		mi.set_surface_override_material(0, _mat(topo, 0.95))
		mi.set_surface_override_material(1, _mat_terra(lado))
		_grupo.add_child(mi)

	if TH.has("mar"):
		var mar := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2.ONE * _raio * 2.7
		mar.mesh = pm
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shaders/mar.gdshader")
		sm.set_shader_parameter("cor", TH["mar"])
		mar.material_override = sm
		mar.position = Vector3(_centro.x, -1.6, _centro.z)
		mar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_grupo.add_child(mar)
		_anim.append([mar, "mar", 0.0])
		var espuma := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.93
		tor.outer_radius = 1.0
		tor.rings = 64
		espuma.mesh = tor
		var me := _mat(Color(1, 1, 1, 0.5))
		me.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		me.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		espuma.material_override = me
		espuma.scale = Vector3(w * 0.56, 0.02, h * 0.6)
		espuma.position = Vector3(_centro.x, -1.55, _centro.z)
		espuma.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_grupo.add_child(espuma)
		_anim.append([espuma, "espuma", Vector2(w * 0.56, h * 0.6)])

	# Pedrinhas entre as casas
	var pedra := CylinderMesh.new()
	pedra.top_radius = 0.16
	pedra.bottom_radius = 0.18
	pedra.height = 0.08
	pedra.radial_segments = 12
	var mp := _mat(TH["pedra"])
	for i in pos.size() - 1:
		var m := _malha(pedra, mp, ((pos[i] as Vector3).lerp(pos[i + 1], 0.5)) * Vector3(1, 0, 1) + Vector3(0, 0.0, 0), false)
		_grupo.add_child(m)

	# Casas
	var cats: Dictionary = S.get("categories", Cartas.resumo_categorias())
	var shader_casa: Shader = load("res://shaders/casa.gdshader")
	var borda_mat := _mat(Color("#2a2550"), 0.7)
	for i in board.size():
		var sq: Dictionary = board[i]
		var cor := Color.WHITE
		var arte := ""
		var rotulo := ""
		match String(sq["type"]):
			"cat":
				cor = Color(cats[sq["cat"]]["color"])
				arte = sq["cat"]
			"all":
				cor = Color("#fff1a8")
				arte = "todos"
			"start":
				arte = "largada"
			"finish":
				cor = Color("#ffd23d")
				arte = "trofeu"
			"jump":
				cor = Color("#5ec8ff")
				rotulo = "+2"
		var grande: bool = sq["type"] in ["start", "finish"]
		var s := 1.3 if grande else 1.0
		var g := Node3D.new()
		g.position = pos[i]
		var base_mat := _mat(cor, 0.45)
		base_mat.emission_enabled = true
		base_mat.emission = cor
		base_mat.emission_energy_multiplier = 0.0
		var base := _malha(Malhas.placa_retangular(0, 0, TILE * s, TILE * s, 0.2, 0.17, -0.12, 0.1, 4), base_mat)
		g.add_child(base)
		var borda := _malha(Malhas.placa_retangular(0, 0, TILE * s + 0.12, TILE * s + 0.12, 0.24, 0.03, -0.1, 0.06, 4), borda_mat, Vector3.ZERO, false)
		g.add_child(borda)
		var tampa := MeshInstance3D.new()
		var plano := PlaneMesh.new()
		plano.size = Vector2(0.9, 0.9) * s
		tampa.mesh = plano
		var sm := ShaderMaterial.new()
		sm.shader = shader_casa
		sm.set_shader_parameter("cor", cor)
		if arte != "":
			sm.set_shader_parameter("arte", UI.tex(UI.img_path(arte)))
			sm.set_shader_parameter("tem_arte", 1.0)
		else:
			sm.set_shader_parameter("tem_arte", 0.0)
		tampa.material_override = sm
		tampa.position.y = 0.176
		tampa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(tampa)
		if rotulo != "":
			g.add_child(_texto3d(rotulo, 92, Vector3(0, 0.18, -0.12), Color.WHITE, 12))
			g.add_child(_texto3d("PULO!", 30, Vector3(0, 0.18, 0.05), Color.WHITE, 8))
		if sq["type"] in ["cat", "all", "jump"]:
			g.add_child(_numero(i, Vector3(0, 0.18, 0.239 * s)))
		_grupo.add_child(g)
		_tiles.append({"group": g, "mat": base_mat, "pos": pos[i]})

	_trofeu(pos)
	_bandeira(pos)
	var perto := func(x: float, z: float, d: float) -> bool:
		for p in pos:
			if (p.x - x) * (p.x - x) + (p.z - z) * (p.z - z) < d * d:
				return true
		return false
	_decorar(TH, perto, x0, z0, w, h)
	if TH["nuvens"]:
		_nuvens(3 if leve else 5)

	# Sombra cobrindo a ilha
	_sol.position = _centro + Vector3(-8, 16, 10)
	_sol.look_at(_centro, Vector3.UP)
	_sol.directional_shadow_max_distance = _raio * 6.0

	# Anel que marca quem está jogando
	_anel = MeshInstance3D.new()
	var anel := TorusMesh.new()
	anel.inner_radius = 0.415
	anel.outer_radius = 0.585
	anel.rings = 48
	anel.ring_segments = 12
	_anel.mesh = anel
	var ma := StandardMaterial3D.new()
	ma.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_anel.material_override = ma
	_anel.visible = false
	_anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grupo.add_child(_anel)


func _texto3d(txt: String, tam: int, p: Vector3, cor := Color.WHITE, contorno := 10) -> Label3D:
	var l := Label3D.new()
	l.text = txt
	l.font = Tema.fonte_titulo
	l.font_size = tam
	l.pixel_size = 0.0024
	l.modulate = cor
	l.outline_size = contorno
	l.outline_modulate = Color(18 / 255.0, 58 / 255.0, 122 / 255.0, 0.85)
	l.rotation_degrees = Vector3(-90, 0, 0)
	l.position = p
	l.shaded = false
	l.double_sided = false
	return l


func _numero(n: int, p: Vector3) -> Node3D:
	var g := Node3D.new()
	g.position = p
	var branco := CylinderMesh.new()
	branco.top_radius = 0.176
	branco.bottom_radius = 0.176
	branco.height = 0.01
	branco.radial_segments = 32
	g.add_child(_malha(branco, _mat(Color.WHITE, 0.6), Vector3.ZERO, false))
	var azul := CylinderMesh.new()
	azul.top_radius = 0.151
	azul.bottom_radius = 0.151
	azul.height = 0.012
	azul.radial_segments = 32
	g.add_child(_malha(azul, _mat(Color("#123a7a"), 0.6), Vector3(0, 0.002, 0), false))
	var l := _texto3d(str(n), 54 if n >= 10 else 64, Vector3(0, 0.01, 0.012), Color.WHITE, 0)
	g.add_child(l)
	return g


func _trofeu(pos: Array) -> void:
	var ouro := _mat(Color("#ffc928"), 0.25, 0.8)
	var perfil := [Vector2(0.0, 0), Vector2(0.32, 0), Vector2(0.3, 0.08), Vector2(0.1, 0.14), Vector2(0.08, 0.42), Vector2(0.18, 0.5),
		Vector2(0.38, 0.62), Vector2(0.42, 0.95), Vector2(0.38, 0.95), Vector2(0.0, 0.7)]
	var t := Node3D.new()
	t.add_child(_malha(Malhas.torno(perfil, 32), ouro))
	for sgn in [-1, 1]:
		var alca := TorusMesh.new()
		alca.inner_radius = 0.12
		alca.outer_radius = 0.2
		var a := _malha(alca, ouro, Vector3(0.42 * sgn, 0.75, 0))
		a.rotation_degrees = Vector3(90, 0, 0)
		a.scale = Vector3(1, 1, 1.0)
		t.add_child(a)
	var ult: Vector3 = pos[pos.size() - 1]
	var dir := (ult - (pos[pos.size() - 2] as Vector3)).normalized()
	t.position = ult + dir * 1.1
	t.position.y = 0.0
	t.scale = Vector3.ONE * 1.3
	_grupo.add_child(t)
	_anim.append([t, "gira", 0.0])


func _bandeira(pos: Array) -> void:
	var prim: Vector3 = pos[0]
	var tras := (prim - (pos[1] as Vector3)).normalized()
	var mastro := CylinderMesh.new()
	mastro.top_radius = 0.04
	mastro.bottom_radius = 0.04
	mastro.height = 1.5
	var m := _malha(mastro, _mat(Color.WHITE, 0.5), prim + tras * 0.95 + Vector3(0, 0.75, 0))
	var pano := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.45)
	q.subdivide_width = 8
	q.center_offset = Vector3(0.35, 0, 0)
	pano.mesh = q
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/bandeira.gdshader")
	sm.set_shader_parameter("xadrez", Malhas.textura_xadrez())
	pano.material_override = sm
	pano.position = Vector3(0, 0.5, 0)
	m.add_child(pano)
	_grupo.add_child(m)


func _nuvens(n: int) -> void:
	var mat := _mat(Color.WHITE, 1.0)
	for k in n:
		var c := Node3D.new()
		for j in 4:
			var esf := SphereMesh.new()
			var r := 0.5 + _rng.randf() * 0.35
			esf.radius = r
			esf.height = r * 2.0
			c.add_child(_malha(esf, mat, Vector3(j * 0.55 - 0.8, _rng.randf() * 0.25, _rng.randf() * 0.3), false))
		c.position = Vector3(_centro.x - _raio + _rng.randf() * _raio * 2.0, 3.6 + _rng.randf() * 1.4, _ilha["z0"] - 1.5 - _rng.randf() * 2.5)
		c.scale = Vector3.ONE * 0.8
		_grupo.add_child(c)
		_anim.append([c, "nuvem", Vector2(c.position.x, 0.15 + _rng.randf() * 0.2)])


# ---------- Enfeites de cada mundo ----------
func _decorar(TH: Dictionary, perto: Callable, x0: float, z0: float, w: float, h: float) -> void:
	var ocupados: Array = []
	var r := _rng
	var lugar := func(min_d: float, borda_bias := 0.0, espaco := 0.0) -> Variant:
		for k in 80:
			var x := x0 + 0.4 + r.randf() * (w - 0.8)
			var z := z0 + 0.4 + r.randf() * (h - 0.8)
			if perto.call(x, z, min_d):
				continue
			var livre := true
			if espaco > 0.0:
				for o in ocupados:
					if (o[0] - x) * (o[0] - x) + (o[1] - z) * (o[1] - z) < (o[2] + espaco) * (o[2] + espaco):
						livre = false
						break
			if not livre:
				continue
			var borda := minf(minf(x - x0, x0 + w - x), minf(z - z0, z0 + h - z))
			if borda_bias > 0.0 and borda > 1.6 and r.randf() < borda_bias:
				continue
			if espaco > 0.0:
				ocupados.append([x, z, espaco])
			return Vector2(x, z)
		return null
	# na borda de trás ou dos lados (enfeite alto não tampa as casas)
	var lugar_borda := func(min_d: float, espaco: float) -> Variant:
		for i in 80:
			var p = lugar.call(min_d, 0.0, espaco)
			if p == null:
				continue
			var borda := minf(minf(p.x - x0, x0 + w - p.x), p.y - z0)
			if borda > 1.1 or p.y > z0 + h * 0.7:
				ocupados.pop_back()
				continue
			return p
		return null

	var tipo := "borboleta" if TH["deco"] == "jardim" else ("passaro" if TH["deco"] == "praia" else "ptero")
	var cores: Array = [Color("#ff6fb5"), Color("#ffd23d"), Color("#5ec8ff"), Color("#a26bff"), Color("#ff8a3d")] if tipo == "borboleta" else ([Color.WHITE, Color("#f2f2f2")] if tipo == "passaro" else [Color("#8a5a44"), Color("#6a4a3a")])
	var nv: int = {"borboleta": 5 if leve else 9, "passaro": 3 if leve else 5, "ptero": 2 if leve else 3}[tipo]
	for i in nv:
		var f := _voador(tipo, cores[i % cores.size()])
		f.set_meta("cx", x0 + w * (0.2 + r.randf() * 0.6))
		f.set_meta("cz", z0 + h * (0.2 + r.randf() * 0.6))
		f.set_meta("rad", 0.6 + r.randf() * 1.4 if tipo == "borboleta" else 2.0 + r.randf() * maxf(w, h) * 0.35)
		f.set_meta("alt", 0.4 + r.randf() * 0.8 if tipo == "borboleta" else (2.6 + r.randf() * 1.2 if tipo == "passaro" else 3.4 + r.randf() * 1.5))
		f.set_meta("sp", (0.5 if tipo == "borboleta" else 0.25) * (0.7 + r.randf() * 0.6) * (1.0 if r.randf() < 0.5 else -1.0))
		f.set_meta("ph", r.randf() * TAU)
		_grupo.add_child(f)
		_voadores.append(f)

	if (TH["tufos"] as Array).size() > 0:
		_tufos(TH["tufos"], perto, x0, z0, w, h)

	match String(TH["deco"]):
		"jardim":
			var arvores := ["arvore_redonda", "carvalho", "arvore_rosa", "pinheiro", "arvore_redonda", "carvalho"]
			for n in (7 if leve else 12):
				var p = lugar_borda.call(1.3, 0.7)
				if p != null:
					_prop(arvores[n % arvores.size()], p, 0.7 + r.randf() * 0.35, r.randf() * 6.0)
			for i in (3 if leve else 6):
				var p = lugar.call(0.8, 0.0, 0.35)
				if p != null:
					_prop("toco" if i % 3 == 2 else "cogumelo", p, 0.75 + r.randf() * 0.5, r.randf() * 6.0)
			for i in (8 if leve else 18):
				var p = lugar.call(0.7)
				if p != null:
					_prop("tufo", p, 0.7 + r.randf() * 0.7, r.randf() * 6.0)
			for i in (8 if leve else 16):
				var p = lugar.call(0.9)
				if p != null:
					_prop(["hibisco", "flor_azul", "flor_rosa"][i % 3], p, 0.8 + r.randf() * 0.6, r.randf() * 6.0)
			_bolinhas_flores([Color("#ff6fb5"), Color("#ffd23d"), Color.WHITE, Color("#a26bff"), Color("#ff8a3d"), Color("#5ec8ff")], 50 if leve else 110, lugar, 0.85, 0.07)
		"praia":
			for i in (5 if leve else 8):
				var p = lugar_borda.call(1.3, 0.8)
				if p != null:
					_prop(["palmeira", "coqueiro", "bananeira"][i % 3], p, 0.7 + r.randf() * 0.35, r.randf() * 6.0)
			for i in 8:
				var p = lugar.call(0.9)
				if p != null:
					_prop("hibisco" if i % 2 else "flor_rosa", p, 0.8 + r.randf() * 0.4, r.randf() * 6.0)
			_bolinhas_flores([Color("#ff4f7a"), Color("#ffb02e"), Color("#ff6fb5"), Color.WHITE], 40 if leve else 80, lugar, 0.85, 0.08)
			var concha := CylinderMesh.new()
			concha.top_radius = 0.0
			concha.bottom_radius = 0.12
			concha.height = 0.08
			concha.radial_segments = 9
			var mconcha := _mat(Color("#ffd2c2"), 0.5)
			var mrocha := _mat(Color("#b5a89a"), 0.9)
			for i in 14:
				var p = lugar.call(1.0)
				if p == null:
					continue
				if i % 2 == 0:
					_grupo.add_child(_malha(concha, mconcha, Vector3(p.x, 0.02, p.y)))
				else:
					var rocha := SphereMesh.new()
					var rr := 0.14 + r.randf() * 0.1
					rocha.radius = rr
					rocha.height = rr * 1.6
					_grupo.add_child(_malha(rocha, mrocha, Vector3(p.x, 0.02, p.y)))
			var ps = lugar.call(1.6, 0.5)
			if ps != null:
				_guarda_sol(ps)
		"jurassico":
			for i in (8 if leve else 14):
				var p = lugar.call(1.0, 0.5)
				if p != null:
					_prop("samambaia", p, 0.9 + r.randf() * 0.8, r.randf() * 6.0)
			var tronco := _mat(Color("#5a3e2a"), 0.95)
			var copa := _mat(Color("#2c5a26"), 0.9)
			for i in (6 if leve else 10):
				var p = lugar.call(1.4, 0.85)
				if p == null:
					continue
				var g := Node3D.new()
				var c := CylinderMesh.new()
				c.top_radius = 0.08
				c.bottom_radius = 0.14
				c.height = 1.6
				c.radial_segments = 7
				g.add_child(_malha(c, tronco, Vector3(0, 0.8, 0)))
				var e := SphereMesh.new()
				e.radius = 0.55
				e.height = 0.5
				e.radial_segments = 8
				e.rings = 5
				g.add_child(_malha(e, copa, Vector3(0, 1.65, 0)))
				g.position = Vector3(p.x, 0, p.y)
				g.scale = Vector3.ONE * (0.8 + r.randf() * 0.5)
				_grupo.add_child(g)
			var mrocha := _mat(Color("#3a302c"), 0.95)
			var lava := _mat(Color("#ff5a1a"))
			lava.emission_enabled = true
			lava.emission = Color("#ff4a0a")
			lava.emission_energy_multiplier = 1.6
			for i in 12:
				var p = lugar.call(0.95)
				if p == null:
					continue
				if i % 3 == 0:
					var b := BoxMesh.new()
					b.size = Vector3(0.7 + r.randf() * 0.6, 0.02, 0.07)
					var fenda := _malha(b, lava, Vector3(p.x, 0.012, p.y), false)
					fenda.rotation.y = r.randf() * 6.0
					_grupo.add_child(fenda)
				else:
					var rocha := SphereMesh.new()
					var rr := 0.2 + r.randf() * 0.25
					rocha.radius = rr
					rocha.height = rr * 1.7
					rocha.radial_segments = 6
					rocha.rings = 3
					_grupo.add_child(_malha(rocha, mrocha, Vector3(p.x, 0.05, p.y)))
			var osso := _mat(Color("#f2ead8"), 0.6)
			for i in 3:
				var p = lugar.call(1.0)
				if p == null:
					continue
				var b := Node3D.new()
				var c := CylinderMesh.new()
				c.top_radius = 0.035
				c.bottom_radius = 0.035
				c.height = 0.4
				var haste := _malha(c, osso)
				haste.rotation_degrees.z = 90
				b.add_child(haste)
				for sx in [-1, 1]:
					for sz in [-1, 1]:
						var bola := SphereMesh.new()
						bola.radius = 0.05
						bola.height = 0.1
						b.add_child(_malha(bola, osso, Vector3(0.2 * sx, 0, 0.035 * sz)))
				b.position = Vector3(p.x, 0.04, p.y)
				b.rotation.y = r.randf() * 6.0
				_grupo.add_child(b)
			# vulcão atrás da ilha, soltando fumaça e brasas
			_vulcao = Node3D.new()
			_vulcao.position = Vector3(x0 + w + 2.2, -1.6, z0 - 1.2)
			_prop_em(_vulcao, "vulcao", 1.0 / 0.75 * 0.9)
			_vulcao.scale = Vector3.ONE * 0.75
			_luz_vulcao = OmniLight3D.new()
			_luz_vulcao.light_color = Color("#ff5a1a")
			_luz_vulcao.omni_range = 14.0
			_luz_vulcao.light_energy = 4.0
			_luz_vulcao.position.y = 4.0
			_vulcao.add_child(_luz_vulcao)
			_grupo.add_child(_vulcao)


func _bolinhas_flores(cores: Array, n: int, lugar: Callable, min_d: float, raio: float) -> void:
	var esf := SphereMesh.new()
	esf.radius = raio
	esf.height = raio * 2.0
	esf.radial_segments = 8
	esf.rings = 6
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = esf
	var lista: Array = []
	for k in n:
		var p = lugar.call(min_d)
		if p != null:
			lista.append(p)
	mm.instance_count = lista.size()
	for k in lista.size():
		mm.set_instance_transform(k, Transform3D(Basis(), Vector3(lista[k].x, 0.0, lista[k].y)))
		mm.set_instance_color(k, cores[k % cores.size()])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.6
	mmi.material_override = mat
	_grupo.add_child(mmi)


func _tufos(cores: Array, perto: Callable, x0: float, z0: float, w: float, h: float) -> void:
	var lamina := CylinderMesh.new()
	lamina.top_radius = 0.0
	lamina.bottom_radius = 0.035
	lamina.height = 0.22
	lamina.radial_segments = 4
	lamina.rings = 1
	var n := 120 if leve else 260
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = lamina
	mm.instance_count = n
	var k := 0
	var tentativas := 0
	var r := _rng
	while k < n and tentativas < n * 6:
		tentativas += 1
		var cx := x0 + 0.3 + r.randf() * (w - 0.6)
		var cz := z0 + 0.3 + r.randf() * (h - 0.6)
		if perto.call(cx, cz, 0.62):
			continue
		for b in 5:
			if k >= n:
				break
			var sc := 0.6 + r.randf() * 0.8
			var bas := Basis.from_euler(Vector3((r.randf() - 0.5) * 0.7, r.randf() * 6.28, (r.randf() - 0.5) * 0.7)).scaled(Vector3(sc, sc * (0.8 + r.randf() * 0.6), sc))
			mm.set_instance_transform(k, Transform3D(bas, Vector3(cx + (r.randf() - 0.5) * 0.12, 0.08, cz + (r.randf() - 0.5) * 0.12)))
			mm.set_instance_color(k, cores[r.randi() % cores.size()])
			k += 1
	mm.visible_instance_count = k
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grupo.add_child(mmi)


func _guarda_sol(p: Vector2) -> void:
	var g := Node3D.new()
	var haste := CylinderMesh.new()
	haste.top_radius = 0.03
	haste.bottom_radius = 0.03
	haste.height = 1.2
	g.add_child(_malha(haste, _mat(Color.WHITE), Vector3(0, 0.6, 0)))
	var img := Image.create(128, 8, false, Image.FORMAT_RGBA8)
	for i in 8:
		img.fill_rect(Rect2i(i * 16, 0, 16, 8), Color("#ff4f7a") if i % 2 else Color.WHITE)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.7
	cone.height = 0.3
	cone.radial_segments = 16
	cone.cap_bottom = false
	g.add_child(_malha(cone, m, Vector3(0, 1.25, 0)))
	g.position = Vector3(p.x, 0, p.y)
	_grupo.add_child(g)


func _voador(tipo: String, cor: Color) -> Node3D:
	var g := Node3D.new()
	var tam: float = {"ptero": 0.9, "passaro": 0.45, "borboleta": 0.18}[tipo]
	var asa_mat := _mat(cor, 0.6)
	asa_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var pts: Array
	if tipo == "borboleta":
		pts = [Vector2(0, 0), Vector2(0.35, 0.45), Vector2(0.9, 0.42), Vector2(1, 0.1), Vector2(0.85, -0.25), Vector2(0.4, -0.45)]
	else:
		pts = [Vector2(0, 0.12), Vector2(1, -0.05), Vector2(0.55, -0.12), Vector2(0, -0.15)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, pts.size() - 1):
		for v in [pts[0], pts[i], pts[i + 1]]:
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(v.x, 0, -v.y) * tam)
	var asa_mesh := st.commit()
	var L := _malha(asa_mesh, asa_mat)
	var R := _malha(asa_mesh, asa_mat)
	R.scale.x = -1
	var corpo := CapsuleMesh.new()
	corpo.radius = tam * 0.08
	corpo.height = tam * 0.66
	var cm := _malha(corpo, _mat(Color.WHITE if tipo == "passaro" else Color("#3a2a24")))
	cm.rotation_degrees.x = 90
	g.add_child(L)
	g.add_child(R)
	g.add_child(cm)
	g.set_meta("L", L)
	g.set_meta("R", R)
	g.set_meta("tipo", tipo)
	return g


# ---------- Modelos do cenário (carregados uma vez e clonados) ----------
func _aabb_cena(raiz: Node) -> AABB:
	var caixa := AABB()
	var primeiro := true
	var pilha: Array = [[raiz, Transform3D()]]
	while not pilha.is_empty():
		var it: Array = pilha.pop_back()
		var no: Node = it[0]
		var xf: Transform3D = it[1]
		if no is MeshInstance3D and (no as MeshInstance3D).visible and (no as MeshInstance3D).mesh:
			var mi := no as MeshInstance3D
			var m := xf
			if mi.skin != null:
				var sk := mi.get_node_or_null(mi.skeleton) as Skeleton3D
				if sk and mi.skin.get_bind_count() > 0:
					var b := mi.skin.get_bind_bone(0)
					if b < 0:
						b = sk.find_bone(mi.skin.get_bind_name(0))
					if b >= 0:
						m = _xf_ate(raiz, sk) * sk.get_bone_global_rest(b) * mi.skin.get_bind_pose(0)
			var ab := m * mi.mesh.get_aabb()
			caixa = ab if primeiro else caixa.merge(ab)
			primeiro = false
		for c in no.get_children():
			var cx := xf
			if c is Node3D:
				cx = xf * (c as Node3D).transform
			pilha.append([c, cx])
	return caixa


func _xf_ate(raiz: Node, no: Node) -> Transform3D:
	var xf := Transform3D()
	var n := no
	while n != null and n != raiz:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


func _modelo_prop(nome: String) -> Node3D:
	if _props_cache.has(nome):
		return _props_cache[nome]
	var cfg: Dictionary = PROPS[nome]
	var cena: PackedScene = load("res://assets/model/cenario/%s.glb" % nome)
	if cena == null:
		_props_cache[nome] = null
		return null
	var raiz: Node3D = cena.instantiate()
	var tudo := _aabb_cena(raiz)
	var W := maxf(tudo.size.x, tudo.size.z)
	var verde := _mat(Color("#4caf3a"), 0.7)
	verde.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tronco := _mat(Color("#9a6a3e"), 0.9)
	for mi in raiz.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var ab := _xf_ate(raiz, m) * m.mesh.get_aabb()
		var sz := ab.size
		# tira o "chão" que alguns modelos trazem
		if sz.y < 0.02 * maxf(sz.x, sz.z) and maxf(sz.x, sz.z) > 0.5 * W:
			m.visible = false
			continue
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if cfg.get("recolor", false):
			for s in m.mesh.get_surface_count():
				var mat := m.mesh.surface_get_material(s)
				var c := Color.WHITE
				if mat is StandardMaterial3D:
					c = (mat as StandardMaterial3D).albedo_color
				if c.r > 0.9 and c.g > 0.9 and c.b > 0.9:
					var estreito := maxf(sz.x, sz.z) < sz.y * 0.4
					if estreito and not cfg.get("bush", false):
						m.set_surface_override_material(s, tronco)
					elif cfg.has("leaf"):
						m.set_surface_override_material(s, _mat(cfg["leaf"], 0.75))
					else:
						m.set_surface_override_material(s, verde)
	var caixa := _aabb_cena(raiz)
	var k: float = cfg["h"] / maxf(caixa.size.y, 0.001)
	var c := caixa.get_center()
	raiz.scale = Vector3.ONE * k
	raiz.position = Vector3(-c.x * k, -caixa.position.y * k, -c.z * k)
	var embrulho := Node3D.new()
	if cfg.get("bush", false):
		# a folhagem é um galho só: junta alguns girados para virar uma moita
		for i in 4:
			var g := Node3D.new()
			g.rotation = Vector3(0.35, i / 4.0 * TAU, 0)
			g.add_child(raiz.duplicate() if i > 0 else raiz)
			embrulho.add_child(g)
	else:
		embrulho.add_child(raiz)
	_props_cache[nome] = embrulho
	return embrulho


func _prop_em(pai: Node3D, nome: String, escala := 1.0) -> void:
	var tpl := _modelo_prop(nome)
	if tpl == null:
		return
	var o: Node3D = tpl.duplicate()
	o.scale = Vector3.ONE * escala
	pai.add_child(o)


func _prop(nome: String, p: Vector2, escala := 1.0, rot := 0.0) -> void:
	var tpl := _modelo_prop(nome)
	if tpl == null:
		return
	var o: Node3D = tpl.duplicate()
	o.position = Vector3(p.x, 0.0, p.y)
	o.scale = Vector3.ONE * escala
	o.rotation.y = rot
	_grupo.add_child(o)
	if nome != "vulcao":
		_anim.append([o, "balanca", _rng.randf() * 6.0])


# ---------- Peões ----------
func _fazer_peao(cor: Color) -> Dictionary:
	var g := Node3D.new()
	var corpo := Node3D.new()
	g.add_child(corpo)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 0.25
	mat.clearcoat_enabled = true
	mat.clearcoat = 1.0
	mat.clearcoat_roughness = 0.15
	var perfil := [Vector2(0, 0), Vector2(0.3, 0), Vector2(0.32, 0.05), Vector2(0.3, 0.12), Vector2(0.2, 0.18), Vector2(0.14, 0.4),
		Vector2(0.2, 0.46), Vector2(0.12, 0.5), Vector2(0, 0.5)]
	corpo.add_child(_malha(Malhas.torno(perfil, 32), mat))
	var cabeca := SphereMesh.new()
	cabeca.radius = 0.22
	cabeca.height = 0.44
	corpo.add_child(_malha(cabeca, mat, Vector3(0, 0.66, 0)))
	var branco := StandardMaterial3D.new()
	branco.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	branco.albedo_color = Color.WHITE
	var preto := StandardMaterial3D.new()
	preto.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	preto.albedo_color = Color("#14213d")
	var bochecha := StandardMaterial3D.new()
	bochecha.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bochecha.albedo_color = Color(1.0, 0.56, 0.64, 0.7)
	bochecha.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for s in [-1, 1]:
		var olho := SphereMesh.new()
		olho.radius = 0.06
		olho.height = 0.12
		var o := _malha(olho, branco, Vector3(0.075 * s, 0.7, 0.18), false)
		o.scale.z = 0.6
		corpo.add_child(o)
		var pup := SphereMesh.new()
		pup.radius = 0.035
		pup.height = 0.07
		corpo.add_child(_malha(pup, preto, Vector3(0.075 * s, 0.7, 0.215), false))
		var bo := SphereMesh.new()
		bo.radius = 0.035
		bo.height = 0.07
		var b := _malha(bo, bochecha, Vector3(0.13 * s, 0.63, 0.17), false)
		b.scale.z = 0.4
		corpo.add_child(b)
	g.scale = Vector3.ONE * 1.1
	return {"group": g, "body": corpo}


# ---------- Mascotes que passeiam pela ilha ----------
func _trocar_mascotes(nivel: String) -> void:
	for m in _mascotes:
		(m["root"] as Node3D).queue_free()
	_mascotes.clear()
	var TH: Dictionary = THEMES.get(nivel, THEMES["kids"])
	var i := 0
	for par in TH["mascotes"]:
		var m := _carregar_mascote(par[0], par[1])
		if m.is_empty():
			continue
		m["slot"] = i
		m["big"] = par[0] == "rawadulto"
		m["st"] = {"target": Vector3.ZERO, "wait": 1.0 + i * 2.0, "mode": "wander", "look": null, "cheer": 0.0, "last_follow": null, "last_stomp": 0.0, "walk_t": 0.0}
		_grupo.add_child(m["root"])
		var p := _lugar_livre()
		(m["root"] as Node3D).position = p
		m["st"]["target"] = p
		_mascotes.append(m)
		i += 1


func _carregar_mascote(nome: String, altura: float) -> Dictionary:
	var cena: PackedScene = load("res://assets/model/%s.glb" % nome)
	if cena == null:
		return {}
	var raiz: Node3D = cena.instantiate()
	var caixa := _aabb_cena(raiz)
	var k := altura / maxf(caixa.size.y, 0.0001)
	raiz.scale = Vector3.ONE * k
	raiz.position = Vector3(-caixa.get_center().x * k, -caixa.position.y * k, -caixa.get_center().z * k)
	for mi in raiz.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		(mi as MeshInstance3D).extra_cull_margin = 4.0
	var embrulho := Node3D.new()
	var dentro := Node3D.new()
	dentro.add_child(raiz)
	embrulho.add_child(dentro)
	var ap: AnimationPlayer = null
	var achados := raiz.find_children("*", "AnimationPlayer", true, false)
	if achados.size() > 0:
		ap = achados[0]
		var lista := ap.get_animation_list()
		if lista.size() > 0:
			var anim := ap.get_animation(lista[0])
			anim.loop_mode = Animation.LOOP_LINEAR
			ap.set_meta("andar", lista[0])
	return {"root": embrulho, "inner": dentro, "ap": ap}


func _lugar_livre() -> Vector3:
	var b := _ilha
	for k in 80:
		var x: float = b["x0"] + b["w"] * 0.15 + randf() * b["w"] * 0.7
		var z: float = b["z0"] + b["h"] * 0.35 + randf() * (b["h"] * 0.6 - 0.8)
		var livre := true
		for t in _tiles:
			var tp: Vector3 = t["pos"]
			if (tp.x - x) * (tp.x - x) + (tp.z - z) * (tp.z - z) < 0.8:
				livre = false
				break
		if livre:
			return Vector3(x, 0, z)
	return Vector3(b["x0"] + 0.8, 0, b["z0"] + 0.8)


func _passo_mascote(m: Dictionary, dt: float, pos_vez, move_id, animando: bool) -> void:
	var st: Dictionary = m["st"]
	var root: Node3D = m["root"]
	# quando alguém anda, ele vai até perto do peão da vez para ver
	if move_id != null and move_id != st["last_follow"] and pos_vez != null:
		st["last_follow"] = move_id
		var dir := Vector3(root.position.x - pos_vez.x, 0, root.position.z - pos_vez.z)
		if dir.length_squared() < 0.01:
			dir = Vector3(1, 0, 0)
		dir = dir.normalized().rotated(Vector3.UP, 1.1 if m["slot"] else 0.0) * (1.9 if m["big"] else 1.4)
		st["target"] = Vector3(pos_vez.x + dir.x, 0, pos_vez.z + dir.z)
		st["mode"] = "watch"
		st["look"] = pos_vez
		st["wait"] = 0.0
	var alvo: Vector3 = st["target"]
	var para := Vector3(alvo.x - root.position.x, 0, alvo.z - root.position.z)
	var d := para.length()
	var vel := 1.1 if m["big"] else 0.9
	var andando := false
	if d > 0.08:
		andando = true
		root.position += para.normalized() * minf(d, vel * dt)
		var quer := atan2(para.x, para.z)
		root.rotation.y += angle_difference(root.rotation.y, quer) * minf(1.0, dt * 6.0)
		if m["big"] and _t - float(st["last_stomp"]) > 0.55:
			st["last_stomp"] = _t
			_tremor = maxf(_tremor, 0.05)
			_estouro(Vector3(root.position.x, 0.05, root.position.z), 4, [Color("#8a7a6e"), Color("#5a4a40")], 1.0, 0.8, 4.0, 0.5)
	else:
		st["wait"] = float(st["wait"]) - dt
		if st["look"] != null:
			var lk: Vector3 = st["look"]
			var quer := atan2(lk.x - root.position.x, lk.z - root.position.z)
			root.rotation.y += angle_difference(root.rotation.y, quer) * minf(1.0, dt * 4.0)
		if float(st["wait"]) <= 0.0 and not animando:
			if st["mode"] == "watch":
				st["mode"] = "idle"
				st["wait"] = 2.5 + randf() * 2.0
			else:
				st["mode"] = "wander"
				st["look"] = null
				st["target"] = _lugar_livre()
				st["wait"] = 1.5 + randf() * 3.0
	var ap: AnimationPlayer = m["ap"]
	var dentro: Node3D = m["inner"]
	var bob := 0.0
	if ap and ap.has_meta("andar"):
		if andando:
			if not ap.is_playing():
				ap.play(ap.get_meta("andar"))
		elif ap.is_playing():
			ap.stop()
	else:
		# sem animação no modelo: anda gingando
		st["walk_t"] = float(st["walk_t"]) + (dt * 7.0 if andando else 0.0)
		var k := 1.0 if andando else 0.0
		dentro.rotation.z += (sin(st["walk_t"]) * 0.12 * k - dentro.rotation.z) * 0.3
		dentro.rotation.x += ((0.08 if andando else 0.0) - dentro.rotation.x) * 0.1
		bob = absf(sin(st["walk_t"])) * 0.08 * k
	# pulinho de comemoração
	if float(st["cheer"]) > 0.0:
		st["cheer"] = float(st["cheer"]) - dt
		root.position.y = absf(sin(float(st["cheer"]) * 9.0)) * (0.25 if m["big"] else 0.45)
	else:
		root.position.y = bob if andando else sin(_t * 2.0) * 0.015


func comemorar() -> void:
	for m in _mascotes:
		m["st"]["cheer"] = 1.4


func tremer(v: float) -> void:
	_tremor = maxf(_tremor, v)


func _fogos(cor: Color) -> void:
	if _tiles.is_empty():
		return
	var tl: Vector3 = _tiles[_tiles.size() - 1]["pos"]
	var p := tl + Vector3((randf() - 0.5) * _raio, 2.5 + randf(), (randf() - 0.5) * _raio * 0.6)
	_estouro(p, 30, [cor, Color("#ffd23d"), Color.WHITE, Color("#ff6fb5"), Color("#5ec8ff")], 3.5, 1.5, 2.5, 1.6, 1.2)


# ---------- Partículas (poeira, brilhos, fogos, brasas) ----------
func _estouro(pos: Vector3, n: int, cores: Array, vel := 2.0, sobe := 2.0, grav := 6.0, vida := 0.8, tam := 1.0, espalha := 1.0) -> void:
	for i in n:
		if _particulas.size() > (160 if leve else 320):
			var velha: Dictionary = _particulas.pop_front()
			(velha["mesh"] as Node).queue_free()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = cores[i % cores.size()]
		var mi := MeshInstance3D.new()
		mi.mesh = _bolinha
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = pos
		var s0 := tam * (0.6 + randf() * 0.8)
		mi.scale = Vector3.ONE * s0
		add_child(mi)
		var a := randf() * TAU
		var sp := vel * (0.4 + randf() * 0.6)
		_particulas.append({"mesh": mi, "v": Vector3(cos(a) * sp * espalha, sobe * (0.5 + randf() * 0.8), sin(a) * sp * espalha), "g": grav, "life": vida, "t": 0.0, "s0": s0, "mat": mat})


func _passo_particulas(dt: float) -> void:
	for i in range(_particulas.size() - 1, -1, -1):
		var p: Dictionary = _particulas[i]
		p["t"] = float(p["t"]) + dt
		var mi: MeshInstance3D = p["mesh"]
		if p["t"] >= p["life"]:
			mi.queue_free()
			_particulas.remove_at(i)
			continue
		var v: Vector3 = p["v"]
		v.y -= float(p["g"]) * dt
		p["v"] = v
		mi.position += v * dt
		var k := 1.0 - float(p["t"]) / float(p["life"])
		(p["mat"] as StandardMaterial3D).albedo_color.a = minf(1.0, k * 1.6)
		mi.scale = Vector3.ONE * float(p["s0"]) * (0.4 + k * 0.6)


# ---------- Quadro a quadro ----------
func _process(delta: float) -> void:
	if S.is_empty() or _tiles.is_empty():
		return
	_t += delta
	var dt := minf(0.05, delta)
	var agora: float = relogio.call()
	var mv = S.get("move")
	var mvT := INF
	var animando := false
	var fim_dado := 0.0
	if mv != null:
		mvT = agora - float(mv["at"])
		animando = mvT < float(mv["dur"])
		fim_dado = DICE_MS if mv["kind"] == "dice" else 400.0

	# Onde cada peão está (o que se move segue o caminho casa a casa)
	var mostrar := {}
	for t in S["teams"]:
		mostrar[t["id"]] = {"pos": int(t["pos"]), "hop": null}
	if animando and mostrar.has(mv["teamId"]):
		var passos: Array = mv["path"]
		var tt := mvT - fim_dado
		if tt < 0.0:
			mostrar[mv["teamId"]]["pos"] = int(mv["from"])
		else:
			var k := int(floor(tt / HOP_MS))
			if k >= passos.size():
				mostrar[mv["teamId"]]["pos"] = int(passos[passos.size() - 1]) if passos.size() > 0 else int(mv["from"])
			else:
				var de := int(mv["from"]) if k == 0 else int(passos[k - 1])
				mostrar[mv["teamId"]]["pos"] = de
				mostrar[mv["teamId"]]["hop"] = {"from": de, "to": int(passos[k]), "f": (tt - k * HOP_MS) / HOP_MS}
				var chave := "%s:%d" % [mv["id"], k]
				if chave != _ultimo_pulo:
					_ultimo_pulo = chave
					pulou.emit(k, passos.size())
					if k > 0:
						_estouro(_pos_casa(int(passos[k - 1])) + Vector3(0, 0.2, 0), 6, [Color("#f3e3c3"), Color.WHITE], 1.2, 0.9, 5.0, 0.45)
	# agrupa por casa para não ficarem um em cima do outro
	var por_casa := {}
	for id in mostrar:
		if mostrar[id]["hop"] == null:
			var pc: int = mostrar[id]["pos"]
			if not por_casa.has(pc):
				por_casa[pc] = []
			por_casa[pc].append(id)

	var fase: String = S.get("phase", "lobby")
	var vez_id = null
	if S.get("turn") != null and fase != "lobby" and fase != "over":
		vez_id = S["turn"]["actingId"]
	for t in S["teams"]:
		if not _peoes.has(t["id"]):
			continue
		var p: Dictionary = _peoes[t["id"]]
		var g: Node3D = p["group"]
		var corpo: Node3D = p["body"]
		var s: Dictionary = mostrar[t["id"]]
		var y := 0.17
		if s["hop"] != null:
			var a := _pos_casa(s["hop"]["from"])
			var b := _pos_casa(s["hop"]["to"])
			var f := clampf(s["hop"]["f"], 0.0, 1.0)
			g.position = a.lerp(b, f)
			y += sin(f * PI) * 0.75
			var dir := b - a
			g.rotation.y = atan2(dir.x, dir.z)
			var amassa := 1.0 - (f - 0.85) * 1.6 if f > 0.85 else 1.0 + sin(f * PI) * 0.08
			corpo.scale = Vector3(1.0 / sqrt(amassa), amassa, 1.0 / sqrt(amassa))
		else:
			var lista: Array = por_casa.get(s["pos"], [t["id"]])
			g.position = _pos_casa(s["pos"]) + _deslocamento(lista.find(t["id"]), lista.size())
			g.rotation.y += (0.0 - g.rotation.y) * 0.15
			if t["id"] == vez_id and not animando:
				y += absf(sin(_t * 3.2)) * 0.18
			corpo.scale = corpo.scale.lerp(Vector3.ONE, 0.2)
		g.position.y = y

	# Anel e brilho da casa da equipe da vez
	for tl in _tiles:
		(tl["mat"] as StandardMaterial3D).emission_energy_multiplier = 0.0
		(tl["group"] as Node3D).position.y = (tl["pos"] as Vector3).y
	if vez_id != null and _peoes.has(vez_id):
		var equipe := _equipe(vez_id)
		var tl: Dictionary = _tiles[mini(int(equipe["pos"]), _tiles.size() - 1)]
		if not animando:
			(tl["mat"] as StandardMaterial3D).emission_energy_multiplier = 0.25 + sin(_t * 4.0) * 0.15
			_anel.visible = true
			(_anel.material_override as StandardMaterial3D).albedo_color = Color(equipe["color"])
			_anel.position = (tl["pos"] as Vector3) + Vector3(0, 0.2, 0)
			_anel.scale = Vector3.ONE * (1.0 + sin(_t * 4.0) * 0.12)
		else:
			_anel.visible = false
	elif _anel:
		_anel.visible = false
	# casa que acabou de receber o peão dá um pulinho
	if mv != null and (mv["path"] as Array).size() > 0:
		var dur := float(mv["dur"])
		if mvT > dur - 300.0 and _pousou_id != mv["id"] and mvT < dur + 1500.0:
			_pousou_id = mv["id"]
			var equipe := _equipe(mv["teamId"])
			var ult: Vector3 = _pos_casa(int(mv["path"][(mv["path"] as Array).size() - 1]))
			_estouro(ult + Vector3(0, 0.5, 0), 26, [Color(equipe["color"]) if not equipe.is_empty() else Color.WHITE, Color("#ffd23d"), Color.WHITE], 2.4, 3.0, 7.0, 0.9)
			_tremor = maxf(_tremor, 0.18 if mv["jumped"] else 0.08)
			pousou.emit(mv)
			comemorar()
		if mvT > dur - 300.0 and mvT < dur + 300.0:
			var tl: Dictionary = _tiles[int(mv["path"][(mv["path"] as Array).size() - 1])]
			var f := (mvT - (dur - 300.0)) / 600.0
			(tl["group"] as Node3D).position.y = (tl["pos"] as Vector3).y + sin(f * PI) * 0.18

	_passo_dados(mv, mvT)
	_passo_enfeites(dt)
	var pos_vez = null
	if vez_id != null and _peoes.has(vez_id):
		pos_vez = (_peoes[vez_id]["group"] as Node3D).position
	var mid = mv["id"] if mv != null and mvT < float(mv["dur"]) + 500.0 else null
	for m in _mascotes:
		_passo_mascote(m, dt, pos_vez, mid, animando)
	if fase == "over" and randf() < dt * 2.5:
		var vencedor := _equipe(S.get("winner"))
		_fogos(Color(vencedor["color"]) if not vencedor.is_empty() else Color("#ffd23d"))
	_passo_particulas(dt)
	_passo_camera(vez_id, animando)


func _equipe(id) -> Dictionary:
	for t in S.get("teams", []):
		if t["id"] == id:
			return t
	return {}


func _deslocamento(k: int, n: int) -> Vector3:
	if n <= 1:
		return Vector3.ZERO
	var a := float(k) / n * TAU + PI / 4.0
	return Vector3(cos(a) * 0.27, 0, sin(a) * 0.27)


func _semente(n: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = n
	return r


func _passo_dados(mv, mvT: float) -> void:
	if mv != null and mv["kind"] == "dice" and mvT < DICE_MS + 150.0:
		if _ultimo_dado != mv["id"]:
			_ultimo_dado = mv["id"]
			dado_rolou.emit()
		var r := _semente(int(mv["id"]) * 977 + int(mv["value"]))
		var queda := clampf(mvT / 1250.0, 0.0, 1.0)
		var chao := _pos_casa(int(mv["from"])).lerp(_centro, 0.35)
		_dado.visible = true
		var quique := absf(cos(queda * PI * 2.5)) * (1.0 - queda) * 3.2
		_dado.position = Vector3(chao.x + (1.0 - queda) * 2.5, 0.65 + quique, chao.z + (1.0 - queda) * 1.5)
		var alvo := Quaternion(FACE_NORMALS[DICE_FACES.find(int(mv["value"]))], Vector3.UP)
		alvo = Quaternion(Vector3.UP, r.randf() * TAU) * alvo
		var eixo := Vector3(r.randf() - 0.5, r.randf() - 0.5, r.randf() - 0.5).normalized()
		var giro := Quaternion(eixo, (1.0 - _ease(queda)) * PI * 6.0)
		var some := 1.0 - (mvT - (DICE_MS - 150.0)) / 300.0 if mvT > DICE_MS - 150.0 else 1.0
		_dado.transform.basis = Basis(giro * alvo).scaled(Vector3.ONE * maxf(0.01, some) * 1.1)
	else:
		_dado.visible = false
	if mv != null and mv["kind"] == "dice" and mv.get("catFace") != null and mvT < DICE_MS + 150.0:
		var r := _semente(int(mv["id"]) * 131 + 7)
		var queda := clampf((mvT - 120.0) / 1250.0, 0.0, 1.0)
		var chao := _pos_casa(int(mv["from"])).lerp(_centro, 0.35)
		_dado_cat.visible = true
		var quique := absf(cos(queda * PI * 2.5)) * (1.0 - queda) * 3.2
		_dado_cat.position = Vector3(chao.x + 1.25 + (1.0 - queda) * 2.8, 0.65 + quique, chao.z + 0.5 + (1.0 - queda) * 1.2)
		var alvo := Quaternion(FACE_NORMALS[CAT_FACES.find(mv["catFace"])], Vector3.UP)
		alvo = Quaternion(Vector3.UP, -0.35 + r.randf() * 0.2) * alvo
		var eixo := Vector3(r.randf() - 0.5, r.randf() - 0.5, r.randf() - 0.5).normalized()
		var giro := Quaternion(eixo, (1.0 - _ease(queda)) * PI * 6.0)
		var some := 1.0 - (mvT - (DICE_MS - 150.0)) / 300.0 if mvT > DICE_MS - 150.0 else 1.0
		_dado_cat.transform.basis = Basis(giro * alvo).scaled(Vector3.ONE * maxf(0.01, some) * 1.1)
		if queda >= 1.0 and _cat_mostrada != mv["id"]:
			_cat_mostrada = mv["id"]
			dado_categoria.emit(mv["catFace"])
			_estouro(_dado_cat.position, 14, [Color("#ffd23d"), Color.WHITE], 1.6, 1.5, 3.0, 0.7)
	else:
		_dado_cat.visible = false


static func _ease(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)


func _passo_enfeites(dt: float) -> void:
	for a in _anim:
		var no: Node3D = a[0]
		match String(a[1]):
			"gira":
				no.rotation.y = _t * 0.8
			"nuvem":
				no.position.x = a[2].x + sin(_t * a[2].y) * 1.5
			"balanca":
				no.rotation.z = sin(_t * 1.2 + a[2]) * 0.04
			"mar":
				no.position.y = -1.6 + sin(_t * 0.8) * 0.05
			"espuma":
				var k := 1.0 + sin(_t * 1.1) * 0.03
				no.scale = Vector3(a[2].x * k, 0.02, a[2].y * k)
	if _vulcao and _luz_vulcao:
		_luz_vulcao.light_energy = 4.0 + sin(_t * 3.0) * 1.2 + sin(_t * 7.3) * 0.5
		var topo := _vulcao.global_position + Vector3(0, 3.6 * _vulcao.scale.y, 0)
		if randf() < dt * 6.0:
			_estouro(topo, 1, [Color("#6a5e58"), Color("#8a7e78")], 0.3, 1.2, -0.4, 3.0, 4.0)
		if randf() < dt * 10.0:
			_estouro(topo, 1, [Color("#ff7a1a"), Color("#ffb02e")], 1.2, 3.0, 2.0, 1.6)
		# brasas flutuando pela ilha
		if randf() < dt * 4.0:
			_estouro(Vector3(_ilha["x0"] + randf() * _ilha["w"], 0.1, _ilha["z0"] + randf() * _ilha["h"]), 1, [Color("#ff8a2e")], 0.2, 0.6, -0.15, 3.0, 0.6)
	for f in _voadores:
		var tipo: String = f.get_meta("tipo")
		var a: float = f.get_meta("ph") + _t * f.get_meta("sp")
		var wob := sin(_t * 2.3 + f.get_meta("ph")) * 0.4 if tipo == "borboleta" else 0.0
		f.position = Vector3(f.get_meta("cx") + cos(a) * f.get_meta("rad") + wob, f.get_meta("alt") + sin(_t * 1.3 + f.get_meta("ph")) * (0.25 if tipo == "borboleta" else 0.3), f.get_meta("cz") + sin(a) * f.get_meta("rad") * 0.7)
		f.rotation.y = atan2(-sin(a) * f.get_meta("sp"), cos(a) * f.get_meta("sp") * 0.7)
		var bate: float = {"borboleta": 18.0, "passaro": 9.0, "ptero": 4.0}[tipo]
		var asa := sin(_t * bate + f.get_meta("ph")) * (0.45 if tipo == "ptero" else 0.8)
		(f.get_meta("L") as Node3D).rotation.z = asa
		(f.get_meta("R") as Node3D).rotation.z = -asa


# ---------- Câmera: visão geral que se aproxima um pouco de quem joga ----------
func _passo_camera(vez_id, animando: bool) -> void:
	var vp := get_viewport().get_visible_rect().size
	var aspecto := vp.x / maxf(vp.y, 1.0)
	var foco := _centro
	var tan_v := tan(deg_to_rad(camera.fov / 2.0))
	var tan_h := tan_v * aspecto
	var elev := atan2(0.82, 0.55)
	var meia_l: float = _ilha.get("w", 10.0) / 2.0 + 0.4
	var meia_p: float = _ilha.get("h", 8.0) / 2.0 + 0.4
	var ext_v := meia_p * sin(elev) + 1.6 * cos(elev)
	var dist := maxf(meia_l / tan_h, ext_v / tan_v) * 1.12 + meia_p * 0.35
	if vez_id != null and _peoes.has(vez_id):
		var pp: Vector3 = (_peoes[vez_id]["group"] as Node3D).position
		foco = foco.lerp(Vector3(pp.x, 0, pp.z), 0.35 if animando else 0.15)
		dist *= 0.9 if animando else 0.98
	dist *= zoom
	var balanco := sin(_t * 0.25) * 0.08
	var dirc := Vector3(0, 0.82, 0.55).normalized()
	var quer := Vector3(foco.x + sin(balanco) * dist * 0.3 * dirc.z, dist * dirc.y, foco.z + dist * dirc.z)
	if not _cam_ok:
		_cam_alvo = quer
		_cam_foco = foco
		_cam_ok = true
	_cam_alvo = _cam_alvo.lerp(quer, 0.04)
	_cam_foco = _cam_foco.lerp(foco, 0.05)
	var p := _cam_alvo
	if _tremor > 0.001:
		p += Vector3((randf() - 0.5) * _tremor, (randf() - 0.5) * _tremor, 0)
		_tremor *= pow(0.02, minf(0.05, get_process_delta_time()))
	camera.look_at_from_position(p, _cam_foco, Vector3.UP)
