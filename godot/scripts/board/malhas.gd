class_name Malhas
extends RefCounted
## Geometria feita por código para o tabuleiro: camadas da ilha, casas arredondadas,
## peças torneadas (peão, troféu), dados com faces pintadas.


## Retângulo de cantos arredondados no plano XZ (x, z), sentido anti-horário visto de cima.
static func retangulo_arredondado(x0: float, z0: float, w: float, h: float, r: float, seg := 8) -> PackedVector2Array:
	r = minf(r, minf(w, h) / 2.0 - 0.001)
	var pts := PackedVector2Array()
	var cantos := [
		[Vector2(x0 + w - r, z0 + h - r), 0.0],
		[Vector2(x0 + w - r, z0 + r), -PI / 2.0],
		[Vector2(x0 + r, z0 + r), -PI],
		[Vector2(x0 + r, z0 + h - r), -3.0 * PI / 2.0],
	]
	for c in cantos:
		var centro: Vector2 = c[0]
		var a0: float = c[1]
		for i in seg + 1:
			var a := a0 + PI / 2.0 - (PI / 2.0) * float(i) / seg
			pts.append(centro + Vector2(cos(a), sin(a)) * r)
	return pts


static func _normais_contorno(p: PackedVector2Array) -> PackedVector2Array:
	var area := 0.0
	var n := p.size()
	for i in n:
		var a := p[i]
		var b := p[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	var sinal := 1.0 if area > 0.0 else -1.0
	var out := PackedVector2Array()
	out.resize(n)
	for i in n:
		var ant := p[(i - 1 + n) % n]
		var prox := p[(i + 1) % n]
		var e1 := (p[i] - ant).normalized()
		var e2 := (prox - p[i]).normalized()
		var n1 := Vector2(e1.y, -e1.x) * sinal
		var n2 := Vector2(e2.y, -e2.x) * sinal
		out[i] = (n1 + n2).normalized()
	return out


## Triângulo com frente virada para "n" (o Godot desenha a face da frente em sentido horário).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var face := (b - a).cross(c - a)
	if face.dot(na + nb + nc) > 0.0:
		var t := b
		b = c
		c = t
		var tn := nb
		nb = nc
		nc = tn
	st.set_normal(na)
	st.add_vertex(a)
	st.set_normal(nb)
	st.add_vertex(b)
	st.set_normal(nc)
	st.add_vertex(c)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3) -> void:
	_tri(st, a, b, c, na, nb, nc)
	_tri(st, a, c, d, na, nc, nd)


## Placa extrudada com bisel em cima e embaixo: superfície 0 = tampa de cima, superfície 1 = laterais.
## contorno_fn(encolhe) devolve o contorno encolhido "encolhe" para dentro (mesmo número de pontos).
static func placa(contorno_fn: Callable, y_topo: float, y_base: float, bisel: float, seg_bisel := 3) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var fora: PackedVector2Array = contorno_fn.call(0.0)
	var dentro: PackedVector2Array = contorno_fn.call(bisel)
	var nfora := _normais_contorno(fora)
	# tampa de cima
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx := Geometry2D.triangulate_polygon(dentro)
	for i in range(0, idx.size(), 3):
		var a := Vector3(dentro[idx[i]].x, y_topo, dentro[idx[i]].y)
		var b := Vector3(dentro[idx[i + 1]].x, y_topo, dentro[idx[i + 1]].y)
		var c := Vector3(dentro[idx[i + 2]].x, y_topo, dentro[idx[i + 2]].y)
		_tri(st, a, b, c, Vector3.UP, Vector3.UP, Vector3.UP)
	st.commit(mesh)
	# laterais com bisel arredondado
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var aneis: Array = [] # [contorno, y, normal_y, peso_lateral]
	for k in seg_bisel + 1:
		var t := float(k) / seg_bisel * PI / 2.0
		aneis.append([contorno_fn.call(bisel * (1.0 - sin(t))), y_topo - bisel * (1.0 - cos(t)), cos(t), sin(t)])
	for k in range(seg_bisel, -1, -1):
		var t := float(k) / seg_bisel * PI / 2.0
		aneis.append([contorno_fn.call(bisel * (1.0 - sin(t))), y_base + bisel * (1.0 - cos(t)), -cos(t), sin(t)])
	var n := fora.size()
	for r in aneis.size() - 1:
		var A: Array = aneis[r]
		var B: Array = aneis[r + 1]
		var pa: PackedVector2Array = A[0]
		var pb: PackedVector2Array = B[0]
		for i in n:
			var j := (i + 1) % n
			var na_i := Vector3(nfora[i].x * A[3], A[2], nfora[i].y * A[3]).normalized()
			var na_j := Vector3(nfora[j].x * A[3], A[2], nfora[j].y * A[3]).normalized()
			var nb_i := Vector3(nfora[i].x * B[3], B[2], nfora[i].y * B[3]).normalized()
			var nb_j := Vector3(nfora[j].x * B[3], B[2], nfora[j].y * B[3]).normalized()
			_quad(st,
				Vector3(pa[i].x, A[1], pa[i].y), Vector3(pa[j].x, A[1], pa[j].y),
				Vector3(pb[j].x, B[1], pb[j].y), Vector3(pb[i].x, B[1], pb[i].y),
				na_i, na_j, nb_j, nb_i)
	st.commit(mesh)
	return mesh


## Placa com contorno de retângulo arredondado (camadas da ilha, base das casas).
static func placa_retangular(cx: float, cz: float, w: float, h: float, r: float, y_topo: float, y_base: float, bisel: float, seg := 8) -> ArrayMesh:
	var fn := func(e: float) -> PackedVector2Array:
		return retangulo_arredondado(cx - w / 2.0 + e, cz - h / 2.0 + e, w - 2.0 * e, h - 2.0 * e, maxf(r - e, 0.02), seg)
	return placa(fn, y_topo, y_base, bisel)


## Peça torneada a partir de um perfil (x = raio, y = altura), de baixo para cima.
static func torno(perfil: Array, segmentos := 32) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var np := perfil.size()
	var n2d: Array = []
	for i in np:
		var acc := Vector2.ZERO
		if i > 0:
			var d: Vector2 = perfil[i] - perfil[i - 1]
			acc += Vector2(d.y, -d.x).normalized()
		if i < np - 1:
			var d2: Vector2 = perfil[i + 1] - perfil[i]
			acc += Vector2(d2.y, -d2.x).normalized()
		n2d.append(acc.normalized())
	for s in segmentos:
		var a0 := TAU * s / segmentos
		var a1 := TAU * (s + 1) / segmentos
		for i in np - 1:
			var p0: Vector2 = perfil[i]
			var p1: Vector2 = perfil[i + 1]
			var m0: Vector2 = n2d[i]
			var m1: Vector2 = n2d[i + 1]
			var v00 := Vector3(p0.x * cos(a0), p0.y, p0.x * sin(a0))
			var v01 := Vector3(p0.x * cos(a1), p0.y, p0.x * sin(a1))
			var v10 := Vector3(p1.x * cos(a0), p1.y, p1.x * sin(a0))
			var v11 := Vector3(p1.x * cos(a1), p1.y, p1.x * sin(a1))
			var n00 := Vector3(m0.x * cos(a0), m0.y, m0.x * sin(a0))
			var n01 := Vector3(m0.x * cos(a1), m0.y, m0.x * sin(a1))
			var n10 := Vector3(m1.x * cos(a0), m1.y, m1.x * sin(a0))
			var n11 := Vector3(m1.x * cos(a1), m1.y, m1.x * sin(a1))
			if (v10 - v00).length() > 0.0001 and (v11 - v00).length() > 0.0001:
				_tri(st, v00, v10, v11, n00, n10, n11)
			if (v11 - v00).length() > 0.0001 and (v01 - v00).length() > 0.0001:
				_tri(st, v00, v11, v01, n00, n11, n01)
	return st.commit()


## Cubo com cada face numa célula de um atlas 3x2. Ordem das faces: +x, -x, +y, -y, +z, -z.
static func cubo_atlas(lado: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := lado / 2.0
	var normais := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	for f in 6:
		var nrm: Vector3 = normais[f]
		var u := Vector3.UP if absf(nrm.y) < 0.5 else Vector3.BACK
		var r := nrm.cross(u).normalized()
		u = r.cross(nrm).normalized()
		var cel := Vector2(f % 3, f / 3)
		var cantos := [[-1, -1], [1, -1], [1, 1], [-1, 1]]
		var vs: Array = []
		var uvs: Array = []
		for c in cantos:
			vs.append(nrm * h + r * h * c[0] + u * h * c[1])
			uvs.append((cel + Vector2((c[0] + 1) / 2.0, 1.0 - (c[1] + 1) / 2.0)) / Vector2(3, 2))
		for tri in [[0, 1, 2], [0, 2, 3]]:
			var a: Vector3 = vs[tri[0]]
			var b: Vector3 = vs[tri[1]]
			var c2: Vector3 = vs[tri[2]]
			var ua: Vector2 = uvs[tri[0]]
			var ub: Vector2 = uvs[tri[1]]
			var uc: Vector2 = uvs[tri[2]]
			if (b - a).cross(c2 - a).dot(nrm) > 0.0:
				var t := b
				b = c2
				c2 = t
				var tu := ub
				ub = uc
				uc = tu
			for p in [[a, ua], [b, ub], [c2, uc]]:
				st.set_normal(nrm)
				st.set_uv(p[1])
				st.add_vertex(p[0])
	return st.commit()


static func circulo_cheio(img: Image, c: Vector2, r: float, cor: Color) -> void:
	var x0 := int(floor(c.x - r - 1))
	var x1 := int(ceil(c.x + r + 1))
	var y0 := int(floor(c.y - r - 1))
	var y1 := int(ceil(c.y + r + 1))
	for y in range(maxi(y0, 0), mini(y1, img.get_height())):
		for x in range(maxi(x0, 0), mini(x1, img.get_width())):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(r - d + 0.5, 0.0, 1.0)
			if a > 0.0:
				var base := img.get_pixel(x, y)
				img.set_pixel(x, y, base.lerp(cor, a * cor.a))


## Textura do dado de pontinhos (atlas 3x2, 128 px por face).
static func textura_dado(valores: Array) -> ImageTexture:
	var img := Image.create(384, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var pips := {
		1: [[64, 64]], 2: [[34, 34], [94, 94]], 3: [[30, 30], [64, 64], [98, 98]], 4: [[34, 34], [94, 34], [34, 94], [94, 94]],
		5: [[30, 30], [98, 30], [64, 64], [30, 98], [98, 98]], 6: [[34, 28], [94, 28], [34, 64], [94, 64], [34, 100], [94, 100]],
	}
	for f in 6:
		var v: int = valores[f]
		var off := Vector2((f % 3) * 128, (f / 3) * 128)
		# cantinho cinza para parecer arredondado
		for p in pips[v]:
			circulo_cheio(img, off + Vector2(p[0], p[1]), 17.0 if v == 1 else 12.0, Color("#e8453c") if v == 1 else Color("#123a7a"))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Textura do dado de categoria: arte de cada categoria (a estrela vira a "categoria da casa").
static func textura_dado_categoria(faces: Array) -> ImageTexture:
	var img := Image.create(384, 256, false, Image.FORMAT_RGBA8)
	for f in 6:
		var face: String = faces[f]
		var off := Vector2i((f % 3) * 128, (f / 3) * 128)
		var cor := Cartas.cor(face) if face != "casa" else Color("#ffd23d")
		img.fill_rect(Rect2i(off, Vector2i(128, 128)), cor)
		if face != "casa":
			var arte: Texture2D = UI.tex(UI.img_path(face))
			if arte:
				var a := arte.get_image()
				a.decompress()
				a.convert(Image.FORMAT_RGBA8)
				a.resize(96, 96, Image.INTERPOLATE_BILINEAR)
				# recorta em círculo
				for y in 96:
					for x in 96:
						var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(48, 48))
						var c := a.get_pixel(x, y)
						c.a = clampf(46.0 - d + 0.5, 0.0, 1.0)
						a.set_pixel(x, y, c)
				circulo_cheio(img, Vector2(off) + Vector2(64, 64), 51.0, Color.WHITE)
				img.blend_rect(a, Rect2i(0, 0, 96, 96), off + Vector2i(16, 16))
		else:
			estrela(img, Vector2(off) + Vector2(64, 66), 50.0, 22.0, Color.WHITE)
			estrela(img, Vector2(off) + Vector2(64, 66), 40.0, 17.0, Color("#ff8a3d"))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func estrela(img: Image, c: Vector2, r_fora: float, r_dentro: float, cor: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var r := r_fora if i % 2 == 0 else r_dentro
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	for y in range(int(c.y - r_fora), int(c.y + r_fora) + 1):
		for x in range(int(c.x - r_fora), int(c.x + r_fora) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				img.set_pixel(x, y, cor)


## Bandeirinha quadriculada da largada.
static func textura_xadrez() -> ImageTexture:
	var img := Image.create(64, 40, false, Image.FORMAT_RGBA8)
	for x in 8:
		for y in 5:
			img.fill_rect(Rect2i(x * 8, y * 8, 8, 8), Color("#123a7a") if (x + y) % 2 else Color.WHITE)
	return ImageTexture.create_from_image(img)
