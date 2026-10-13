extends SceneTree
## StreamingZonas duerme las luces fijas lejanas del nivel 1 y las despierta al acercarse (no toca luciérnagas ni jugador).
## godot --headless --path . --script res://tests/diag_streaming_luces.gd   (usa ventana si hay: da igual)

var fallos := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fallos += 1
	print("[ OK ] " if ok else "[FAIL] ", msg)


func _luces(esc: Node) -> Array:
	var r := []
	var pila := [esc]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		for c in n.get_children():
			pila.append(c)
		if n is Light2D:
			r.append(n)
	return r


func _init() -> void:
	await process_frame
	root.get_node("Progresion").marcar_dialogo_visto("intro_nivel1")
	var esc = (load("res://scenes/nivel1.tscn") as PackedScene).instantiate()
	esc.get_node("TituloNivel").free()
	root.add_child(esc)
	current_scene = esc
	var p: Node2D = esc.get_node("Player")
	p.global_position = Vector2(-1000, 900)
	p.set("god_mode", true)
	esc.get_node("SalidaNivel").process_mode = Node.PROCESS_MODE_DISABLED
	var sz = esc.get_node("StreamingZonas")
	var ra: Vector2 = sz.radio_activo
	var rd: Vector2 = ra * float(sz.histeresis)
	for i in 40:
		await process_frame
	var luces := _luces(esc)
	_check(luces.size() >= 15, "el nivel tiene luces fijas (%d)" % luces.size())
	var mal_lejos := 0
	var mal_cerca := 0
	var apagadas := 0
	var cam := root.get_viewport().get_camera_2d()
	var c0 := cam.get_screen_center_position()
	for l in luces:
		var d: Vector2 = (l.global_position - c0).abs()
		var d2: Vector2 = (l.global_position - p.global_position).abs()
		var lejos: bool = (d.x > rd.x or d.y > rd.y) and (d2.x > rd.x or d2.y > rd.y)
		var cerca: bool = (d.x <= ra.x and d.y <= ra.y) or (d2.x <= ra.x and d2.y <= ra.y)
		if l.is_in_group("player") or l.get_parent().is_in_group("player"):
			continue
		if not l.enabled:
			apagadas += 1
		if lejos and l.enabled:
			mal_lejos += 1
		if cerca and not l.enabled:
			mal_cerca += 1
	_check(apagadas > 0, "hay luces lejanas apagadas (%d de %d)" % [apagadas, luces.size()])
	_check(mal_lejos == 0, "ninguna luz lejana queda encendida (%d)" % mal_lejos)
	_check(mal_cerca == 0, "ninguna luz cercana queda apagada (%d)" % mal_cerca)
	# Despertar: llevar al jugador junto a cada luz apagada la enciende
	var apag: Array = luces.filter(func(l): return not l.enabled)
	var objetivo: Light2D = apag[0]
	p.global_position = objetivo.global_position
	for i in 40:
		await process_frame
	_check(objetivo.enabled, "al acercarse, la luz se vuelve a encender")
	# Volver lejos la duerme otra vez
	p.global_position = Vector2(-1000, 900)
	for i in 40:
		await process_frame
	_check(not objetivo.enabled, "al alejarse, la luz se vuelve a apagar")
	# Al final, todas las luces encendidas originalmente siguen existiendo y la luz del jugador no se tocó
	var del_jugador := 0
	for l in _luces(p):
		if not l.enabled:
			del_jugador += 1
	_check(del_jugador == 0, "las luces del jugador nunca se apagan")
	print("DIAG STREAMING LUCES: FALLOS = ", fallos)
	esc.free()
	quit(1 if fallos > 0 else 0)
