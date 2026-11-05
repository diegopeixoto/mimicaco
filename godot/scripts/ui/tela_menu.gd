class_name TelaMenu
extends Control
## Tela inicial: logo, Rawzinho e os dois jeitos de jogar.

var main: Node
var _primeiro: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sombra := ColorRect.new()
	sombra.color = Color(Tema.AZUL, 0.25)
	UI.cheio(sombra)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sombra)

	var centro := CenterContainer.new()
	UI.cheio(centro)
	add_child(centro)
	var col := UI.vbox(10, BoxContainer.ALIGNMENT_CENTER)
	col.custom_minimum_size = Vector2(760, 0)
	centro.add_child(col)

	var logo := UI.imagem("res://assets/img/logo.png", Vector2(300, 128))
	col.add_child(logo)
	col.add_child(UI.titulo("Mimicaço", 58))
	var heroi := UI.imagem(UI.img_path("hero"), Vector2(124, 124), true)
	col.add_child(heroi)
	var tag := UI.label("A mímica da Turma do Rawzinho! Joguem o dado e façam a mímica da carta.", 22)
	tag.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	tag.add_theme_constant_override("shadow_offset_y", 2)
	col.add_child(tag)

	var cartoes := UI.hbox(16, BoxContainer.ALIGNMENT_CENTER)
	col.add_child(cartoes)
	var a := UI.vbox(8)
	a.add_child(UI.h("Neste aparelho", 26))
	a.add_child(UI.muted("Tablet, notebook ou TV. O aparelho passa de mão em mão e só quem faz a mímica vê a carta."))
	_primeiro = UI.botao("Jogar aqui", main.jogar_local, "", 28)
	a.add_child(_primeiro)
	var pa := UI.painel(a)
	pa.custom_minimum_size = Vector2(360, 0)
	pa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cartoes.add_child(pa)
	var b := UI.vbox(8)
	b.add_child(UI.h("Com celulares", 26))
	b.add_child(UI.muted("Esta tela mostra o tabuleiro e cada celular vira o controle. Precisa de internet."))
	b.add_child(UI.botao("Criar sala", main.jogar_online, "BotaoBranco", 28))
	var pb := UI.painel(b)
	pb.custom_minimum_size = Vector2(360, 0)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cartoes.add_child(pb)

	var linha := UI.hbox(12, BoxContainer.ALIGNMENT_CENTER)
	col.add_child(linha)
	linha.add_child(UI.botao("Como jogar", func(): add_child(Janelas.regras()), "BotaoBranco", 20))
	linha.add_child(UI.botao("Opções", func(): add_child(Janelas.opcoes()), "BotaoBranco", 20))
	if not Config.eh_movel():
		linha.add_child(UI.botao("Sair", func(): get_tree().quit(), "BotaoBranco", 20))

	var rodape := UI.label("© Aquarela · Turma do Rawzinho · versão %s" % ProjectSettings.get_setting("application/config/version", "1.0"), 15, Color(1, 1, 1, 0.8))
	rodape.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	rodape.offset_top = -30
	rodape.offset_bottom = -6
	rodape.offset_left = -300
	rodape.offset_right = 300
	add_child(rodape)

	# entrada com pulinho
	col.modulate.a = 0.0
	col.scale = Vector2(0.96, 0.96)
	var tw := create_tween().set_parallel()
	tw.tween_property(col, "modulate:a", 1.0, 0.4)
	heroi.pivot_offset = Vector2(62, 62)
	heroi.scale = Vector2(0.3, 0.3)
	tw.tween_property(heroi, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_primeiro.call_deferred("grab_focus")
	Som.voz("boasvindas", 700)
