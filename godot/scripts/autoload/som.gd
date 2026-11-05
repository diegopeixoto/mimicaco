extends Node
## Música de cada mundo, efeitos e falas do Rawzinho.
## Música, falas e efeitos ligam e desligam separadamente (como no jogo web).

const VOL_MUSICA := 0.35
const VOL_MUSICA_FALANDO := 0.12

var opt := {"musica": true, "vozes": true, "efeitos": true}
var _cache := {}
var _musica: AudioStreamPlayer
var _musica_nome := ""
var _quer_musica := false
var _voz: AudioStreamPlayer
var _efeitos: Array[AudioStreamPlayer] = []
var _prox := 0
var _tween_musica: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in opt:
		opt[k] = Config.ler("som", k, true)
	_musica = AudioStreamPlayer.new()
	add_child(_musica)
	_voz = AudioStreamPlayer.new()
	add_child(_voz)
	_voz.finished.connect(_fim_da_fala)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_efeitos.append(p)


func _stream(nome: String) -> AudioStream:
	if not _cache.has(nome):
		var path := "res://assets/som/%s.mp3" % nome
		_cache[nome] = load(path) if ResourceLoader.exists(path) else null
	return _cache[nome]


## Efeito sonoro (dado, pulo, acertou...). vol de 0 a 1.
func play(nome: String, vol := 0.8) -> void:
	if not opt["efeitos"]:
		return
	var s := _stream(nome)
	if s == null:
		return
	var p := _efeitos[_prox]
	_prox = (_prox + 1) % _efeitos.size()
	p.stream = s
	p.volume_db = linear_to_db(clampf(vol, 0.01, 1.0))
	p.play()


## Fala do Rawzinho (voz_acertou, voz_suavez...). Abaixa a música enquanto fala, uma fala por vez.
func voz(nome: String, atraso_ms := 0) -> void:
	if not opt["vozes"]:
		return
	if atraso_ms > 0:
		await get_tree().create_timer(atraso_ms / 1000.0).timeout
		if not opt["vozes"]:
			return
	var s := _stream("voz_" + nome)
	if s == null:
		return
	_voz.stop()
	_voz.stream = s
	_voz.play()
	_volume_musica(VOL_MUSICA_FALANDO, 0.2)


func _fim_da_fala() -> void:
	_volume_musica(VOL_MUSICA, 0.6)


## Cada mundo tem sua música: musica (fácil), musica_familia, musica_adulto.
func trilha(nome: String) -> void:
	_quer_musica = true
	if nome == _musica_nome and _musica.playing:
		return
	_musica_nome = nome
	if not opt["musica"]:
		return
	var s := _stream(nome)
	if s == null:
		return
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	if _musica.playing:
		var t := create_tween()
		t.tween_property(_musica, "volume_db", -40.0, 0.5)
		await t.finished
	_musica.stream = s
	_musica.volume_db = -40.0
	_musica.play()
	_volume_musica(VOL_MUSICA, 0.8)


func parar_musica() -> void:
	_quer_musica = false
	_musica.stop()


func _volume_musica(vol: float, dur: float) -> void:
	if _tween_musica:
		_tween_musica.kill()
	_tween_musica = create_tween()
	_tween_musica.tween_property(_musica, "volume_db", linear_to_db(vol), dur)


func definir(chave: String, on: bool) -> void:
	opt[chave] = on
	Config.gravar("som", chave, on)
	if chave == "musica":
		if on and _quer_musica:
			var n := _musica_nome
			_musica_nome = ""
			trilha(n if n != "" else "musica")
		elif not on:
			_musica.stop()
	if chave == "vozes" and not on:
		_voz.stop()
		_volume_musica(VOL_MUSICA, 0.3)


func algum_ligado() -> bool:
	return opt["musica"] or opt["vozes"] or opt["efeitos"]
