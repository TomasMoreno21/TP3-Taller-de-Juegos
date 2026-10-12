extends SceneTree
## Picos de frame jugando (bot: avanza, salta y usa acciones al azar) desde varios checkpoints de un nivel.
## NIVEL=2 FRAMES=1500 godot --path . --resolution 1920x1080 --disable-vsync --max-fps 0 --script res://tests/medir_picos.gd
## Imprime PICO: percentiles de ms/frame y los frames más lentos con su posición (para ver qué los causa).

func _scripts(n: Node) -> String:
	var s := n.get_script() as Script
	return s.resource_path.get_file() if s != null else ""


func _buscar(esc: Node, archivo: String) -> Array:
	var r := []
	var pila := [esc]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		for c in n.get_children():
			pila.append(c)
		if _scripts(n) == archivo:
			r.append(n)
	return r


func _init() -> void:
	var nivel := OS.get_environment("NIVEL")
	var frames := int(OS.get_environment("FRAMES")) if OS.get_environment("FRAMES") != "" else 1500
	await process_frame
	var esc: Node = (load("res://scenes/nivel%s.tscn" % nivel) as PackedScene).instantiate()
	for t in _buscar(esc, "titulo_nivel.gd"):
		t.free()
	for i in _buscar(esc, "intro_nivel.gd"):
		root.get_node("Progresion").marcar_dialogo_visto(i.id_visto)
	var puntos := []
	for c in _buscar(esc, "checkpoint.gd"):
		puntos.append((c as Node2D).global_position)
	puntos.sort_custom(func(a, b): return a.y + a.x * 0.01 < b.y + b.x * 0.01)
	if puntos.size() >= 3:
		puntos = [puntos[0], puntos[puntos.size() / 2], puntos[puntos.size() - 1]]
	root.add_child(esc)
	current_scene = esc
	for s in _buscar(esc, "salida_nivel.gd"):
		s.process_mode = Node.PROCESS_MODE_DISABLED
	var p: Node2D = esc.get_node("Player")
	p.set("god_mode", true)
	var acts := ["jump", "attack", "heavy", "special", "block", "transform"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for _w in 120:
		await process_frame
	var todos := []
	var picos := []
	for pt in puntos:
		p.global_position = pt + Vector2(0, -60)
		p.velocity = Vector2.ZERO
		for i in 60:
			await process_frame
		Input.action_press("move_right")
		var ant := Time.get_ticks_usec()
		for f in frames:
			await process_frame
			var ahora := Time.get_ticks_usec()
			var ms := (ahora - ant) / 1000.0
			ant = ahora
			todos.append(ms)
			if ms > 8.0:
				picos.append([ms, p.global_position, f])
			if f % 40 == 0:
				var a: String = acts[rng.randi() % acts.size()]
				Input.action_press(a)
				await process_frame
				Input.action_release(a)
			if f % 300 == 0:
				p.set("health", 100)
		Input.action_release("move_right")
	todos.sort()
	var n := todos.size()
	print("PICO nivel", nivel, " frames=", n, " p50=", snappedf(todos[n / 2], 0.01), " p95=", snappedf(todos[int(n * 0.95)], 0.01),
		" p99=", snappedf(todos[int(n * 0.99)], 0.01), " max=", snappedf(todos[n - 1], 0.01), " >8ms=", picos.size())
	picos.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(12, picos.size()):
		print("PICO  ", snappedf(picos[i][0], 0.1), " ms en ", picos[i][1], " (frame ", picos[i][2], ")")
	quit()
