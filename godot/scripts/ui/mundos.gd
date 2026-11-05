class_name EscolhaMundo
extends Control
## "Escolham o mundo!": três cartões ilustrados (Fácil, Médio, Difícil) com transição.

signal escolheu(nivel: String)

var atual := "kids"
var sugerido = null
var media = null
var _cartoes: Array = []
var _ocupado := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fundo := UI.fundo_escuro(0.78)
	add_child(fundo)
	var centro := CenterContainer.new()
	UI.cheio(centro)
	add_child(centro)
	var col := UI.vbox(16, BoxContainer.ALIGNMENT_CENTER)
	centro.add_child(col)
	col.add_child(UI.titulo("Escolham o mundo!", 54))
	col.add_child(UI.label("Média de idade: %s anos" % str(media) if media != null else "Cada mundo tem cartas mais fáceis ou mais difíceis. Dá para trocar depois.", 22))
	var linha := UI.hbox(26, BoxContainer.ALIGNMENT_CENTER)
	col.add_child(linha)
	var i := 0
	for k in ["kids", "familia", "adulto"]:
		var c := _cartao(k)
		linha.add_child(c)
		_cartoes.append(c)
		c.modulate.a = 0.0
		c.position.y += 60
		var t := create_tween().set_parallel()
		t.tween_property(c, "modulate:a", 1.0, 0.35).set_delay(0.08 * i)
		if k == atual:
			c.call_deferred("grab_focus")
		i += 1
	var fechar := UI.botao("Fechar", func(): Janelas.fechar(self), "BotaoGhost", 20)
	fechar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(fechar)
	Som.play("pop")


func _cartao(k: String) -> Button:
	var lv: Dictionary = Cartas.levels[k]
	var b := Button.new()
	b.custom_minimum_size = Vector2(250, 372)
	b.pivot_offset = Vector2(125, 186)
	var vazio := StyleBoxFlat.new()
	vazio.bg_color = Color.WHITE
	vazio.set_corner_radius_all(28)
	vazio.set_border_width_all(6)
	vazio.border_color = Tema.ACCENT if k == sugerido else Color.WHITE
	vazio.shadow_color = Color(0, 0, 0, 0.35)
	vazio.shadow_size = 1
	vazio.shadow_offset = Vector2(0, 12)
	for s in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(s, vazio)
	var foco := StyleBoxFlat.new()
	foco.draw_center = false
	foco.set_corner_radius_all(32)
	foco.set_border_width_all(6)
	foco.border_color = Tema.ACCENT
	foco.expand_margin_left = 6
	foco.expand_margin_right = 6
	foco.expand_margin_top = 6
	foco.expand_margin_bottom = 6
	b.add_theme_stylebox_override("focus", foco)
	var arte := TextureRect.new()
	arte.texture = UI.tex(UI.img_path("mundo_" + k))
	arte.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arte.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	arte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arte.offset_left = 6
	arte.offset_top = 6
	arte.offset_right = -6
	arte.offset_bottom = -6
	arte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(arte)
	var grad := TextureRect.new()
	var g := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(0, 0, 0, 0))
	gr.set_color(1, Color(0, 0, 0, 0.8))
	g.gradient = gr
	g.fill_from = Vector2(0, 0)
	g.fill_to = Vector2(0, 1)
	grad.texture = g
	grad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	grad.offset_top = -150
	grad.offset_left = 6
	grad.offset_right = -6
	grad.offset_bottom = -6
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(grad)
	var txt := UI.vbox(0)
	txt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	txt.offset_top = -100
	txt.offset_bottom = -16
	txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	txt.add_child(UI.titulo(lv["name"], 40))
	txt.add_child(UI.label(lv["sub"], 22))
	b.add_child(txt)
	if k == sugerido:
		var sel := UI.pilula("Sugerido", Tema.ACCENT, Tema.AZUL, 20)
		sel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		sel.position = Vector2(125 - 60, 14)
		sel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(sel)
	if k == atual:
		var esc := UI.pilula("Escolhido", Color.WHITE, Tema.AZUL, 18)
		esc.position = Vector2(250 - 130, 50 if k == sugerido else 14)
		esc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(esc)
	b.mouse_entered.connect(func():
		Som.play("pop", 0.3)
		create_tween().tween_property(b, "scale", Vector2(1.05, 1.05), 0.2).set_trans(Tween.TRANS_BACK))
	b.mouse_exited.connect(func(): create_tween().tween_property(b, "scale", Vector2.ONE, 0.2))
	b.focus_entered.connect(func(): create_tween().tween_property(b, "scale", Vector2(1.05, 1.05), 0.2))
	b.focus_exited.connect(func(): create_tween().tween_property(b, "scale", Vector2.ONE, 0.2))
	b.pressed.connect(func(): _escolher(k, b))
	return b


func _escolher(k: String, b: Button) -> void:
	if _ocupado:
		return
	_ocupado = true
	Som.play("brilho")
	if k == "adulto":
		Som.play("rugido", 0.8)
	escolheu.emit(k)
	for c in _cartoes:
		var t := create_tween().set_parallel()
		if c == b:
			t.tween_property(c, "scale", Vector2(1.25, 1.25), 0.5).set_trans(Tween.TRANS_BACK)
		else:
			t.tween_property(c, "modulate:a", 0.0, 0.3)
	var t2 := create_tween()
	t2.tween_interval(0.5)
	t2.tween_property(self, "modulate:a", 0.0, 0.4)
	t2.tween_callback(queue_free)
