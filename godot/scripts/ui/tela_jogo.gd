class_name TelaJogo
extends Control
## Tela da partida: tabuleiro 3D à esquerda, painel à direita (preparação e cada fase da vez).
## Funciona igual nos dois modos: passa-e-joga (SalaLocal) e com celulares (SalaOnline).

const LATERAL_JOGO := 420.0
const LATERAL_LOBBY := 520.0

var main: Node
var sala: Node
var S: Dictionary = {}

var _area: Control
var _svp: SubViewport
var _tab: Tabuleiro3D
var _lateral: Control
var _conteudo: VBoxContainer
var _reacao: Reacao
var _toast: PanelContainer
var _toast_txt: Label
var _toast_tw: Tween
var _mundo_pill: Control
var _sala_lbl: Label
var _sala_pill: Control
var _carta: CartaView
var _cortina: Control
var _timer_lbl: Label
var _barra: ProgressBar
var _palavra_espiada: Label
var _largura := LATERAL_LOBBY
var _ultima_fase := ""
var _ultimo_result = null
var _ultimo_move = null
var _ultimo_acting = null
var _mundos_perguntado := false
var _fim: Control
var _refocar := ""
var _ultimo_seg := -1
var _qr: Texture2D
var _pendente_render := false
var _nivel_mostrado := ""
var _conectado := true


func _local() -> bool:
	return sala is SalaLocal


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_area = Control.new()
	_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_area.offset_right = -_largura
	add_child(_area)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.add_child(svc)
	_svp = SubViewport.new()
	_svp.transparent_bg = true
	_svp.own_world_3d = true
	_svp.msaa_3d = Viewport.MSAA_2X if Config.eh_movel() else Viewport.MSAA_4X
	svc.add_child(_svp)
	_tab = Tabuleiro3D.new()
	_tab.leve = Config.eh_movel()
	_tab.relogio = func() -> float: return sala.agora()
	_svp.add_child(_tab)
	_tab.dado_rolou.connect(func(): Som.play("dado"))
	_tab.pulou.connect(func(_k: int, _n: int):
		if _nivel() == "adulto":
			Som.play("pisada", 0.6)
		else:
			Som.play("pulo", 0.45))
	_tab.pousou.connect(func(mv: Dictionary):
		Som.play("brilho", 0.5)
		if mv.get("jumped", false) and _nivel() == "adulto":
			Som.play("rugido", 0.7))
	_tab.dado_categoria.connect(func(face: String):
		Som.play("brilho", 0.6)
		mostrar_toast("Dado de categoria: %s" % (Cartas.nome(face) if face != "casa" else "vale a categoria da casa"), 1.6))

	# cabeçalho: logo e nome; embaixo, o mundo e (no modo com celulares) o código da sala
	var cab := UI.hbox(10)
	cab.position = Vector2(14, 10)
	cab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.add_child(cab)
	cab.add_child(UI.imagem("res://assets/img/logo.png", Vector2(150, 64)))
	var cab_col := UI.vbox(4)
	cab_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cab.add_child(cab_col)
	var tit := UI.sem_quebra(UI.titulo("Mimicaço", 34))
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	cab_col.add_child(tit)
	var cab_linha := UI.hbox(8)
	cab_col.add_child(cab_linha)
	_mundo_pill = Control.new()
	cab_linha.add_child(_mundo_pill)
	_sala_lbl = UI.sem_quebra(UI.label("", 20))
	_sala_lbl.add_theme_font_override("font", Tema.fonte_titulo)
	_sala_pill = UI.pilula("", Tema.ACCENT, Tema.AZUL, 20)
	_sala_lbl = _sala_pill.get_child(0)
	_sala_pill.visible = false
	cab_linha.add_child(_sala_pill)

	var menu := UI.botao("Menu", _pausa, "BotaoBranco", 20)
	menu.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu.offset_left = -112
	menu.offset_right = -14
	menu.offset_top = 12
	menu.offset_bottom = 60
	_area.add_child(menu)

	_reacao = Reacao.new()
	_reacao.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_area.add_child(_reacao)

	_toast_txt = UI.sem_quebra(UI.label("", 26))
	_toast_txt.add_theme_font_override("font", Tema.fonte_titulo)
	_toast = UI.painel(_toast_txt)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.offset_bottom = -30
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	_area.add_child(_toast)

	_lateral = Control.new()
	_lateral.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_lateral.offset_left = -_largura
	add_child(_lateral)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 8
	scroll.offset_right = -12
	scroll.offset_top = 12
	scroll.offset_bottom = -12
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_lateral.add_child(scroll)
	_conteudo = UI.vbox(12)
	_conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_conteudo)

	sala.mudou.connect(_on_estado)
	if sala is SalaOnline:
		var so := sala as SalaOnline
		so.erro.connect(_erro_online)
		so.sala_criada.connect(func(code: String):
			_sala_lbl.text = "Sala %s" % code
			_sala_pill.visible = true
			so.baixar_qr(func(t):
				_qr = t
				_render()))
		so.conexao.connect(func(ok: bool):
			_conectado = ok
			if not ok:
				mostrar_toast("Reconectando…", 3.0))
		_aguardando()
	if not sala.estado.is_empty():
		_on_estado(sala.estado)


func _nivel() -> String:
	return S.get("settings", {}).get("level", "kids")


func _agora() -> float:
	return sala.agora()


func _animando() -> bool:
	var mv = S.get("move")
	return mv != null and _agora() < float(mv["at"]) + float(mv["dur"])


func _equipe(id) -> Dictionary:
	for t in S.get("teams", []):
		if t["id"] == id:
			return t
	return {}


func _idx_equipe(id) -> int:
	var ts: Array = S.get("teams", [])
	for i in ts.size():
		if ts[i]["id"] == id:
			return i
	return 0


## Equipes alternam o mascote: 1ª Rawzinho, 2ª Toninho, 3ª Rawzinho...
func _mascote(id) -> String:
	return "toninho" if _idx_equipe(id) % 2 == 1 else "rawzinho"


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_pausa()


# ---------- Estado ----------
func _on_estado(st: Dictionary) -> void:
	S = st
	_tab.atualizar(S)
	_aplicar_mundo()
	_eventos()
	var digitando := false
	var foco := get_viewport().gui_get_focus_owner()
	if foco is LineEdit and _conteudo.is_ancestor_of(foco) and not _local():
		digitando = true
	if digitando:
		_pendente_render = true
	else:
		_render()
	_fluxo_local()
	_janela_fim()
	var mv = S.get("move")
	if mv != null and mv["id"] != _ultimo_move:
		_ultimo_move = mv["id"]
		var falta := float(mv["at"]) + float(mv["dur"]) - _agora()
		get_tree().create_timer(maxf(0.0, falta / 1000.0) + 0.06).timeout.connect(func():
			if is_instance_valid(self):
				_render())
	if S["phase"] == "lobby" and not _mundos_perguntado:
		_mundos_perguntado = true
		get_tree().create_timer(0.5).timeout.connect(func():
			if is_instance_valid(self) and S["phase"] == "lobby":
				_abrir_mundos())
	if S["phase"] in ["card", "miming", "timeup"] and S.get("turn") != null:
		_ultimo_acting = S["turn"]["actingId"]
	_ultima_fase = S["phase"]


func _aplicar_mundo() -> void:
	var lv := _nivel()
	if lv == _nivel_mostrado:
		return
	_nivel_mostrado = lv
	main.fundo.mundo(lv)
	Som.trilha("musica" if lv == "kids" else "musica_" + lv)
	for c in _mundo_pill.get_children():
		c.queue_free()
	var l: Dictionary = Cartas.levels[lv]
	var p := UI.pilula("%s · %s" % [l["name"], l["sub"]], Color(Tema.AZUL, 0.85), Color.WHITE, 20)
	_mundo_pill.add_child(p)
	_mundo_pill.custom_minimum_size = p.get_combined_minimum_size()


func _eventos() -> void:
	# na primeira atualização só anota o resultado que já existia (reconexão), sem aviso
	var r = S.get("result")
	if _ultimo_result == null:
		_ultimo_result = r["id"] if r != null else 0
	elif r != null and r["id"] != _ultimo_result:
		_ultimo_result = r["id"]
		var t := _equipe(r.get("teamId"))
		var quem := _mascote(r["teamId"] if r.get("teamId") != null else _ultimo_acting)
		if r["kind"] == "miss":
			Som.play("errou")
			Som.voz("errou", 300)
			_reacao.tocar("errou", quem)
			mostrar_toast("A palavra era \"%s\"" % r["word"] if r.get("word") != null else "Repescagem! A próxima equipe tenta.", 2.4)
		else:
			Som.play("acertou")
			Som.voz("acertou", 300)
			Som.play("torcida", 0.5)
			_tab.comemorar()
			_reacao.tocar("acertou", quem)
			mostrar_toast("%s%s · \"%s\"" % ["Roubou! " if r["kind"] == "steal_hit" else "", t.get("name", ""), r.get("word", "")], 2.4)
	var fase: String = S["phase"]
	if fase == _ultima_fase:
		return
	if fase == "turn" and _ultima_fase != "" and _ultima_fase != "lobby":
		Som.voz("suavez", 2600)
	if fase == "turn" and _ultima_fase == "lobby":
		Som.voz("suavez", 300)
		if _nivel() == "adulto":
			Som.play("rugido", 0.8)
	if fase == "draw" and S.get("turn") != null:
		var eq := _equipe(S["turn"]["teamId"])
		var sq: Dictionary = S["board"][int(eq["pos"])]
		if sq["type"] == "all":
			var mv = S.get("move")
			var espera := maxf(0.0, float(mv["at"]) + float(mv["dur"]) - _agora()) if mv != null else 0.0
			Som.voz("todos", int(espera) + 50)
	if fase == "card" and _ultima_fase == "draw":
		Som.play("tambor", 0.6)
	elif fase == "card" and not _local():
		Som.play("carta")
	if fase == "timeup" and _ultima_fase == "miming":
		Som.play("tempo")
		Som.voz("tempo", 900)
	if fase == "over":
		Som.play("vitoria")
		Som.voz("vitoria", 1800)
		Som.play("fogos", 0.6)
		get_tree().create_timer(0.6).timeout.connect(func(): Som.play("torcida", 0.6))
		if _nivel() == "adulto":
			get_tree().create_timer(1.2).timeout.connect(func(): Som.play("rugido", 0.9))
		_tab.tremer(0.25)


func mostrar_toast(texto: String, seg := 2.0) -> void:
	_toast_txt.text = texto
	if _toast_tw:
		_toast_tw.kill()
	_toast.reset_size()
	_toast.offset_left = -_toast.size.x / 2.0
	_toast.offset_right = _toast.size.x / 2.0
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tw.tween_interval(seg)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.3)


# ---------- Passa-e-joga: cortina, carta e repescagem ----------
func _fluxo_local() -> void:
	if not _local():
		return
	var fase: String = S["phase"]
	if fase == "card":
		if _ultima_fase == "draw" and _carta == null:
			_abrir_carta()
		elif _ultima_fase in ["miming", "timeup"] and S["turn"]["steal"]:
			# deixa a reação do "errou" aparecer antes de passar o aparelho
			get_tree().create_timer(1.4).timeout.connect(func():
				if is_instance_valid(self) and S["phase"] == "card" and _carta == null and _cortina == null:
					_abrir_cortina())
		elif _carta != null:
			_carta.atualizar(S["card"], S["turn"]["steal"])
	elif _carta != null:
		Janelas.fechar(_carta)
		_carta = null


func _nome_mimico() -> String:
	var t = S.get("turn")
	if t != null and t.get("mimer") != null:
		return t["mimer"]["name"]
	var eq := _equipe(t["actingId"]) if t != null else {}
	return "alguém da %s" % eq.get("name", "equipe")


func _abrir_cortina() -> void:
	if _cortina != null and is_instance_valid(_cortina):
		return
	var t: Dictionary = S["turn"]
	var eq := _equipe(t["actingId"])
	var aviso := "Repescagem! %s tenta a mesma carta, com metade do tempo." % eq["name"] if t["steal"] else ""
	var pose := "ton_parado" if _mascote(eq["id"]) == "toninho" else "raw_aponta"
	_cortina = Janelas.cortina(_nome_mimico(), eq["name"], Color(eq["color"]), aviso, func():
		_cortina = null
		if S["phase"] == "draw":
			sala.send({"t": "draw"})
		elif S["phase"] == "card":
			_abrir_carta(), pose)
	add_child(_cortina)


func _abrir_carta() -> void:
	if _carta != null or S.get("card") == null:
		return
	_carta = CartaView.new()
	add_child(_carta)
	_carta.mostrar(S["card"], S["turn"]["steal"])
	Som.play("carta")
	_carta.trocar.connect(func(): sala.send({"t": "swap_card"}))
	_carta.comecar.connect(func():
		var c := _carta
		_carta = null
		Janelas.fechar(c)
		sala.send({"t": "go"}))


# ---------- Painel lateral ----------
func _definir_largura(w: float) -> void:
	if is_equal_approx(w, _largura):
		return
	_largura = w
	var t := create_tween().set_parallel()
	t.tween_property(_lateral, "offset_left", -w, 0.3).set_trans(Tween.TRANS_SINE)
	t.tween_property(_area, "offset_right", -w, 0.3).set_trans(Tween.TRANS_SINE)


func _render() -> void:
	if S.is_empty():
		return
	_pendente_render = false
	UI.limpar(_conteudo)
	_timer_lbl = null
	_barra = null
	_palavra_espiada = null
	if S["phase"] == "lobby":
		_definir_largura(LATERAL_LOBBY)
		if _local():
			_lobby_local()
		else:
			_lobby_online()
	else:
		_definir_largura(LATERAL_JOGO)
		_painel_vez()
		_painel_equipes()
		var linha := UI.hbox(10)
		var pv := UI.botao("Pular vez", func(): sala.send({"t": "skip_turn"}), "BotaoBranco", 19)
		pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var enc := UI.botao("Encerrar partida", _encerrar, "BotaoPerigo", 19)
		enc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha.add_child(pv)
		linha.add_child(enc)
		_conteudo.add_child(linha)
	if _refocar != "":
		var alvo := _conteudo.find_child(_refocar, true, false)
		if alvo is Control:
			(alvo as Control).call_deferred("grab_focus")
		_refocar = ""


func _secao(titulo := "") -> VBoxContainer:
	var v := UI.vbox(10)
	if titulo != "":
		v.add_child(UI.h(titulo, 26))
	var p := UI.painel(v)
	_conteudo.add_child(p)
	return v


func _bloco_categoria(cat: String, twist = null, tam := 130.0) -> VBoxContainer:
	var v := UI.vbox(6)
	v.add_child(UI.imagem(UI.img_path(cat), Vector2(tam, tam), true))
	var c := Cartas.cor(cat)
	v.add_child(UI.pilula(Cartas.nome(cat), c, UI.contraste(c), 22))
	if twist != null and String(twist) != "":
		v.add_child(UI.pilula("Regra extra: %s" % twist, Tema.BAD, Color.WHITE, 18))
	return v


func _pilula_equipe(t: Dictionary, tam := 24) -> Control:
	var c := Color(t["color"])
	return UI.pilula(t["name"], c, UI.contraste(c), tam)


func _painel_vez() -> void:
	var v := _secao()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var turn: Dictionary = S["turn"]
	var equipe := _equipe(turn["teamId"])
	var acting := _equipe(turn["actingId"])
	var anim := _animando()
	var msg: String = S.get("message", "")
	match String(S["phase"]):
		"turn":
			if msg != "":
				v.add_child(UI.faixa(msg))
			v.add_child(UI.imagem(UI.img_path("toninho" if int(turn["teamIdx"]) % 2 else "hero"), Vector2(140, 140), true))
			v.add_child(UI.h("Vez da", 26))
			v.add_child(_pilula_equipe(equipe, 28))
			v.add_child(UI.label("Joguem o dado!" if _local() else "Joguem o dado no celular!", 22))
			var b := UI.botao("Jogar o dado", func(): sala.send({"t": "roll"}), "", 30)
			b.disabled = anim
			b.custom_minimum_size = Vector2(0, 76)
			v.add_child(b)
			b.call_deferred("grab_focus")
		"draw":
			var sq: Dictionary = S["board"][int(equipe["pos"])]
			if anim:
				v.add_child(_pilula_equipe(equipe))
				var mv = S.get("move")
				v.add_child(UI.label("Tirou %s no dado…" % (str(int(mv["value"])) if mv != null and mv.get("value") != null else ""), 26, Tema.ACCENT))
				return
			if msg != "":
				v.add_child(UI.faixa(msg))
			var face = turn.get("catFace")
			if sq["type"] == "all":
				v.add_child(UI.imagem(UI.img_path("todos"), Vector2(130, 130), true))
				v.add_child(UI.h("Todos jogam!", 30, Tema.ACCENT))
				v.add_child(UI.muted("Qualquer equipe pode adivinhar. Quem acertar anda +3 casas."))
			elif sq["type"] == "finish":
				v.add_child(_bloco_categoria("dificil"))
				v.add_child(UI.h("Última casa! Acertem para vencer!", 24, Tema.ACCENT))
			else:
				v.add_child(_bloco_categoria(face if face != null and face != "casa" else String(sq.get("cat", "acao"))))
			if face != null and sq["type"] != "finish":
				v.add_child(UI.muted("Dado de categoria: %s" % ("vale a categoria da casa" if face == "casa" else "mandou essa!")))
			if _local():
				v.add_child(UI.label("Quem faz a mímica:", 20, Tema.MUTED))
				v.add_child(UI.h(_nome_mimico(), 34, Tema.ACCENT))
				var b := UI.botao("Puxar carta", _abrir_cortina, "", 30)
				b.custom_minimum_size = Vector2(0, 76)
				v.add_child(b)
				b.call_deferred("grab_focus")
				v.add_child(UI.botao("Trocar mímico", func(): sala.send({"t": "skip_mimer"}), "BotaoGhost", 18))
			else:
				v.add_child(UI.label("%s, puxe a carta no celular." % _nome_mimico(), 22))
				var l := UI.hbox(10)
				var tm := UI.botao("Trocar mímico", func(): sala.send({"t": "skip_mimer"}), "BotaoGhost", 18)
				var pd := UI.botao("Puxar daqui", func(): sala.send({"t": "draw"}), "BotaoGhost", 18)
				tm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				pd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				l.add_child(tm)
				l.add_child(pd)
				v.add_child(l)
		"card":
			if turn["steal"]:
				v.add_child(UI.faixa("Repescagem! %s tenta a mesma carta" % acting["name"]))
			v.add_child(UI.h("%s está lendo a carta…" % _nome_mimico(), 26))
			v.add_child(_bloco_categoria(S["card"]["cat"], S["card"].get("twist")))
			if _local():
				var b := UI.botao("Ver a carta", _abrir_cortina, "", 26)
				v.add_child(b)
			else:
				_palavra_espiada = UI.h("", 32, Tema.ACCENT)
				v.add_child(_palavra_espiada)
				var l := UI.hbox(10)
				var esp := UI.botao("Segure p/ espiar", func(): pass, "BotaoGhost", 18)
				esp.button_down.connect(func(): sala.send({"t": "peek", "on": true}))
				esp.button_up.connect(func(): sala.send({"t": "peek", "on": false}))
				var go := UI.botao("Começar", func(): sala.send({"t": "go"}), "", 22)
				esp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				l.add_child(esp)
				l.add_child(go)
				v.add_child(l)
				if S["card"].get("word") != null:
					_palavra_espiada.text = S["card"]["word"]
		"miming", "timeup":
			if turn["steal"]:
				v.add_child(UI.faixa("Repescagem"))
			if turn["allPlay"]:
				v.add_child(UI.h("Todos jogam!", 30, Tema.ACCENT))
			else:
				v.add_child(_pilula_equipe(acting, 26))
			v.add_child(_bloco_categoria(S["card"]["cat"], S["card"].get("twist"), 100))
			if S["phase"] == "timeup":
				v.add_child(UI.imagem(UI.img_path("tempo"), Vector2(96, 96), true))
			_timer_lbl = UI.h("Tempo!" if S["phase"] == "timeup" else "", 76)
			v.add_child(_timer_lbl)
			_barra = ProgressBar.new()
			_barra.show_percentage = false
			_barra.custom_minimum_size = Vector2(0, 14)
			_barra.max_value = 1.0
			_barra.value = 0.0 if S["phase"] == "timeup" else 1.0
			v.add_child(_barra)
			if _local():
				_palavra_espiada = UI.h("", 32, Tema.ACCENT)
				v.add_child(_palavra_espiada)
				var esp := UI.botao("Segure para ver a palavra", func(): pass, "BotaoGhost", 18)
				esp.button_down.connect(func(): _palavra_espiada.text = S["card"]["word"])
				esp.button_up.connect(func(): _palavra_espiada.text = "")
				v.add_child(esp)
			if S.get("hasJudge", false):
				v.add_child(UI.muted("O juiz decide no celular"))
			if turn["allPlay"]:
				for t in S["teams"]:
					var c := Color(t["color"])
					var b := UI.botao("%s acertou" % t["name"], func(): sala.send({"t": "result", "teamId": t["id"]}), "BotaoEquipe", 22)
					_pintar_botao(b, c)
					v.add_child(b)
				v.add_child(UI.botao("Ninguém acertou", func(): sala.send({"t": "result", "teamId": null}), "BotaoRuim", 22))
			else:
				var l := UI.hbox(10)
				var ok := UI.botao("Acertou!", func(): sala.send({"t": "result", "teamId": acting["id"]}), "BotaoBom", 28)
				var no := UI.botao("Não acertou", func(): sala.send({"t": "result", "teamId": null}), "BotaoRuim", 24)
				ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				ok.custom_minimum_size = Vector2(0, 76)
				no.custom_minimum_size = Vector2(0, 76)
				l.add_child(ok)
				l.add_child(no)
				v.add_child(l)
				ok.call_deferred("grab_focus")
			_atualizar_tempo()
		"over":
			v.add_child(UI.h("Fim de jogo!", 32))


func _pintar_botao(b: Button, c: Color) -> void:
	for s in ["normal", "hover", "pressed", "hover_pressed"]:
		var cor := c if s == "normal" else (c.lightened(0.1) if s == "hover" else c.darkened(0.1))
		b.add_theme_stylebox_override(s, Tema._caixa(cor, 14, 0, Color.TRANSPARENT, 4 if s in ["normal", "hover"] else 1))
	var fc := UI.contraste(c)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fc)


func _bolinha(c: Color, tam := 22.0) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(99)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 1, 1, 0.8)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(tam, tam)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


func _painel_equipes() -> void:
	var v := _secao()
	var acting_id = S["turn"]["actingId"] if S.get("turn") != null else null
	for t in S["teams"]:
		var linha := UI.hbox(10)
		linha.add_child(_bolinha(Color(t["color"])))
		var col := UI.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UI.label(t["name"], 21, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT))
		var nomes: Array = []
		for p in t["people"]:
			nomes.append(p["name"])
		col.add_child(UI.label(", ".join(nomes) if nomes.size() else "ninguém ainda", 16, Tema.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
		linha.add_child(col)
		linha.add_child(UI.sem_quebra(UI.h(str(int(t["pos"])), 30)))
		var caixa := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.1) if t["id"] == acting_id else Color(0, 0, 0, 0.15)
		sb.set_corner_radius_all(14)
		if t["id"] == acting_id:
			sb.set_border_width_all(3)
			sb.border_color = Color(t["color"])
		sb.set_content_margin_all(8)
		caixa.add_theme_stylebox_override("panel", sb)
		caixa.add_child(linha)
		v.add_child(caixa)


func _process(_dt: float) -> void:
	_atualizar_tempo()


func _atualizar_tempo() -> void:
	if S.is_empty() or S["phase"] != "miming" or _timer_lbl == null or not is_instance_valid(_timer_lbl):
		return
	if S.get("timerEnd") == null:
		return
	var falta := maxf(0.0, (float(S["timerEnd"]) - _agora()) / 1000.0)
	var seg := int(ceil(falta))
	_timer_lbl.text = str(seg)
	_timer_lbl.add_theme_color_override("font_color", Tema.BAD if seg <= 10 else Color.WHITE)
	var total := ceilf(float(S["settings"]["seconds"]) / 2.0) if S["turn"]["steal"] else float(S["settings"]["seconds"])
	if _barra:
		_barra.value = falta / maxf(total, 1.0)
	if seg != _ultimo_seg and seg <= 5 and seg > 0:
		Som.play("tique", 0.9)
	_ultimo_seg = seg


# ---------- Preparação (lobby) ----------
func _cartao_mundo(v: VBoxContainer) -> void:
	var s: Dictionary = S["settings"]
	var lv: String = s["level"]
	var l: Dictionary = Cartas.levels[lv]
	var linha := UI.hbox(12)
	var img := TextureRect.new()
	img.texture = UI.tex(UI.img_path("mundo_" + lv))
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.custom_minimum_size = Vector2(62, 88)
	img.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linha.add_child(img)
	var col := UI.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UI.h("Mundo %s" % l["name"], 26, Tema.ACCENT))
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var sub: String = l["sub"]
	if S.get("suggestedLevel") == lv:
		sub += " · sugerido"
	col.add_child(UI.label(sub, 19, Tema.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	linha.add_child(col)
	linha.add_child(UI.botao("Trocar mundo", _abrir_mundos, "BotaoGhost", 18))
	v.add_child(linha)
	if S.get("avgAge") != null:
		var cnt := int(S["ageCount"])
		v.add_child(UI.label("Média de idade: %s anos (%d %s)" % [str(S["avgAge"]), cnt, "pessoa" if cnt == 1 else "pessoas"], 18, Tema.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	else:
		v.add_child(UI.label("Ponham as idades para o jogo sugerir o mundo.", 18, Tema.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	if not s["levelAuto"]:
		v.add_child(UI.botao("Voltar a seguir a média de idade", func(): sala.send({"t": "settings", "settings": {"level": "auto"}}), "BotaoGhost", 16))


func _ajustes(v: VBoxContainer) -> void:
	var s: Dictionary = S["settings"]
	var g := UI.grade(2, 10)
	v.add_child(g)
	_opcao(g, "Equipes", "teamCount", [2, 3, 4, 5, 6], func(o): return str(o))
	_opcao(g, "Tempo por mímica", "seconds", [30, 45, 60, 90, 120], func(o): return "%d s" % o)
	_opcao(g, "Tabuleiro", "boardLength", [21, 31, 41], func(o): return {21: "Curto", 31: "Médio", 41: "Longo"}[o])
	for par in [["catDie", "Dado de categoria"], ["again", "Acertou, joga de novo"], ["steal", "Repescagem (errou, a próxima tenta)"], ["twists", "Regras extras nas cartas"]]:
		var c := CheckButton.new()
		c.text = par[1]
		c.button_pressed = s[par[0]]
		var k: String = par[0]
		c.toggled.connect(func(on: bool):
			sala.send({"t": "settings", "settings": {k: on}})
			_salvar_turma())
		v.add_child(c)


func _opcao(g: GridContainer, rotulo: String, chave: String, opcoes: Array, fmt: Callable) -> void:
	var l := UI.label(rotulo, 20, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(l)
	var ob := OptionButton.new()
	for i in opcoes.size():
		ob.add_item(fmt.call(opcoes[i]), i)
		if int(S["settings"][chave]) == int(opcoes[i]):
			ob.select(i)
	ob.custom_minimum_size = Vector2(150, 0)
	ob.item_selected.connect(func(i: int):
		sala.send({"t": "settings", "settings": {chave: opcoes[i]}})
		_salvar_turma())
	g.add_child(ob)


func _lobby_local() -> void:
	var m := _secao()
	_cartao_mundo(m)

	var v := _secao("Equipes")
	for t in S["teams"]:
		v.add_child(_cartao_equipe_local(t))
	var pode := true
	var b := UI.botao("Começar jogo", func():
		_salvar_turma()
		sala.send({"t": "start_game"}), "", 30)
	b.custom_minimum_size = Vector2(0, 76)
	b.disabled = not pode
	v.add_child(b)
	v.add_child(UI.label("Ponham os nomes: o jogo chama quem faz a mímica e reveza dentro da equipe.", 17, Tema.MUTED))

	var a := _secao("Ajustes")
	_ajustes(a)


func _cartao_equipe_local(t: Dictionary) -> Control:
	var tid: String = t["id"]
	var col := UI.vbox(8)
	var topo := UI.hbox(8)
	topo.add_child(_bolinha(Color(t["color"]), 26))
	var nome := LineEdit.new()
	nome.text = t["name"]
	nome.max_length = 20
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome.add_theme_font_override("font", Tema.fonte_titulo)
	var salvar_nome := func():
		if nome.text.strip_edges() != "":
			(sala as SalaLocal).renomear(tid, nome.text)
			_salvar_turma()
	nome.text_changed.connect(func(_x): salvar_nome.call())
	topo.add_child(nome)
	col.add_child(topo)

	var fluxo := HFlowContainer.new()
	fluxo.add_theme_constant_override("h_separation", 6)
	fluxo.add_theme_constant_override("v_separation", 6)
	var roster: Array = t.get("roster", [])
	for i in roster.size():
		var p: Dictionary = roster[i]
		var chip := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color.WHITE
		sb.set_corner_radius_all(99)
		sb.content_margin_left = 12
		sb.content_margin_right = 4
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		chip.add_theme_stylebox_override("panel", sb)
		var h := UI.hbox(4)
		var txt: String = p["name"]
		if p.get("age") != null:
			txt += " · %d" % int(p["age"])
		h.add_child(UI.sem_quebra(UI.label(txt, 19, Tema.AZUL)))
		var idx := i
		var x := UI.botao("x", func():
			sala.send({"t": "remove_person", "teamId": tid, "i": idx})
			_salvar_turma(), "BotaoRuim", 16)
		x.custom_minimum_size = Vector2(34, 30)
		h.add_child(x)
		chip.add_child(h)
		fluxo.add_child(chip)
	if roster.size() > 0:
		col.add_child(fluxo)

	var add := UI.hbox(6)
	var nn := LineEdit.new()
	nn.name = "nome_" + tid
	nn.placeholder_text = "Nome de quem joga"
	nn.max_length = 20
	nn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ida := LineEdit.new()
	ida.placeholder_text = "Idade"
	ida.max_length = 2
	ida.custom_minimum_size = Vector2(76, 0)
	ida.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	var adicionar := func():
		var n := nn.text.strip_edges()
		if n == "":
			nn.grab_focus()
			return
		_refocar = "nome_" + tid
		Som.play("pop")
		sala.send({"t": "add_person", "teamId": tid, "name": n, "age": ida.text})
		_salvar_turma()
	nn.text_submitted.connect(func(_x):
		if ida.text.strip_edges() == "":
			ida.grab_focus()
		else:
			adicionar.call())
	ida.text_submitted.connect(func(_x): adicionar.call())
	var mais := UI.botao("+", adicionar, "", 26)
	mais.custom_minimum_size = Vector2(52, 0)
	add.add_child(nn)
	add.add_child(ida)
	add.add_child(mais)
	col.add_child(add)
	return UI.painel(col, "PainelEscuro")


func _salvar_turma() -> void:
	if not _local():
		return
	var sl := sala as SalaLocal
	Config.gravar("turma", "equipes", sl.turma())
	var s := sl.settings
	var aj := {}
	for k in ["seconds", "boardLength", "twists", "steal", "again", "catDie"]:
		aj[k] = s[k]
	if not s["levelAuto"]:
		aj["level"] = s["level"]
	Config.gravar("turma", "ajustes", aj)


func _lobby_online() -> void:
	var so := sala as SalaOnline
	var q := _secao()
	q.alignment = BoxContainer.ALIGNMENT_CENTER
	q.add_child(UI.h("Entrem pelo celular", 28))
	if _qr:
		var qr := TextureRect.new()
		qr.texture = _qr
		qr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		qr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		qr.custom_minimum_size = Vector2(200, 200)
		qr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var fundo_qr := UI.painel(qr)
		var sbq := StyleBoxFlat.new()
		sbq.bg_color = Color.WHITE
		sbq.set_corner_radius_all(16)
		sbq.set_content_margin_all(10)
		fundo_qr.add_theme_stylebox_override("panel", sbq)
		fundo_qr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		q.add_child(fundo_qr)
	q.add_child(UI.label("ou acesse %s e digite" % so.servidor.replace("https://", "").replace("http://", ""), 19, Tema.MUTED))
	q.add_child(UI.titulo(so.code, 54, Tema.ACCENT))

	var m := _secao()
	_cartao_mundo(m)

	var v := _secao("Equipes")
	var pronto := true
	for t in S["teams"]:
		if (t["people"] as Array).is_empty():
			pronto = false
		var col := UI.vbox(4)
		var topo := UI.hbox(8)
		topo.add_child(_bolinha(Color(t["color"]), 24))
		var nome := LineEdit.new()
		nome.text = t["name"]
		nome.max_length = 20
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tid: String = t["id"]
		nome.text_submitted.connect(func(x: String): sala.send({"t": "team_name", "teamId": tid, "name": x}))
		nome.focus_exited.connect(func():
			sala.send({"t": "team_name", "teamId": tid, "name": nome.text})
			if _pendente_render:
				_render.call_deferred())
		topo.add_child(nome)
		col.add_child(topo)
		var nomes: Array = []
		for p in t["people"]:
			nomes.append(p["name"] + ("" if p.get("connected", true) else " (saiu)"))
		col.add_child(UI.label(", ".join(nomes) if nomes.size() else "ninguém ainda", 18, Tema.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
		v.add_child(UI.painel(col, "PainelEscuro"))
	var esc: Array = []
	for p in S.get("unassigned", []):
		esc.append(" e ".join(p["names"]))
	if esc.size():
		v.add_child(UI.label("Escolhendo equipe: %s" % ", ".join(esc), 18, Tema.MUTED))
	var juizes: Array = []
	for j in S.get("judges", []):
		juizes.append(" e ".join(j["names"]))
	if juizes.size():
		v.add_child(UI.label("Juiz: %s" % ", ".join(juizes), 18, Tema.MUTED))
	var b := UI.botao("Começar jogo", func(): sala.send({"t": "start_game"}), "", 30)
	b.disabled = not pronto
	b.custom_minimum_size = Vector2(0, 76)
	v.add_child(b)
	if not pronto:
		v.add_child(UI.label("Cada equipe precisa de pelo menos 1 celular.", 17, Tema.MUTED))
	var a := _secao("Ajustes")
	_ajustes(a)


func _aguardando() -> void:
	UI.limpar(_conteudo)
	var v := _secao()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(UI.imagem(UI.img_path("hero"), Vector2(140, 140), true))
	v.add_child(UI.h("Criando a sala…", 30))
	v.add_child(UI.muted("O servidor gratuito pode levar até 1 minuto para acordar."))
	v.add_child(UI.botao("Voltar", main.ir_menu, "BotaoGhost", 20))


func _erro_online(texto: String) -> void:
	UI.limpar(_conteudo)
	var v := _secao()
	v.add_child(UI.h("Ops!", 32))
	v.add_child(UI.label(texto, 21))
	v.add_child(UI.botao("Tentar de novo", main.jogar_online, "", 24))
	v.add_child(UI.botao("Voltar ao menu", main.ir_menu, "BotaoGhost", 20))


# ---------- Janelas ----------
func _abrir_mundos() -> void:
	for c in get_children():
		if c is EscolhaMundo:
			return
	var m := EscolhaMundo.new()
	m.atual = _nivel()
	m.sugerido = S.get("suggestedLevel")
	m.media = S.get("avgAge")
	m.escolheu.connect(func(k: String):
		sala.send({"t": "settings", "settings": {"level": k}})
		_salvar_turma())
	add_child(m)


func _janela_fim() -> void:
	if S["phase"] == "over" and _fim == null:
		_fim = Janelas.fim(S, func():
			_fim = null
			sala.send({"t": "back_to_lobby"}), main.ir_menu)
		add_child(_fim)
		Janelas.confete(self)
	elif S["phase"] != "over" and _fim != null:
		Janelas.fechar(_fim)
		_fim = null


func _encerrar() -> void:
	add_child(Janelas.confirmar("Voltar à preparação? O placar será zerado.", func(): sala.send({"t": "back_to_lobby"}), "Encerrar"))


func _pausa() -> void:
	if get_node_or_null("Pausa") != null:
		return
	var b := Janelas.base(460)
	var raiz: Control = b[0]
	raiz.name = "Pausa"
	var col: VBoxContainer = b[1]
	col.add_child(UI.titulo("Pausa", 44))
	var cont := UI.botao("Continuar", func(): Janelas.fechar(raiz), "", 26)
	col.add_child(cont)
	cont.call_deferred("grab_focus")
	col.add_child(UI.botao("Como jogar", func(): add_child(Janelas.regras()), "BotaoGhost", 20))
	col.add_child(UI.botao("Opções e som", func(): add_child(Janelas.opcoes()), "BotaoGhost", 20))
	if S.get("phase", "lobby") != "lobby":
		col.add_child(UI.botao("Pular vez", func():
			Janelas.fechar(raiz)
			sala.send({"t": "skip_turn"}), "BotaoGhost", 20))
		if S["phase"] in ["turn", "draw"]:
			col.add_child(UI.botao("Trocar mímico", func():
				Janelas.fechar(raiz)
				sala.send({"t": "skip_mimer"}), "BotaoGhost", 20))
		col.add_child(UI.botao("Encerrar partida", func():
			Janelas.fechar(raiz)
			_encerrar(), "BotaoPerigo", 20))
	col.add_child(UI.botao("Sair para o menu", func():
		Janelas.fechar(raiz)
		add_child(Janelas.confirmar("Sair para o menu? A partida será perdida.", main.ir_menu, "Sair")), "BotaoPerigo", 20))
	add_child(raiz)
