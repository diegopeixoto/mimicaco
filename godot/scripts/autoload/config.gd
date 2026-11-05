extends Node
## Preferências salvas no aparelho: som, servidor do modo com celulares e a última turma que jogou.

const ARQ := "user://mimicaco.cfg"
const SERVIDOR_PADRAO := "https://mimicaco.onrender.com"

var cfg := ConfigFile.new()


func _ready() -> void:
	cfg.load(ARQ)
	_aplicar_tela_cheia()


func ler(secao: String, chave: String, padrao: Variant = null) -> Variant:
	return cfg.get_value(secao, chave, padrao)


func gravar(secao: String, chave: String, valor: Variant) -> void:
	cfg.set_value(secao, chave, valor)
	cfg.save(ARQ)


func servidor() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--servidor="):
			return a.substr(11).trim_suffix("/")
	var s: String = ler("online", "servidor", SERVIDOR_PADRAO)
	s = s.strip_edges().trim_suffix("/")
	return s if s != "" else SERVIDOR_PADRAO


func eh_movel() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


## Fundo em vídeo: ligado no computador, desligado no tablet/celular para poupar bateria.
func fundo_animado() -> bool:
	return ler("tela", "fundo_animado", not eh_movel())


func tela_cheia() -> bool:
	return ler("tela", "tela_cheia", false)


func definir_tela_cheia(on: bool) -> void:
	gravar("tela", "tela_cheia", on)
	_aplicar_tela_cheia()


func _aplicar_tela_cheia() -> void:
	if eh_movel() or DisplayServer.get_name() == "headless":
		return
	var modo := DisplayServer.WINDOW_MODE_FULLSCREEN if tela_cheia() else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != modo:
		DisplayServer.window_set_mode(modo)
