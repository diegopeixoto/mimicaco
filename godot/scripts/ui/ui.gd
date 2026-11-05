class_name UI
extends RefCounted
## Atalhos para montar a interface por código (todas as telas são feitas assim, sem cenas .tscn).

static var _tex := {}
static var _shader_circulo: Shader


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


static func img_path(nome: String) -> String:
	return "res://assets/img/%s.jpg" % nome


static func label(texto: String, tam := 22, cor := Color.WHITE, alinhar := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	if cor != Color.WHITE:
		l.add_theme_color_override("font_color", cor)
	l.horizontal_alignment = alinhar
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Label numa linha só (para dentro de HBox, onde a quebra automática esmaga o texto).
static func sem_quebra(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


static func muted(texto: String, tam := 19) -> Label:
	return label(texto, tam, Tema.MUTED)


static func titulo(texto: String, tam := 34, cor := Color.WHITE) -> Label:
	var l := label(texto, tam, cor)
	l.theme_type_variation = "Titulo"
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_constant_override("outline_size", maxi(4, int(tam / 4.0)))
	l.add_theme_constant_override("shadow_outline_size", maxi(4, int(tam / 4.0)))
	l.add_theme_constant_override("shadow_offset_y", maxi(2, int(tam / 9.0)))
	return l


## Título simples em Lilita, sem contorno (para dentro dos painéis).
static func h(texto: String, tam := 28, cor := Color.WHITE) -> Label:
	var l := label(texto, tam, cor)
	l.add_theme_font_override("font", Tema.fonte_titulo)
	return l


static func botao(texto: String, acao: Callable, variante := "", tam := 0) -> Button:
	var b := Button.new()
	b.text = texto
	if variante != "":
		b.theme_type_variation = variante
	if tam > 0:
		b.add_theme_font_size_override("font_size", tam)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func():
		Som.play("pop", 0.35)
		acao.call())
	return b


static func painel(conteudo: Control = null, variante := "") -> PanelContainer:
	var p := PanelContainer.new()
	if variante != "":
		p.theme_type_variation = variante
	if conteudo:
		p.add_child(conteudo)
	return p


static func vbox(sep := 10, alinhar := BoxContainer.ALIGNMENT_BEGIN) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.alignment = alinhar
	return v


static func hbox(sep := 10, alinhar := BoxContainer.ALIGNMENT_BEGIN) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", sep)
	hb.alignment = alinhar
	return hb


static func grade(colunas := 2, sep := 10) -> GridContainer:
	var g := GridContainer.new()
	g.columns = colunas
	g.add_theme_constant_override("h_separation", sep)
	g.add_theme_constant_override("v_separation", sep)
	return g


static func imagem(path: String, tamanho: Vector2, redonda := false, borda := 0.05) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if redonda else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = tamanho
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if redonda:
		if _shader_circulo == null:
			_shader_circulo = load("res://shaders/circulo.gdshader")
		var m := ShaderMaterial.new()
		m.shader = _shader_circulo
		m.set_shader_parameter("borda", borda)
		t.material = m
	return t


## Etiqueta arredondada colorida (categoria, equipe).
static func pilula(texto: String, cor: Color, cor_texto := Color.WHITE, tam := 22) -> PanelContainer:
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.set_corner_radius_all(99)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 2
	sb.content_margin_bottom = 4
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb)
	var l := label(texto, tam, cor_texto)
	l.add_theme_font_override("font", Tema.fonte_titulo)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	p.add_child(l)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return p


## Faixa amarela de aviso (como o .banner do web).
static func faixa(texto: String) -> PanelContainer:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tema.ACCENT
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 6
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb)
	var l := label(texto, 21, Tema.AZUL)
	l.add_theme_font_override("font", Tema.fonte_titulo)
	p.add_child(l)
	return p


static func espaco(alt := 8) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, alt)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func limpar(no: Node) -> void:
	for c in no.get_children():
		no.remove_child(c)
		c.queue_free()


static func cheio(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


## Cor do texto que fica legível em cima da cor dada.
static func contraste(c: Color) -> Color:
	return Tema.AZUL if c.get_luminance() > 0.62 else Color.WHITE


static func fundo_escuro(alpha := 0.6) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(Tema.AZUL, alpha)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r
