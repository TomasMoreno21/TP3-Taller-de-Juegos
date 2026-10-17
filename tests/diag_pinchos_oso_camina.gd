extends SceneTree
## El Oso camina y salta por el tramo final del nivel 3 (piso de pinchos entre plataformas): parado en el piso con el
## centro sobre los pinchos y los pies a <= 60 px de las puntas TIENE que estar en la zona de daño (antes su collider
## ancho se apoyaba en los bordes del pozo y caminaba encima sin daño).
var _f := 0
func _init() -> void:
	await process_frame
	var nivel: Node = load("res://scenes/nivel3.tscn").instantiate()
	root.add_child(nivel)
	for n in nivel.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("dialog_trigger.gd"):
			n.queue_free()
	await physics_frame
	await physics_frame
	var p: CharacterBody2D = nivel.get_node("Player")
	p.god_mode = true
	var forma := int(OS.get_environment("FORMA")) if OS.get_environment("FORMA") != "" else 2
	p._transformar(forma, true)
	var x0 := float(OS.get_environment("X0")) if OS.get_environment("X0") != "" else 16900.0
	p.global_position = Vector2(x0, float(OS.get_environment("Y0")) if OS.get_environment("Y0") != "" else 6000.0)
	var pins := get_nodes_in_group("pinchos")
	Input.action_press("move_right")
	for i in 900:
		await physics_frame
		p.set("energia", 100.0)
		if i % 20 == 0:
			Input.action_press("jump")
		elif i % 20 == 3:
			Input.action_release("jump")
		for pin in pins:
			var loc: Vector2 = pin.global_transform.affine_inverse() * p.global_position
			if absf(loc.x) < pin._kill_zone_size.x * 0.5 and loc.y > -260.0 and loc.y < 100.0:
				if p.is_on_floor() and loc.y > -245.0 and not pin._cuerpo_en_zona(p):
					print("[FAIL] f%d %s pos=%s parado sobre los pinchos sin daño (locy=%.0f)" % [i, pin.name, p.global_position.round(), loc.y])
					_f += 1
	Input.action_release("move_right")
	Input.action_release("jump")
	print("DIAG PINCHOS OSO: FALLOS = ", _f)
	quit(1 if _f > 0 else 0)
