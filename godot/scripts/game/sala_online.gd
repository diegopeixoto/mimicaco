class_name SalaOnline
extends Node
## Modo com celulares: o app vira a "tela principal" de uma sala no servidor do jogo web
## (mimicaco.onrender.com). Os celulares entram pelo QR code e jogam pelo jogar.html de sempre.

signal mudou(estado: Dictionary)
signal erro(texto: String)
signal sala_criada(code: String)
signal conexao(ok: bool)

var local := false
var servidor := ""
var code := ""
var host_key := ""
var estado: Dictionary = {}
var offset := 0.0 # relógio do servidor - relógio do aparelho (ms)
var ws := WebSocketPeer.new()
var _aberto := false
var _quer_conectar := false
var _espera := 0.5
var _proxima_tentativa := 0.0
var _parado_por_erro := false


func _ready() -> void:
	servidor = Config.servidor()
	set_process(false)


func agora() -> float:
	return SalaLocal.agora_ms() + offset


func url_entrar() -> String:
	return "%s/%s" % [servidor, code]


## Cria a sala no servidor (o plano gratuito do Render pode levar ~1 min para acordar).
func criar() -> void:
	var http := HTTPRequest.new()
	http.timeout = 120.0
	add_child(http)
	http.request_completed.connect(func(res: int, status: int, _h: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		if res != HTTPRequest.RESULT_SUCCESS or status != 200:
			erro.emit("Não consegui falar com o servidor (%s). Confira a internet e tente de novo." % servidor)
			return
		var d = JSON.parse_string(body.get_string_from_utf8())
		if typeof(d) != TYPE_DICTIONARY or not d.has("code"):
			erro.emit("O servidor respondeu algo estranho. Tente de novo.")
			return
		code = d["code"]
		host_key = d["hostKey"]
		sala_criada.emit(code)
		_conectar())
	var e := http.request(servidor + "/api/new", ["content-type: application/json"], HTTPClient.METHOD_POST, "{}")
	if e != OK:
		erro.emit("Não consegui abrir a conexão com o servidor.")


## Baixa o QR code (SVG) do servidor e devolve como textura.
func baixar_qr(cb: Callable) -> void:
	var http := HTTPRequest.new()
	http.timeout = 30.0
	add_child(http)
	http.request_completed.connect(func(res: int, status: int, _h: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		if res != HTTPRequest.RESULT_SUCCESS or status != 200:
			cb.call(null)
			return
		var img := Image.new()
		if img.load_svg_from_buffer(body, 6.0) != OK:
			cb.call(null)
			return
		cb.call(ImageTexture.create_from_image(img)))
	http.request("%s/api/qr?u=%s" % [servidor, url_entrar().uri_encode()])


func _conectar() -> void:
	_quer_conectar = true
	_parado_por_erro = false
	var url := servidor.replace("https://", "wss://").replace("http://", "ws://") + "/ws"
	ws = WebSocketPeer.new()
	ws.inbound_buffer_size = 1 << 20
	var e := ws.connect_to_url(url)
	if e != OK:
		_agendar_reconexao()
	set_process(true)


func _agendar_reconexao() -> void:
	_proxima_tentativa = SalaLocal.agora_ms() + _espera * 1000.0
	_espera = minf(_espera * 2.0, 5.0)


func _process(_dt: float) -> void:
	if _proxima_tentativa > 0.0:
		if SalaLocal.agora_ms() >= _proxima_tentativa:
			_proxima_tentativa = 0.0
			_conectar()
		return
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _aberto:
			_aberto = true
			_espera = 0.5
			conexao.emit(true)
			_enviar({"t": "hello", "code": code, "hostKey": host_key})
		while ws.get_available_packet_count() > 0:
			_receber(ws.get_packet().get_string_from_utf8())
	elif st == WebSocketPeer.STATE_CLOSED:
		if _aberto:
			_aberto = false
			conexao.emit(false)
		if _quer_conectar and not _parado_por_erro:
			_agendar_reconexao()
		else:
			set_process(false)


func _receber(txt: String) -> void:
	var msg = JSON.parse_string(txt)
	if typeof(msg) != TYPE_DICTIONARY:
		return
	if msg.get("t") == "error":
		_parado_por_erro = true
		ws.close()
		erro.emit(String(msg.get("error", "Erro na sala.")))
		return
	if msg.get("t") == "state":
		offset = float(msg["now"]) - SalaLocal.agora_ms()
		estado = msg
		mudou.emit(estado)


func _enviar(msg: Dictionary) -> void:
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(msg))


func send(msg: Dictionary) -> void:
	_enviar(msg)


func sair() -> void:
	_quer_conectar = false
	ws.close()
