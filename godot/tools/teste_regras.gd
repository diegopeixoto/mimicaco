extends SceneTree
## Teste rápido das regras: simula várias partidas inteiras no modo passa-e-joga.
## godot --headless --path . -s res://tools/teste_regras.gd

func _initialize() -> void:
	await process_frame
	var cartas = root.get_node("Cartas")
	print("palavras kids=", cartas.total_palavras("kids"), " familia=", cartas.total_palavras("familia"), " adulto=", cartas.total_palavras("adulto"))
	var falhas := 0
	for partida in 30:
		var sala = load("res://scripts/game/sala_local.gd").new()
		root.add_child(sala)
		sala.definir_turma([
			{"name": "Rawzinhos", "people": [{"name": "Ana", "age": 8}, {"name": "Beto", "age": 35}]},
			{"name": "Toninhos", "people": [{"name": "Caio", "age": 10}]},
			{"name": "", "people": []},
		])
		sala.send({"t": "settings", "settings": {"boardLength": [21, 31, 41][partida % 3], "twists": partida % 2 == 0, "steal": partida % 4 != 1, "again": partida % 5 != 2, "catDie": partida % 2 == 1}})
		sala.send({"t": "start_game"})
		var passos := 0
		var fases := {}
		while sala.phase != "over" and passos < 2000:
			passos += 1
			var e: Dictionary = sala.estado
			fases[e.phase] = true
			match e.phase:
				"turn":
					if sala.move != null:
						sala.move["at"] = 0.0
					sala.send({"t": "roll"})
				"draw":
					sala.send({"t": "draw"})
				"card":
					if randf() < 0.2 and not e.card.swapped and not e.turn.steal:
						sala.send({"t": "swap_card"})
					sala.send({"t": "go"})
				"miming", "timeup":
					var tid = null
					if randf() < 0.55:
						tid = e.turn.actingId
						if e.turn.allPlay:
							tid = e.teams[randi() % e.teams.size()].id
					sala.send({"t": "result", "teamId": tid})
			# conferências
			for t in sala.teams:
				if t.pos < 0 or t.pos > sala.board.size() - 1:
					falhas += 1
					print("posição inválida ", t)
			if sala.phase == "card" and (sala.card == null or String(sala.card.word) == ""):
				falhas += 1
				print("carta vazia")
		var vencedor = sala.estado.winner
		print("partida %d: tabuleiro %d, %d passos, venceu %s, fases %s" % [partida, sala.board.size(), passos, vencedor, fases.keys()])
		if sala.phase != "over":
			falhas += 1
		sala.send({"t": "back_to_lobby"})
		if sala.phase != "lobby":
			falhas += 1
		sala.queue_free()
	print("FALHAS=", falhas)
	quit(1 if falhas else 0)
