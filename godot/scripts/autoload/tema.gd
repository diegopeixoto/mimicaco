extends Node
## Visual da Turma do Rawzinho: fontes, cores, botões e painéis (mesmo estilo do jogo web).

const AZUL := Color("#123a7a")
const AZUL2 := Color("#1d4fa3")
const ROXO := Color("#2a2550")
const CARD := Color(18 / 255.0, 52 / 255.0, 120 / 255.0, 0.9)
const ACCENT := Color("#ffd23d")
const GOOD := Color("#4cc94a")
const BAD := Color("#ff5a5f")
const MUTED := Color("#cfe3ff")

var fonte_titulo: Font
var fonte_texto: Font
var theme := Theme.new()


func _ready() -> void:
	fonte_titulo = load("res://assets/fonte/LilitaOne-Regular.ttf")
	var baloo := FontVariation.new()
	baloo.base_font = load("res://assets/fonte/Baloo2.ttf")
	baloo.variation_opentype = {"wght": 700}
	fonte_texto = baloo
	_montar()


func _caixa(bg: Color, raio := 14, borda := 0, cor_borda := Color.TRANSPARENT, sombra := 4, mx := 18, my := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(raio)
	sb.corner_detail = 6
	sb.set_border_width_all(borda)
	sb.border_color = cor_borda
	if sombra > 0:
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 1
		sb.shadow_offset = Vector2(0, sombra)
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my
	sb.anti_aliasing = true
	return sb


func _botao(tipo: String, bg: Color, fg: Color, borda := 0, cor_borda := Color.TRANSPARENT, sombra := 4) -> void:
	var normal := _caixa(bg, 14, borda, cor_borda, sombra)
	var hover := _caixa(bg.lightened(0.12), 14, borda, cor_borda, sombra)
	var pressed := _caixa(bg.darkened(0.12), 14, borda, cor_borda, 1)
	pressed.content_margin_top += 3
	pressed.content_margin_bottom -= 3
	var disabled := _caixa(Color(bg, bg.a * 0.45), 14, borda, Color(cor_borda, cor_borda.a * 0.45), 0)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_corner_radius_all(16)
	focus.set_border_width_all(4)
	focus.border_color = Color.WHITE
	focus.expand_margin_left = 4
	focus.expand_margin_right = 4
	focus.expand_margin_top = 4
	focus.expand_margin_bottom = 4
	theme.set_stylebox("normal", tipo, normal)
	theme.set_stylebox("hover", tipo, hover)
	theme.set_stylebox("pressed", tipo, pressed)
	theme.set_stylebox("hover_pressed", tipo, pressed)
	theme.set_stylebox("disabled", tipo, disabled)
	theme.set_stylebox("focus", tipo, focus)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(c, tipo, fg)
	theme.set_color("font_disabled_color", tipo, Color(fg, 0.55))
	theme.set_font("font", tipo, fonte_titulo)
	theme.set_font_size("font_size", tipo, 24)


func _montar() -> void:
	theme.default_font = fonte_texto
	theme.default_font_size = 22
	theme.set_color("font_color", "Label", Color.WHITE)

	_botao("Button", ACCENT, AZUL)
	for v in ["BotaoGhost", "BotaoBom", "BotaoRuim", "BotaoBranco", "BotaoPerigo", "BotaoEquipe"]:
		theme.set_type_variation(v, "Button")
	_botao("BotaoGhost", Color(1, 1, 1, 0.12), Color.WHITE, 2, Color(1, 1, 1, 0.5), 0)
	_botao("BotaoBom", GOOD, Color.WHITE)
	_botao("BotaoRuim", BAD, Color.WHITE)
	_botao("BotaoBranco", Color.WHITE, ROXO, 3, ROXO)
	_botao("BotaoPerigo", Color("#ffe1dc"), Color("#b3261e"), 3, Color("#b3261e"))
	_botao("BotaoEquipe", Color.WHITE, Color.WHITE)

	# Painel azul translúcido com borda clara
	var painel := _caixa(CARD, 18, 3, Color(1, 1, 1, 0.35), 8, 18, 16)
	painel.shadow_color = Color(10 / 255.0, 30 / 255.0, 70 / 255.0, 0.35)
	theme.set_stylebox("panel", "PanelContainer", painel)
	theme.set_type_variation("PainelEscuro", "PanelContainer")
	var escuro := _caixa(Color(0, 0, 0, 0.18), 14, 0, Color.TRANSPARENT, 0, 12, 8)
	theme.set_stylebox("panel", "PainelEscuro", escuro)

	# Campos de texto brancos
	var campo := _caixa(Color.WHITE, 14, 0, Color.TRANSPARENT, 0, 14, 8)
	var campo_foco := _caixa(Color.WHITE, 14, 3, ACCENT, 0, 14, 8)
	theme.set_stylebox("normal", "LineEdit", campo)
	theme.set_stylebox("focus", "LineEdit", campo_foco)
	theme.set_stylebox("read_only", "LineEdit", campo)
	theme.set_color("font_color", "LineEdit", AZUL)
	theme.set_color("font_placeholder_color", "LineEdit", Color(AZUL, 0.45))
	theme.set_color("caret_color", "LineEdit", AZUL)
	theme.set_color("selection_color", "LineEdit", Color(ACCENT, 0.6))
	theme.set_font_size("font_size", "LineEdit", 22)

	# Listas de opção
	theme.set_stylebox("normal", "OptionButton", campo)
	theme.set_stylebox("hover", "OptionButton", campo)
	theme.set_stylebox("pressed", "OptionButton", campo)
	theme.set_stylebox("focus", "OptionButton", campo_foco)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(c, "OptionButton", AZUL)
	theme.set_font("font", "OptionButton", fonte_texto)
	theme.set_font_size("font_size", "OptionButton", 20)
	var popup := _caixa(Color.WHITE, 12, 2, AZUL, 4, 6, 6)
	theme.set_stylebox("panel", "PopupMenu", popup)
	theme.set_color("font_color", "PopupMenu", AZUL)
	theme.set_color("font_hover_color", "PopupMenu", AZUL)
	theme.set_stylebox("hover", "PopupMenu", _caixa(Color(ACCENT, 0.7), 8, 0, Color.TRANSPARENT, 0, 6, 4))
	theme.set_font_size("font_size", "PopupMenu", 22)

	# Liga/desliga
	theme.set_color("font_color", "CheckButton", Color.WHITE)
	theme.set_color("font_hover_color", "CheckButton", Color.WHITE)
	theme.set_color("font_pressed_color", "CheckButton", Color.WHITE)
	theme.set_color("font_hover_pressed_color", "CheckButton", Color.WHITE)
	theme.set_color("font_focus_color", "CheckButton", Color.WHITE)
	theme.set_stylebox("focus", "CheckButton", _caixa(Color(1, 1, 1, 0.12), 10, 0, Color.TRANSPARENT, 0, 4, 2))
	theme.set_font_size("font_size", "CheckButton", 20)

	# Barra do cronômetro
	theme.set_stylebox("background", "ProgressBar", _caixa(Color(0, 0, 0, 0.25), 99, 0, Color.TRANSPARENT, 0, 0, 0))
	theme.set_stylebox("fill", "ProgressBar", _caixa(ACCENT, 99, 0, Color.TRANSPARENT, 0, 0, 0))

	# Títulos com contorno azul, como no web
	theme.set_type_variation("Titulo", "Label")
	theme.set_font("font", "Titulo", fonte_titulo)
	theme.set_font_size("font_size", "Titulo", 34)
	theme.set_color("font_outline_color", "Titulo", AZUL)
	theme.set_constant("outline_size", "Titulo", 10)
	theme.set_color("font_shadow_color", "Titulo", AZUL)
	theme.set_constant("shadow_offset_y", "Titulo", 4)
	theme.set_constant("shadow_offset_x", "Titulo", 0)
	theme.set_constant("shadow_outline_size", "Titulo", 10)
	theme.set_type_variation("Muted", "Label")
	theme.set_color("font_color", "Muted", MUTED)

	theme.set_constant("separation", "VBoxContainer", 10)
	theme.set_constant("separation", "HBoxContainer", 10)
	theme.set_stylebox("panel", "TooltipPanel", _caixa(Color.WHITE, 8, 0, Color.TRANSPARENT, 0, 8, 4))
	theme.set_color("font_color", "TooltipLabel", AZUL)
