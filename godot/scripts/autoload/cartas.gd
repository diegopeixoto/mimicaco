extends Node
## Cartas, categorias e níveis do Mimicaço.
## Os dados vêm de data/cartas.json, gerado a partir do cards.js do jogo web
## (rode tools/atualizar_cartas.sh depois de editar as cartas no repositório web).

var levels := {}
var categories := {}
var twists: Array = []
var cat_order: Array = []
var cat_faces: Array = []
var team_presets: Array = []


func _ready() -> void:
	var f := FileAccess.open("res://data/cartas.json", FileAccess.READ)
	if f == null:
		push_error("Não achei data/cartas.json")
		return
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	levels = d["levels"]
	categories = d["categories"]
	twists = d["twists"]
	cat_order = d["cat_order"]
	cat_faces = d["cat_faces"]
	team_presets = d["team_presets"]


## Só o que as telas precisam saber de cada categoria (sem as palavras).
func resumo_categorias() -> Dictionary:
	var out := {}
	for k in categories:
		var c: Dictionary = categories[k]
		out[k] = {"name": c["name"], "emoji": c["emoji"], "color": c["color"]}
	return out


func cor(cat: String) -> Color:
	if categories.has(cat):
		return Color(categories[cat]["color"])
	return Color("#ffd23d")


func nome(cat: String) -> String:
	if categories.has(cat):
		return categories[cat]["name"]
	return "Categoria da casa"


func total_palavras(level: String) -> int:
	var n := 0
	for k in categories:
		n += (categories[k]["words"][level] as Array).size()
	return n
