extends SceneTree
## Voladores (enemigos `flotante`): al activarse no deben quedar dentro del terreno ni más arriba del techo, y
## mientras flotan/persiguen no deben atravesar el techo (el terreno enterrado no tiene colisión, solo una banda).

var fallos := 0
var _nivel: Node


func _chk(ok: bool, msg: String) -> void:
	if ok:
		print("ok   ", msg)
	else:
		fallos += 1
		print("FAIL ", msg)


func _celda_solida(p: Vector2) -> bool:
	var tm := _nivel.get_node_or_null("TileMap") as TileMapLayer
	return tm != null and tm.get_cell_source_id(tm.local_to_map(tm.to_local(p))) != -1


func _cuerpo_en_terreno(e: Node2D) -> int:
	var cs := e.get("collide_shape") as CollisionShape2D
	var tam: Vector2 = (cs.shape as RectangleShape2D).size if cs != null else Vector2(40, 60)
	var c: Vector2 = cs.global_position if cs != null else e.global_position
	var n := 0
	for fx in [-0.5, 0.0, 0.5]:
		for fy in [-0.5, 0.0, 0.5]:
			if _celda_solida(c + Vector2(tam.x * fx, tam.y * fy)):
				n += 1
	return n


func _voladores(n: Node, r: Array) -> void:
	for h in n.get_children():
		if h.get("flotante") == true:
			r.append(h)
		_voladores(h, r)


func _nivel_probar(ruta: String) -> void:
	_nivel = load(ruta).instantiate()
	root.add_child(_nivel)
	for i in 6:
		await physics_frame
	var lista: Array = []
	_voladores(_nivel, lista)
	print("== ", ruta, ": ", lista.size(), " voladores")
	var jugador := get_first_node_in_group("player") as Node2D
	for e in lista:
		var nombre := "%s/%s" % [e.get_parent().name, e.name]
		var y_suelo: float = e.global_position.y
		e.activar()
		for i in 5:
			await physics_frame
		var alzado: float = y_suelo - e.global_position.y
		_chk(alzado >= 120.0, "%s flota %.0f px sobre el piso (pedido %.0f)" % [nombre, alzado, e.altura_flote])
		var dentro := _cuerpo_en_terreno(e)
		_chk(dentro == 0, "%s al aparecer: %d/9 puntos del cuerpo dentro del terreno (y=%.0f)" % [nombre, dentro, e.global_position.y])
		var y0: float = e.global_position.y
		# Persigue/flota un rato, con el jugador debajo; no puede acabar dentro del terreno.
		if jugador != null:
			jugador.global_position = e.global_position + Vector2(60.0, float(e.altura_flote))
		var peor := 0
		for i in 240:
			await physics_frame
			if is_instance_valid(e):
				peor = maxi(peor, _cuerpo_en_terreno(e))
		_chk(peor == 0, "%s tras 4 s flotando: máx %d/9 puntos en terreno" % [nombre, peor])
	_nivel.queue_free()
	await physics_frame


func _initialize() -> void:
	await _nivel_probar("res://scenes/nivel2.tscn")
	await _nivel_probar("res://scenes/nivel3.tscn")
	print("DIAG VOLADORES FALLOS = ", fallos)
	quit()
