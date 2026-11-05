class_name Fundo
extends Control
## Fundo de cada mundo: imagem e, no computador, o vídeo em loop por cima.

const IMAGENS := {"kids": "fundo", "familia": "fundo_ilha", "adulto": "fundo_vulcao", "menu": "fundo"}

var _img: TextureRect
var _video: VideoStreamPlayer
var _video_tex: TextureRect
var _atual := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_img = _cobrir(TextureRect.new())
	add_child(_img)
	_video = VideoStreamPlayer.new()
	_video.loop = true
	_video.volume_db = -80.0
	_video.size = Vector2(4, 4)
	_video.modulate.a = 0.0
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_video)
	_video_tex = _cobrir(TextureRect.new())
	_video_tex.modulate.a = 0.0
	add_child(_video_tex)


func _cobrir(t: TextureRect) -> TextureRect:
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func mundo(nivel: String) -> void:
	if nivel == _atual:
		return
	_atual = nivel
	_img.texture = UI.tex(UI.img_path(IMAGENS.get(nivel, "fundo")))
	_video.stop()
	_video_tex.modulate.a = 0.0
	if not Config.fundo_animado():
		return
	var lv := "kids" if nivel == "menu" else nivel
	var path := "res://assets/vid/fundo_%s.ogv" % lv
	if not ResourceLoader.exists(path):
		return
	_video.stream = load(path)
	_video.play()
	await get_tree().process_frame
	_video_tex.texture = _video.get_video_texture()
	create_tween().tween_property(_video_tex, "modulate:a", 1.0, 0.8)


func religar() -> void:
	var n := _atual
	_atual = ""
	mundo(n)
