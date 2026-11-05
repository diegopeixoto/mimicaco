class_name CartaView
extends Control
## A carta que vira na frente do mímico: categoria, palavra, regra extra, trocar e começar.

signal trocar
signal comecar

const W := 380.0
const H := 470.0

var _card: Control
var _frente: PanelContainer
var _verso: PanelContainer
var _palavra: Label
var _cat_nome: Label
var _arte: TextureRect
var _regra: PanelContainer
var _bt_trocar: Button
var _bt_comecar: Button
var _dica: Label
var _cor := Color.WHITE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UI.fundo_escuro(0.82))
	var centro := CenterContainer.new()
	UI.cheio(centro)
	add_child(centro)
	var col := UI.vbox(14, BoxContainer.ALIGNMENT_CENTER)
	centro.add_child(col)
	col.add_child(UI.label("Só você pode ver! Leia e prepare a mímica.", 22, Tema.MUTED))
	_card = Control.new()
	_card.custom_minimum_size = Vector2(W, H)
	_card.pivot_offset = Vector2(W / 2.0, H / 2.0)
	_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_card)

	_frente = PanelContainer.new()
	_frente.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.add_child(_frente)
	var logo := UI.imagem("res://assets/img/logo.png", Vector2(300, 130))
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_frente.add_child(logo)

	_verso = PanelContainer.new()
	_verso.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_verso.add_theme_stylebox_override("panel", _caixa(Color.WHITE, Color.WHITE))
	_card.add_child(_verso)
	var v := UI.vbox(8, BoxContainer.ALIGNMENT_CENTER)
	_verso.add_child(v)
	_arte = UI.imagem(UI.img_path("acao"), Vector2(200, 200), true, 0.05)
	v.add_child(_arte)
	_cat_nome = UI.h("", 26)
	v.add_child(_cat_nome)
	_palavra = UI.label("", 44, Tema.AZUL)
	_palavra.add_theme_font_override("font", Tema.fonte_titulo)
	_palavra.custom_minimum_size = Vector2(W - 40, 0)
	v.add_child(_palavra)
	_regra = UI.pilula("", Tema.BAD, Color.WHITE, 22)
	v.add_child(_regra)

	var linha := UI.hbox(12, BoxContainer.ALIGNMENT_CENTER)
	col.add_child(linha)
	_bt_trocar = UI.botao("Trocar carta", func(): trocar.emit(), "BotaoGhost", 24)
	_bt_trocar.custom_minimum_size = Vector2(190, 70)
	linha.add_child(_bt_trocar)
	_bt_comecar = UI.botao("Começar!", func(): comecar.emit(), "BotaoBom", 32)
	_bt_comecar.custom_minimum_size = Vector2(220, 70)
	linha.add_child(_bt_comecar)
	_dica = UI.muted("Não conhece a palavra? Pode trocar uma vez.", 18)
	col.add_child(_dica)


func _caixa(bg: Color, borda: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(6)
	sb.border_color = borda
	sb.shadow_color = Color(10 / 255.0, 30 / 255.0, 70 / 255.0, 0.35)
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(0, 10)
	sb.set_content_margin_all(16)
	return sb


## Mostra a carta virando. steal = repescagem (não dá para trocar).
func mostrar(card: Dictionary, steal: bool) -> void:
	_preencher(card, steal)
	_frente.visible = true
	_verso.visible = false
	_card.scale = Vector2(0.7, 0.7)
	var t := create_tween()
	t.tween_property(_card, "scale", Vector2(0.0, 0.95), 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.15)
	t.tween_callback(func():
		_frente.visible = false
		_verso.visible = true)
	t.tween_property(_card, "scale", Vector2(1.05, 1.05), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_card, "scale", Vector2.ONE, 0.15)
	_bt_comecar.call_deferred("grab_focus")


## Depois de trocar a carta: vira de novo com a palavra nova.
func atualizar(card: Dictionary, steal: bool) -> void:
	var t := create_tween()
	t.tween_property(_card, "scale:x", 0.0, 0.18)
	t.tween_callback(func(): _preencher(card, steal))
	t.tween_property(_card, "scale:x", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _preencher(card: Dictionary, steal: bool) -> void:
	var cat: String = card["cat"]
	_cor = Cartas.cor(cat)
	_frente.add_theme_stylebox_override("panel", _caixa(_cor, Color.WHITE))
	_verso.add_theme_stylebox_override("panel", _caixa(Color.WHITE, _cor))
	_arte.texture = UI.tex(UI.img_path(cat))
	(_arte.material as ShaderMaterial).set_shader_parameter("cor_borda", _cor)
	_cat_nome.text = Cartas.nome(cat)
	_cat_nome.add_theme_color_override("font_color", _cor.darkened(0.15))
	_palavra.text = String(card.get("word", ""))
	_palavra.add_theme_font_size_override("font_size", 44 if _palavra.text.length() < 18 else (36 if _palavra.text.length() < 30 else 30))
	var tw = card.get("twist")
	_regra.visible = tw != null and String(tw) != ""
	if _regra.visible:
		(_regra.get_child(0) as Label).text = "Regra extra: %s" % tw
	var pode: bool = not steal and not card.get("swapped", false)
	_bt_trocar.disabled = not pode
	_bt_trocar.text = "Já trocou" if card.get("swapped", false) else "Trocar carta"
	_dica.visible = not steal
