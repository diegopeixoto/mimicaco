class_name SalaLocal
extends Node
## Regras do Mimicaço rodando no próprio aparelho: port do server.js do jogo web.
## Gera o mesmo "estado" que o servidor manda para a tela principal, então a interface
## e o tabuleiro funcionam igual no modo passa-e-joga e no modo com celulares.

signal mudou(estado: Dictionary)

const DICE_MS := 1700.0
const HOP_MS := 330.0
const BONUS_STEAL := 2 # casas extras para quem acerta na repescagem
const BONUS_ALL := 3 # casas extras para quem acerta no "Todos jogam"
const JUMP := 2 # casa "Pulo do Rawzinho"

var local := true
var settings := {
	"teamCount": 2, "seconds": 60, "boardLength": 31, "twists": true, "steal": true,
	"again": true, "level": "kids", "catDie": true, "levelAuto": true,
}
var teams: Array = [] # [{id, name, color, pos, people: [{name, age}]}]
var phase := "lobby" # lobby | turn | draw | card | miming | timeup | over
var turn = null # {teamIdx, allPlay, steal, stealIdx, catFace}
var mimer_idx := {}
var card = null # {cat, word, twist, swapped}
var timer_end = null
var move = null # {id, teamId, kind, value, from, path, jumped, at, dur, catFace}
var move_seq := 0
var result = null # {id, kind: hit|miss|steal_hit|all_hit, teamId, word}
var result_seq := 0
var winner = null
var decks := {}
var message := ""
var board: Array = []
var estado: Dictionary = {}
var rng := RandomNumberGenerator.new()
var _timer: Timer


func _init() -> void:
	rng.randomize()
	_set_teams(2)
	board = build_board(settings["boardLength"])


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_tempo_esgotado)
	_emitir()


static func agora_ms() -> float:
	return Time.get_unix_time_from_system() * 1000.0


func agora() -> float:
	return agora_ms()


static func move_duration(mv: Dictionary) -> float:
	return (DICE_MS if mv["kind"] == "dice" else 400.0) + (mv["path"] as Array).size() * HOP_MS + 300.0


# ---------- Tabuleiro ----------
static func build_board(length: int) -> Array:
	var squares: Array = [{"type": "start"}]
	var c := 0
	for i in range(1, length - 1):
		if i % 7 == 0:
			squares.append({"type": "all"}) # Todos jogam
		elif i % 11 == 4:
			squares.append({"type": "jump"}) # Pulo do Rawzinho: anda +2
		else:
			squares.append({"type": "cat", "cat": Cartas.cat_order[c % Cartas.cat_order.size()]})
			c += 1
	squares.append({"type": "finish", "cat": "dificil"})
	return squares


func _last() -> int:
	return board.size() - 1


func _square_at(pos: int) -> Dictionary:
	return board[mini(pos, _last())]


# ---------- Equipes e pessoas ----------
func _set_teams(n: int) -> void:
	var old := teams
	teams = []
	for i in n:
		var p: Dictionary = Cartas.team_presets[i]
		teams.append({
			"id": "t%d" % i,
			"name": old[i]["name"] if i < old.size() else p["name"],
			"color": p["color"],
			"pos": 0,
			"people": old[i]["people"] if i < old.size() else [],
		})


func definir_turma(dados: Array) -> void:
	## dados = [{name, people: [{name, age}]}], vindo do que ficou salvo da última partida.
	_set_teams(clampi(dados.size(), 2, 6))
	for i in teams.size():
		if i < dados.size():
			var d: Dictionary = dados[i]
			if String(d.get("name", "")).strip_edges() != "":
				teams[i]["name"] = String(d["name"]).substr(0, 20)
			teams[i]["people"] = (d.get("people", []) as Array).duplicate(true)
	settings["teamCount"] = teams.size()
	_auto_level()
	_emitir()


## Muda o nome da equipe sem redesenhar a tela (enquanto a pessoa digita).
func renomear(team_id: String, nome: String) -> void:
	var team = _team_by_id(team_id)
	var nm := nome.strip_edges().substr(0, 20)
	if team != null and nm != "":
		team["name"] = nm
		estado = _view()


func turma() -> Array:
	var out: Array = []
	for t in teams:
		out.append({"name": t["name"], "people": (t["people"] as Array).duplicate(true)})
	return out


func _slots(team: Dictionary) -> Array:
	var out: Array = []
	var ps: Array = team["people"]
	for i in ps.size():
		out.append({"pid": "%s-%d" % [team["id"], i], "i": i, "name": ps[i]["name"], "connected": true})
	return out


func _acting_team() -> Variant:
	if turn == null:
		return null
	return teams[turn["stealIdx"] if turn["steal"] else turn["teamIdx"]]


func _turn_team() -> Variant:
	return teams[turn["teamIdx"]] if turn != null else null


func _current_mimer() -> Variant:
	var team = _acting_team()
	if team == null:
		return null
	var list := _slots(team)
	if list.is_empty():
		return null
	var start: int = mimer_idx.get(team["id"], 0)
	return list[start % list.size()]


func _advance_mimer(team: Dictionary) -> void:
	var n: int = (team["people"] as Array).size()
	if n > 0:
		mimer_idx[team["id"]] = (int(mimer_idx.get(team["id"], 0)) + 1) % n


func _age_stats() -> Dictionary:
	var ages: Array = []
	for t in teams:
		for p in t["people"]:
			if p.get("age") != null and int(p["age"]) > 0:
				ages.append(int(p["age"]))
	if ages.is_empty():
		return {"avgAge": null, "ageCount": 0, "suggestedLevel": null}
	var s := 0.0
	for a in ages:
		s += a
	var avg := s / ages.size()
	var lvl := "kids"
	if avg >= float(Cartas.levels["adulto"]["minAge"]):
		lvl = "adulto"
	elif avg >= float(Cartas.levels["familia"]["minAge"]):
		lvl = "familia"
	return {"avgAge": roundf(avg * 10.0) / 10.0, "ageCount": ages.size(), "suggestedLevel": lvl}


# Enquanto ninguém escolher o mundo na mão, ele segue a média de idade.
func _auto_level() -> void:
	if phase != "lobby" or not settings["levelAuto"]:
		return
	var sug = _age_stats()["suggestedLevel"]
	if sug != null:
		settings["level"] = sug


static func limpar_idade(v) -> Variant:
	if v == null or str(v).strip_edges() == "":
		return null
	var n := int(round(float(str(v))))
	return n if n >= 2 and n <= 99 else null


# ---------- Movimento ----------
func _move_team(team: Dictionary, steps: int, kind: String, value = null) -> Dictionary:
	var from: int = team["pos"]
	var path: Array = []
	var pos := from
	var s := 0
	while s < steps and pos < _last():
		pos += 1
		path.append(pos)
		s += 1
	var jumped := false
	if kind == "dice" and _square_at(pos)["type"] == "jump":
		jumped = true
		s = 0
		while s < JUMP and pos < _last():
			pos += 1
			path.append(pos)
			s += 1
	team["pos"] = pos
	move_seq += 1
	move = {"id": move_seq, "teamId": team["id"], "kind": kind, "value": value, "from": from, "path": path, "jumped": jumped, "at": agora_ms(), "catFace": null}
	move["dur"] = move_duration(move)
	return move


func _set_result(kind: String, team_id, word) -> void:
	result_seq += 1
	result = {"id": result_seq, "kind": kind, "teamId": team_id, "word": word}


func _draw_word(cat: String) -> String:
	var key := "%s:%s" % [settings["level"], cat]
	if not decks.has(key) or (decks[key] as Array).is_empty():
		var words: Array = (Cartas.categories[cat]["words"][settings["level"]] as Array).duplicate()
		_shuffle(words)
		decks[key] = words
	return (decks[key] as Array).pop_back()


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp


func _start_turn(team_idx: int, msg := "") -> void:
	turn = {"teamIdx": team_idx, "allPlay": false, "steal": false, "stealIdx": null, "catFace": null}
	card = null
	timer_end = null
	phase = "turn"
	message = msg
	if _timer:
		_timer.stop()


func _next_idx(i: int) -> int:
	return (i + 1) % teams.size()


func _start_timer(seconds: int) -> void:
	phase = "miming"
	timer_end = agora_ms() + seconds * 1000.0
	_timer.start(seconds + 0.3)


func _tempo_esgotado() -> void:
	if phase == "miming":
		phase = "timeup"
		_emitir()


# ---------- Ações (mesmas mensagens que os celulares mandam para o servidor) ----------
func send(msg: Dictionary) -> void:
	_handle(msg)
	_emitir()


func _handle(msg: Dictionary) -> void:
	match String(msg.get("t", "")):
		"settings":
			if phase != "lobby":
				return
			var s: Dictionary = msg.get("settings", {})
			if s.has("teamCount"):
				var n := int(s["teamCount"])
				if n >= 2 and n <= 6:
					_set_teams(n)
			if s.has("seconds") and int(s["seconds"]) in [30, 45, 60, 90, 120]:
				settings["seconds"] = int(s["seconds"])
			if s.has("boardLength") and int(s["boardLength"]) in [21, 31, 41]:
				settings["boardLength"] = int(s["boardLength"])
				board = build_board(settings["boardLength"])
			for k in ["twists", "steal", "again", "catDie"]:
				if s.has(k) and typeof(s[k]) == TYPE_BOOL:
					settings[k] = s[k]
			if s.has("level"):
				if s["level"] == "auto":
					settings["levelAuto"] = true
					_auto_level()
				elif Cartas.levels.has(s["level"]):
					settings["level"] = s["level"]
					settings["levelAuto"] = false
			settings["teamCount"] = teams.size()
		"team_name":
			var team = _team_by_id(msg.get("teamId", ""))
			var nm := String(msg.get("name", "")).strip_edges().substr(0, 20)
			if team != null and nm != "":
				team["name"] = nm
		"add_person":
			var team = _team_by_id(msg.get("teamId", ""))
			var nm := String(msg.get("name", "")).strip_edges().substr(0, 20)
			if team != null and nm != "" and (team["people"] as Array).size() < 12:
				(team["people"] as Array).append({"name": nm, "age": limpar_idade(msg.get("age"))})
				_auto_level()
		"remove_person":
			var team = _team_by_id(msg.get("teamId", ""))
			var i := int(msg.get("i", -1))
			if team != null and i >= 0 and i < (team["people"] as Array).size():
				(team["people"] as Array).remove_at(i)
				mimer_idx.erase(team["id"])
				_auto_level()
		"set_age":
			var team = _team_by_id(msg.get("teamId", ""))
			var i := int(msg.get("i", -1))
			if team != null and i >= 0 and i < (team["people"] as Array).size():
				team["people"][i]["age"] = limpar_idade(msg.get("age"))
				_auto_level()
		"start_game":
			if phase != "lobby":
				return
			for t in teams:
				t["pos"] = 0
			winner = null
			move = null
			result = null
			mimer_idx = {}
			_start_turn(0)
		"roll":
			if phase != "turn":
				return
			if move != null and agora_ms() < float(move["at"]) + float(move["dur"]) - 200.0:
				return # espera a animação anterior
			var team: Dictionary = _turn_team()
			var value := rng.randi_range(1, 6)
			var cat_face = Cartas.cat_faces[rng.randi_range(0, Cartas.cat_faces.size() - 1)] if settings["catDie"] else null
			var mv := _move_team(team, value, "dice", value)
			mv["catFace"] = cat_face
			turn["catFace"] = cat_face
			var sq := _square_at(team["pos"])
			turn["allPlay"] = sq["type"] == "all"
			phase = "draw"
			message = "Pulo do Rawzinho! +2 casas" if mv["jumped"] else ""
		"draw":
			if phase != "draw":
				return
			var team: Dictionary = _turn_team()
			var sq := _square_at(team["pos"])
			# a casa final é sempre Desafio; senão vale o dado de categoria (a estrela usa a categoria da casa)
			var face = turn["catFace"]
			var cat = null
			if sq["type"] == "finish":
				cat = "dificil"
			elif face != null and face != "casa":
				cat = face
			else:
				cat = sq.get("cat")
			if cat == null:
				cat = Cartas.cat_order[rng.randi_range(0, Cartas.cat_order.size() - 1)]
			var twist = null
			if settings["twists"] and rng.randi_range(0, 3) == 0:
				twist = Cartas.twists[rng.randi_range(0, Cartas.twists.size() - 1)]
			card = {"cat": cat, "word": _draw_word(cat), "twist": twist, "swapped": false}
			phase = "card"
		"swap_card":
			if phase != "card" or card["swapped"] or turn["steal"]:
				return
			card["word"] = _draw_word(card["cat"])
			card["swapped"] = true
		"go":
			if phase != "card":
				return
			var secs: int = int(ceil(settings["seconds"] / 2.0)) if turn["steal"] else int(settings["seconds"])
			_start_timer(secs)
		"result":
			if phase not in ["miming", "timeup"]:
				return
			_timer.stop()
			var tid = msg.get("teamId")
			_on_result(tid if tid != null and String(tid) != "" else null)
		"skip_mimer":
			if phase not in ["turn", "draw", "card"]:
				return
			_advance_mimer(_acting_team())
		"skip_turn":
			if phase in ["lobby", "over"]:
				return
			_start_turn(_next_idx(turn["teamIdx"]))
		"back_to_lobby":
			if _timer:
				_timer.stop()
			phase = "lobby"
			turn = null
			card = null
			winner = null
			move = null
			result = null
			for t in teams:
				t["pos"] = 0


func _team_by_id(id) -> Variant:
	for t in teams:
		if t["id"] == id:
			return t
	return null


func _on_result(guessed_team_id) -> void:
	var team: Dictionary = _turn_team()
	var word: String = card["word"]
	var on_finish: bool = int(team["pos"]) == _last()

	# Repescagem: a próxima equipe tentou a mesma carta
	if turn["steal"]:
		var steal_team: Dictionary = teams[turn["stealIdx"]]
		_advance_mimer(steal_team)
		if guessed_team_id != null:
			_set_result("steal_hit", steal_team["id"], word)
			_move_team(steal_team, BONUS_STEAL, "bonus")
			_start_turn(turn["stealIdx"], "%s roubou a carta e ganhou +%d casas!" % [steal_team["name"], BONUS_STEAL])
		else:
			_set_result("miss", null, word)
			_start_turn(turn["stealIdx"], "Ninguém acertou \"%s\"." % word)
		return

	_advance_mimer(team)

	# Todos jogam: quem acertar ganha casas extras
	if turn["allPlay"]:
		var win = _team_by_id(guessed_team_id)
		if win == null:
			_set_result("miss", null, word)
			_start_turn(_next_idx(turn["teamIdx"]), "Ninguém acertou \"%s\"." % word)
			return
		_set_result("all_hit", win["id"], word)
		_move_team(win, BONUS_ALL, "bonus")
		var again: bool = win["id"] == team["id"] and settings["again"]
		_start_turn(turn["teamIdx"] if again else _next_idx(turn["teamIdx"]), "%s acertou e ganhou +%d casas!" % [win["name"], BONUS_ALL])
		return

	if guessed_team_id != null:
		_set_result("hit", team["id"], word)
		if on_finish:
			winner = team["id"]
			phase = "over"
			return
		if settings["again"]:
			_start_turn(turn["teamIdx"], "%s acertou e joga de novo!" % team["name"])
		else:
			_start_turn(_next_idx(turn["teamIdx"]), "%s acertou!" % team["name"])
		return

	# Errou: a próxima equipe tenta a mesma carta, com metade do tempo
	if settings["steal"] and teams.size() > 1:
		_set_result("miss", null, null)
		turn["steal"] = true
		turn["stealIdx"] = _next_idx(turn["teamIdx"])
		card["twist"] = null
		timer_end = null
		phase = "card"
		message = "Repescagem! %s tenta a mesma carta." % teams[turn["stealIdx"]]["name"]
		return
	_set_result("miss", null, word)
	_start_turn(_next_idx(turn["teamIdx"]), "Ninguém acertou \"%s\"." % word)


# ---------- Estado para a interface e o tabuleiro ----------
func _emitir() -> void:
	estado = _view()
	mudou.emit(estado)


func _view() -> Dictionary:
	var mimer = _current_mimer()
	var acting = _acting_team()
	var ts: Array = []
	for t in teams:
		var tt: Dictionary = (t as Dictionary).duplicate(true)
		tt["people"] = _slots(t)
		tt["roster"] = (t["people"] as Array).duplicate(true)
		ts.append(tt)
	var tv = null
	if turn != null:
		tv = (turn as Dictionary).duplicate(true)
		tv["teamId"] = _turn_team()["id"]
		tv["actingId"] = acting["id"]
		tv["mimer"] = {"pid": mimer["pid"], "name": mimer["name"]} if mimer != null else null
	var st := {
		"t": "state",
		"local": true,
		"code": "",
		"you": {"host": true},
		"settings": settings.duplicate(true),
		"teams": ts,
		"unassigned": [],
		"judges": [],
		"hasJudge": false,
		"levels": Cartas.levels,
		"board": board.duplicate(true),
		"phase": phase,
		"turn": tv,
		"card": (card as Dictionary).duplicate(true) if card != null else null,
		"timerEnd": timer_end,
		"now": agora_ms(),
		"move": (move as Dictionary).duplicate(true) if move != null else null,
		"result": (result as Dictionary).duplicate(true) if result != null else null,
		"winner": winner,
		"message": message,
		"categories": Cartas.resumo_categorias(),
	}
	st.merge(_age_stats())
	return st
