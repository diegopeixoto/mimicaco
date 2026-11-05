class_name Reacao
extends Control
## Rawzinho e Toninho reagindo por cima do tabuleiro (no lugar das animações Rive do web):
## pulam na tela com a pose certa e o letreiro ACERTOU! / ERROU / SUA VEZ.

const POSES := {
	"rawzinho": {"acertou": "raw_feliz", "errou": "raw_triste", "carta": "raw_aponta", "susto": "raw_susto"},
	"toninho": {"acertou": "ton_feliz", "errou": "ton_triste", "carta": "ton_parado", "susto": "ton_susto"},
}
const TITULOS := {"acertou": "tit_acertou", "errou": "tit_errou", "carta": "tit_carta"}

var _boneco: TextureRect
var _titulo: TextureRect
var _tw: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boneco = TextureRect.new()
	_boneco.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_boneco.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_boneco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_boneco)
	_titulo = TextureRect.new()
	_titulo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_titulo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_titulo)
	visible = false


func tocar(tipo: String, quem := "rawzinho") -> void:
	var pose: String = POSES.get(quem, POSES["rawzinho"]).get(tipo, "raw_feliz")
	_boneco.texture = UI.tex("res://assets/poses/%s.webp" % pose)
	_titulo.texture = UI.tex("res://assets/poses/%s.webp" % TITULOS[tipo]) if TITULOS.has(tipo) else null
	var alt := minf(size.y * 0.62, 480.0)
	var bw := alt * 0.62
	_boneco.size = Vector2(bw, alt)
	_boneco.position = Vector2((size.x - bw) / 2.0, size.y * 0.32)
	_boneco.pivot_offset = Vector2(bw / 2.0, alt)
	var tw := minf(size.x * 0.7, 520.0)
	_titulo.size = Vector2(tw, tw * 0.28)
	_titulo.position = Vector2((size.x - tw) / 2.0, size.y * 0.12)
	_titulo.pivot_offset = _titulo.size / 2.0
	visible = true
	modulate.a = 1.0
	_boneco.scale = Vector2(0.2, 0.2)
	_titulo.scale = Vector2(0.2, 0.2)
	_boneco.rotation = 0.0
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.set_parallel()
	_tw.tween_property(_boneco, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(_titulo, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.12)
	_tw.chain()
	if tipo == "acertou":
		_tw.tween_property(_boneco, "position:y", _boneco.position.y - 40, 0.18).set_trans(Tween.TRANS_SINE)
		_tw.chain().tween_property(_boneco, "position:y", _boneco.position.y, 0.18).set_trans(Tween.TRANS_SINE)
		_tw.chain().tween_property(_boneco, "position:y", _boneco.position.y - 30, 0.16)
		_tw.chain().tween_property(_boneco, "position:y", _boneco.position.y, 0.16)
	elif tipo == "errou":
		_tw.tween_property(_boneco, "rotation", -0.08, 0.25).set_trans(Tween.TRANS_SINE)
		_tw.chain().tween_property(_boneco, "rotation", 0.06, 0.4).set_trans(Tween.TRANS_SINE)
	else:
		_tw.tween_property(_boneco, "rotation", 0.06, 0.3).set_trans(Tween.TRANS_SINE)
		_tw.chain().tween_property(_boneco, "rotation", -0.04, 0.3).set_trans(Tween.TRANS_SINE)
	_tw.chain().tween_interval(0.6)
	_tw.chain().tween_property(self, "modulate:a", 0.0, 0.3)
	_tw.chain().tween_callback(func(): visible = false)
