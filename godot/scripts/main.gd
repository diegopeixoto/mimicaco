extends Control
## Raiz do jogo: fundo, troca de telas (menu e partida) e botão de som.

var fundo: Fundo
var _tela: Control
var _sala: Node


func _ready() -> void:
	theme = Tema.theme
	fundo = Fundo.new()
	add_child(fundo)
	get_tree().root.min_size = Vector2i(960, 540)
	ir_menu()
	# roteiro de teste automático (tools/roteiro.gd): godot --path . -- --roteiro
	if "--roteiro" in OS.get_cmdline_user_args() and ResourceLoader.exists("res://tools/roteiro.gd"):
		var r: Node = load("res://tools/roteiro.gd").new()
		r.set("main", self)
		add_child(r)


func _trocar(nova: Control) -> void:
	if _tela:
		_tela.queue_free()
	_tela = nova
	add_child(_tela)
	_tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func ir_menu() -> void:
	if _sala:
		if _sala.has_method("sair"):
			_sala.sair()
		_sala.queue_free()
		_sala = null
	fundo.mundo("menu")
	Som.trilha("musica")
	var m := TelaMenu.new()
	m.main = self
	_trocar(m)


## Passa-e-joga: tudo neste aparelho.
func jogar_local() -> void:
	var sala := SalaLocal.new()
	sala.definir_turma(Config.ler("turma", "equipes", [
		{"name": "Equipe Rawzinho", "people": []},
		{"name": "Equipe Toninho", "people": []},
	]))
	var aj: Dictionary = Config.ler("turma", "ajustes", {})
	if not aj.is_empty():
		sala.send({"t": "settings", "settings": aj})
	_comecar(sala)


## Com celulares: este aparelho é a tela principal de uma sala no servidor web.
func jogar_online() -> void:
	var sala := SalaOnline.new()
	_comecar(sala)
	sala.criar()


func _comecar(sala: Node) -> void:
	if _sala:
		_sala.queue_free()
	_sala = sala
	add_child(sala)
	var t := TelaJogo.new()
	t.main = self
	t.sala = sala
	_trocar(t)
