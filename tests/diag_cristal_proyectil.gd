extends SceneTree
## Barrera de cristales: reparto vertical, solo proyectil rompe, y el teledirigido no mira a través de la roca.
## Uso: godot --headless --script tests/diag_cristal_proyectil.gd

var fallos := 0

func _chk(nombre: String, ok: bool) -> void:
	print("[%s] %s" % ["OK" if ok else "FAIL", nombre])
	if not ok:
		fallos += 1


func _init() -> void:
	await process_frame
	var gs := GDScript.new()
	gs.source_code = "extends Node2D\nvar current_form := 3\n"
	gs.reload()
	var j := Node2D.new()
	j.set_script(gs)
	j.add_to_group("player")
	root.add_child(j)
	var b: Node2D = load("res://scenes/barrera_bosque.tscn").instantiate()
	b.tam_barrera = Vector2(220, 1120)
	b.centro_barrera = Vector2(0, -395)
	b.distribuir_cristales_vertical = true
	b.cristales_solo_proyectil = true
	b.barrera_id = "diag_cristal"
	root.add_child(b)
	await physics_frame
	var ys: Array = []
	for c in b.get_children():
		if c.is_in_group("cristal"):
			ys.append(c.position.y)
	_chk("3 cristales repartidos de arriba a abajo", ys.size() == 3 and ys[0] < ys[1] and ys[1] < ys[2] and ys[0] >= -955.0 and ys[2] <= 165.0)
	var c1: Node = b.get_child(b.get_child_count() - 3)
	for c in b.get_children():
		if c.is_in_group("cristal"):
			c1 = c
			break
	for i in 5:
		c1.take_damage(10, 0.0, 1)
	_chk("golpes normales no lo rompen", c1.get("_golpes") == 0 and not c1.get("_roto"))
	for i in 3:
		c1.golpe_proyectil = true
		c1.take_damage(10, 0.0, 1)
	_chk("el proyectil sí lo rompe", c1.get("_roto") == true)
	# línea de visión: una pared entre dos puntos la corta
	var pared := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(40, 400)
	cs.shape = r
	pared.add_child(cs)
	pared.position = Vector2(2000, 0)
	root.add_child(pared)
	await physics_frame
	await physics_frame
	var P = load("res://scripts/projectile.gd")
	_chk("línea libre sin pared", P.linea_libre(j, Vector2(1500, 0), Vector2(1700, 0)))
	_chk("la pared corta la línea", not P.linea_libre(j, Vector2(1500, 0), Vector2(2500, 0)))
	print("DIAG_CRISTAL_PROYECTIL: FALLOS = %d" % fallos)
	quit()
