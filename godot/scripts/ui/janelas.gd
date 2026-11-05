class_name Janelas
extends RefCounted
## Janelas por cima do jogo: regras, opções, confirmação, pausa, "passe o aparelho" e fim de jogo.


## Fundo escuro + painel central. Devolve [raiz, coluna_do_conteudo].
static func base(largura := 560.0, fecha_fora := true) -> Array:
	var raiz := Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	var escuro := UI.fundo_escuro(0.62)
	raiz.add_child(escuro)
	if fecha_fora:
		escuro.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed:
				fechar(raiz))
	var centro := CenterContainer.new()
	UI.cheio(centro)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(centro)
	var col := UI.vbox(12)
	col.custom_minimum_size = Vector2(largura, 0)
	var p := UI.painel(col)
	centro.add_child(p)
	p.pivot_offset = Vector2(largura / 2.0, 200)
	p.scale = Vector2(0.85, 0.85)
	p.modulate.a = 0.0
	raiz.ready.connect(func():
		var t := raiz.create_tween().set_parallel()
		t.tween_property(p, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(p, "modulate:a", 1.0, 0.2))
	return [raiz, col]


static func fechar(raiz: Control) -> void:
	if not is_instance_valid(raiz) or raiz.is_queued_for_deletion():
		return
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := raiz.create_tween()
	t.tween_property(raiz, "modulate:a", 0.0, 0.15)
	t.tween_callback(raiz.queue_free)


static func regras() -> Control:
	var b := base(680)
	var col: VBoxContainer = b[1]
	col.add_child(UI.titulo("Como jogar", 40))
	var txt := RichTextLabel.new()
	txt.bbcode_enabled = true
	txt.fit_content = true
	txt.scroll_active = false
	txt.add_theme_font_size_override("normal_font_size", 20)
	txt.add_theme_font_size_override("bold_font_size", 20)
	txt.add_theme_font_override("bold_font", Tema.fonte_titulo)
	txt.text = "\n".join([
		"[b]1.[/b] Montem de 2 a 6 equipes e escolham o mundo: [b]Fácil[/b] (crianças), [b]Médio[/b] (família) ou [b]Difícil[/b] (adultos). A média de idade sugere o mundo.",
		"[b]2.[/b] Na vez da equipe, joguem o dado. A cor da casa (ou o dado de categoria) diz a categoria da carta.",
		"[b]3.[/b] O mímico da vez (as pessoas da equipe revezam) pega o aparelho e vê a carta. Ninguém mais olha! Dá para trocar a carta uma vez.",
		"[b]4.[/b] Começa o tempo: a equipe tenta adivinhar só pela mímica, sem falar nada.",
		"[b]5.[/b] Acertou: joga de novo. Errou: a próxima equipe tenta a mesma carta com metade do tempo (repescagem) e, se acertar, anda +2.",
		"[b]Casa raio (Todos jogam):[/b] qualquer equipe pode adivinhar e quem acertar anda +3.",
		"[b]Casa +2 (Pulo do Rawzinho):[/b] anda mais duas casas.",
		"[b]Para vencer:[/b] chegar na casa do troféu e acertar a carta de Desafio dela.",
		"Às vezes a carta vem com uma [b]regra extra[/b], como \"só com uma mão\" ou \"em câmera lenta\".",
	])
	col.add_child(txt)
	var ok := UI.botao("Entendi!", func(): fechar(b[0]))
	col.add_child(ok)
	ok.call_deferred("grab_focus")
	return b[0]


static func opcoes() -> Control:
	var b := base(560)
	var col: VBoxContainer = b[1]
	col.add_child(UI.titulo("Opções", 40))
	col.add_child(UI.h("Som", 24, Tema.ACCENT))
	for par in [["musica", "Música"], ["vozes", "Falas do Rawzinho"], ["efeitos", "Efeitos"]]:
		var c := CheckButton.new()
		c.text = par[1]
		c.button_pressed = Som.opt[par[0]]
		var chave: String = par[0]
		c.toggled.connect(func(on: bool): Som.definir(chave, on))
		col.add_child(c)
	col.add_child(UI.h("Tela", 24, Tema.ACCENT))
	if not Config.eh_movel():
		var tc := CheckButton.new()
		tc.text = "Tela cheia"
		tc.button_pressed = Config.tela_cheia()
		tc.toggled.connect(func(on: bool): Config.definir_tela_cheia(on))
		col.add_child(tc)
	var fa := CheckButton.new()
	fa.text = "Fundo animado (vídeo)"
	fa.button_pressed = Config.fundo_animado()
	fa.toggled.connect(func(on: bool):
		Config.gravar("tela", "fundo_animado", on)
		for n in fa.get_tree().root.find_children("*", "Control", true, false):
			if n is Fundo:
				(n as Fundo).religar())
	col.add_child(fa)
	col.add_child(UI.h("Modo com celulares", 24, Tema.ACCENT))
	col.add_child(UI.muted("Endereço do servidor do jogo web:", 17))
	var srv := LineEdit.new()
	srv.text = Config.servidor()
	srv.text_changed.connect(func(t: String): Config.gravar("online", "servidor", t))
	col.add_child(srv)
	var ok := UI.botao("Fechar", func(): fechar(b[0]))
	col.add_child(ok)
	ok.call_deferred("grab_focus")
	return b[0]


static func confirmar(texto: String, sim: Callable, rotulo_sim := "Sim") -> Control:
	var b := base(480)
	var col: VBoxContainer = b[1]
	col.add_child(UI.h(texto, 26))
	var linha := UI.hbox(10, BoxContainer.ALIGNMENT_CENTER)
	var nao := UI.botao("Cancelar", func(): fechar(b[0]), "BotaoGhost")
	nao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := UI.botao(rotulo_sim, func():
		fechar(b[0])
		sim.call(), "BotaoRuim")
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(nao)
	linha.add_child(s)
	col.add_child(linha)
	nao.call_deferred("grab_focus")
	return b[0]


## "Passe o aparelho": só o mímico pode ver a carta.
static func cortina(nome: String, equipe: String, cor: Color, aviso: String, ok: Callable, pose := "raw_aponta") -> Control:
	var raiz := Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	var fundo := ColorRect.new()
	fundo.color = cor.darkened(0.45)
	UI.cheio(fundo)
	raiz.add_child(fundo)
	var faixa := ColorRect.new()
	faixa.color = Color(Tema.AZUL, 0.55)
	UI.cheio(faixa)
	raiz.add_child(faixa)
	var centro := CenterContainer.new()
	UI.cheio(centro)
	raiz.add_child(centro)
	var linha := UI.hbox(30, BoxContainer.ALIGNMENT_CENTER)
	centro.add_child(linha)
	var boneco := UI.imagem("res://assets/poses/%s.webp" % pose, Vector2(250, 390))
	linha.add_child(boneco)
	var col := UI.vbox(14, BoxContainer.ALIGNMENT_CENTER)
	col.custom_minimum_size = Vector2(560, 0)
	linha.add_child(col)
	if aviso != "":
		col.add_child(UI.faixa(aviso))
	col.add_child(UI.label("Passe o aparelho para", 26, Tema.MUTED))
	col.add_child(UI.titulo(nome, 66, Tema.ACCENT))
	col.add_child(UI.pilula(equipe, cor, UI.contraste(cor), 24))
	col.add_child(UI.label("Só %s pode ver a carta. O resto da turma: olhos fechados!" % nome, 24))
	var b := UI.botao("Sou %s: ver a carta" % nome, func():
		Som.play("carta")
		Janelas.fechar(raiz)
		ok.call(), "BotaoBom", 32)
	b.custom_minimum_size = Vector2(0, 86)
	col.add_child(b)
	b.call_deferred("grab_focus")
	boneco.pivot_offset = Vector2(125, 390)
	boneco.scale = Vector2(0.6, 0.6)
	raiz.ready.connect(func():
		var t := raiz.create_tween()
		t.tween_property(boneco, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var bal := raiz.create_tween().set_loops()
		bal.tween_property(boneco, "rotation", 0.05, 0.6).set_trans(Tween.TRANS_SINE)
		bal.tween_property(boneco, "rotation", -0.05, 0.6).set_trans(Tween.TRANS_SINE))
	return raiz


static func fim(estado: Dictionary, de_novo: Callable, menu: Callable) -> Control:
	var b := base(560, false)
	var col: VBoxContainer = b[1]
	var vencedor: Dictionary = {}
	for t in estado["teams"]:
		if t["id"] == estado.get("winner"):
			vencedor = t
	col.add_child(UI.imagem(UI.img_path("trofeu"), Vector2(200, 200), true))
	var cor := Color(vencedor.get("color", "#ffd23d"))
	col.add_child(UI.titulo("%s venceu!" % vencedor.get("name", "Alguém"), 48, cor.lightened(0.25)))
	var nomes: Array = []
	for p in vencedor.get("people", []):
		nomes.append(p["name"])
	if nomes.size() > 0:
		col.add_child(UI.muted(", ".join(nomes), 22))
	var r = estado.get("result")
	if r != null and r.get("word") != null:
		col.add_child(UI.label("Última carta: \"%s\"" % r["word"], 22))
	var bt := UI.botao("Jogar de novo", func():
		Janelas.fechar(b[0])
		de_novo.call(), "", 30)
	col.add_child(bt)
	col.add_child(UI.botao("Voltar ao menu", func():
		Janelas.fechar(b[0])
		menu.call(), "BotaoGhost"))
	bt.call_deferred("grab_focus")
	return b[0]


## Chuva de confete por cima de tudo.
static func confete(pai: Control, n := 140) -> void:
	var cores := [Color("#ffd23d"), Color("#5cc93a"), Color("#2f7bf5"), Color("#e8453c"), Color("#a26bff"), Color("#ff6fb5")]
	var tam := pai.get_viewport_rect().size
	for i in n:
		var c := ColorRect.new()
		c.color = cores[i % cores.size()]
		c.size = Vector2(12, 18)
		c.pivot_offset = Vector2(6, 9)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.position = Vector2(randf() * tam.x, -30)
		c.z_index = 100
		pai.add_child(c)
		var dur := 2.0 + randf() * 3.0
		var t := c.create_tween().set_parallel()
		t.tween_property(c, "position:y", tam.y + 40, dur).set_delay(randf() * 1.2)
		t.tween_property(c, "rotation", TAU * 2.0, dur).set_delay(randf() * 1.2)
		t.chain().tween_callback(c.queue_free)
