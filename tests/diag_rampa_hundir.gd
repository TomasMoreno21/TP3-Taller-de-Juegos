extends SceneTree
## Sobre las rampas suaves invisibles el sprite baja hasta apoyar los pies en los bloques visibles (no flota).

var fallos := 0

func _chk(ok: bool, msg: String) -> void:
	if ok:
		print("ok   ", msg)
	else:
		fallos += 1
		print("FAIL ", msg)


func _initialize() -> void:
	var nivel: Node = (load("res://scenes/nivel3.tscn") as PackedScene).instantiate()
	root.add_child(nivel)
	for i in 6:
		await physics_frame
	var p := get_first_node_in_group("player") as CharacterBody2D
	var rampas := nivel.get_node_or_null("Rampas")
	var cuerpo: StaticBody2D = null
	for n in get_nodes_in_group("rampa_suave"):
		cuerpo = n
	_chk(cuerpo != null, "hay rampas suaves")
	var owners := cuerpo.get_shape_owners()
	var probados := 0
	var peor := 0.0
	var tot := 0
	for i in range(0, cuerpo.shape_owner_get_shape_count(owners[0]), 25):
		var pts: PackedVector2Array = (cuerpo.shape_owner_get_shape(owners[0], i) as ConvexPolygonShape2D).points
		var xs := [pts[0].x, pts[1].x, pts[2].x]
		var x := (minf(xs[0], minf(xs[1], xs[2])) + maxf(xs[0], maxf(xs[1], xs[2]))) * 0.5
		p.global_position = Vector2(x, pts[0].y - 200.0)
		p.velocity = Vector2.ZERO
		for k in 90:
			await physics_frame
		if not p.is_on_floor():
			continue
		tot += 1
		var hover: float = p.call("_altura_sobre_bloques")
		var bajado: float = p.get("_suave_y")
		if bool(p.get("_sobre_rampa")) and hover > 1.0:
			probados += 1
			peor = maxf(peor, absf(minf(hover, float(p.get("rampa_hundimiento"))) - bajado))
	print("rampas con levantamiento medido: %d de %d; peor diferencia %.2f px" % [probados, tot, peor])
	_chk(probados > 0, "se probó al menos una rampa que levanta al jugador")
	_chk(peor < 2.0, "el sprite baja lo que lo levanta la rampa (peor %.2f px)" % peor)
	print("DIAG RAMPA HUNDIR FALLOS = ", fallos)
	quit()
