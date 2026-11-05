extends Node
## Roteiro de teste: joga uma partida sozinho e salva prints em user://prints (ou --saida=pasta).
## godot --path . -- --roteiro [--saida=/tmp/prints]

var main: Node
var saida := "user://prints"
var n := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			saida = a.substr(8)
	DirAccess.make_dir_recursive_absolute(saida)
	_rodar.call_deferred()


func espera(s: float) -> void:
	await get_tree().create_timer(s).timeout


func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	n += 1
	var p := "%s/%02d_%s.png" % [saida, n, nome]
	img.save_png(p)
	print("print: ", p)


func tela() -> Node:
	for c in main.get_children():
		if (c is TelaJogo or c is TelaMenu) and not c.is_queued_for_deletion():
			return c
	return null


func _modo() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--so="):
			return a.substr(5)
	return "tudo"


func _rodar() -> void:
	if _modo() == "dado":
		await _rodar_dado()
		return
	if _modo() == "online":
		await _rodar_online()
		return
	await espera(2.5)
	await foto("menu")
	main.jogar_local()
	await espera(1.6)
	await foto("mundos")
	var t: TelaJogo = tela()
	for c in t.get_children():
		if c is EscolhaMundo:
			c.queue_free()
	var sala: SalaLocal = t.sala
	for i in 2:
		var tid: String = sala.teams[i]["id"]
		if (sala.teams[i]["people"] as Array).is_empty():
			for p in [["Ana", 8], ["Beto", 36], ["Caio", 10]] if i == 0 else [["Duda", 9], ["Edu", 41]]:
				sala.send({"t": "add_person", "teamId": tid, "name": p[0], "age": p[1]})
	sala.send({"t": "settings", "settings": {"level": "kids"}})
	await espera(2.0)
	await foto("preparacao")
	sala.send({"t": "start_game"})
	await espera(2.5)
	await foto("vez")
	sala.send({"t": "roll"})
	await espera(0.9)
	await foto("dado")
	await espera(3.2)
	await foto("depois_do_dado")
	t._abrir_cortina()
	await espera(1.0)
	await foto("passe_o_aparelho")
	for c in t.get_children():
		if c.name.begins_with("@Control") or c is Control and c.get_child_count() > 0 and c.get_child(0) is ColorRect and t._cortina == c:
			pass
	if t._cortina:
		t._cortina.queue_free()
		t._cortina = null
	sala.send({"t": "draw"})
	await espera(1.6)
	await foto("carta")
	t._carta.comecar.emit()
	await espera(2.5)
	await foto("mimica")
	sala.send({"t": "result", "teamId": sala.estado["turn"]["actingId"]})
	await espera(0.7)
	await foto("acertou")
	await espera(2.5)
	# mais algumas jogadas para espalhar os peões
	for k in 3:
		if sala.move:
			sala.move["at"] = 0.0
		sala.send({"t": "roll"})
		sala.move["at"] = 0.0
		sala.send({"t": "draw"})
		sala.send({"t": "go"})
		sala.send({"t": "result", "teamId": null if k == 1 else sala.estado["turn"]["actingId"]})
		if sala.phase == "card":
			sala.send({"t": "go"})
			sala.send({"t": "result", "teamId": null})
	await espera(2.0)
	await foto("tabuleiro_kids")
	for lv in ["familia", "adulto"]:
		sala.send({"t": "back_to_lobby"})
		sala.send({"t": "settings", "settings": {"level": lv}})
		await espera(0.5)
		for c in t.get_children():
			if c is EscolhaMundo:
				c.queue_free()
		sala.send({"t": "start_game"})
		for k in 2:
			if sala.move:
				sala.move["at"] = 0.0
			sala.send({"t": "roll"})
			sala.move["at"] = 0.0
			sala.send({"t": "draw"})
			sala.send({"t": "go"})
			sala.send({"t": "result", "teamId": sala.estado["turn"]["actingId"]})
		await espera(3.5)
		await foto("mundo_" + lv)
	# fim de jogo
	sala.phase = "over"
	sala.winner = sala.teams[1]["id"]
	sala.send({"t": "noop"})
	await espera(2.5)
	await foto("fim")
	get_tree().quit()


func _rodar_dado() -> void:
	main.jogar_local()
	await espera(1.0)
	var t: TelaJogo = tela()
	for c in t.get_children():
		if c is EscolhaMundo:
			c.queue_free()
	var sala: SalaLocal = t.sala
	sala.send({"t": "start_game"})
	await espera(2.0)
	sala.send({"t": "roll"})
	var t0 := Time.get_ticks_msec()
	for k in 6:
		await foto("rolagem_%dms" % (Time.get_ticks_msec() - t0))
		await espera(0.25)
	get_tree().quit()


func _rodar_online() -> void:
	main.jogar_online()
	var t: TelaJogo = tela()
	var sala: SalaOnline = t.sala
	var limite := 60.0
	while sala.code == "" and limite > 0.0:
		await espera(0.5)
		limite -= 0.5
	print("SALA=", sala.code)
	var f := FileAccess.open("/tmp/sala.txt", FileAccess.WRITE)
	f.store_string(sala.code)
	f.close()
	limite = 60.0
	while limite > 0.0:
		await espera(0.5)
		limite -= 0.5
		var e: Dictionary = sala.estado
		if e.is_empty():
			continue
		var ok := true
		for tt in e["teams"]:
			if (tt["people"] as Array).is_empty():
				ok = false
		if ok:
			break
	for c in t.get_children():
		if c is EscolhaMundo:
			c.queue_free()
	await espera(2.0)
	await foto("online_lobby")
	sala.send({"t": "start_game"})
	await espera(1.5)
	sala.send({"t": "roll"})
	await espera(4.0)
	await foto("online_depois_do_dado")
	sala.send({"t": "draw"})
	await espera(1.0)
	await foto("online_carta")
	sala.send({"t": "go"})
	await espera(2.0)
	await foto("online_mimica")
	sala.send({"t": "result", "teamId": sala.estado["turn"]["actingId"]})
	await espera(1.0)
	await foto("online_acertou")
	print("FASE_FINAL=", sala.estado["phase"], " POS=", sala.estado["teams"][0]["pos"])
	get_tree().quit()
