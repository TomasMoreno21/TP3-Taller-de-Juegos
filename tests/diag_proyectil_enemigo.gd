extends SceneTree
## El proyectil del enemigo apunta al centro del cuerpo del jugador (collider), no a su origen (altura de la cabeza).

var fallos := 0

func _chk(ok: bool, msg: String) -> void:
	if ok:
		print("ok   ", msg)
	else:
		fallos += 1
		print("FAIL ", msg)


func _initialize() -> void:
	var mundo := Node2D.new()
	root.add_child(mundo)
	var e: CharacterBody2D = (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
	e.set("tipo", "arquero")
	mundo.add_child(e)
	e.global_position = Vector2(0, 0)
	var obj := Node2D.new()
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(40, 100)
	cs.shape = r
	cs.position = Vector2(0, 70)   # el cuerpo queda 70 px por debajo del origen (cabeza)
	obj.add_child(cs)
	mundo.add_child(obj)
	obj.global_position = Vector2(600, 0)
	for i in 3:
		await physics_frame
	e.call("_disparar", obj)
	var proj: Node = null
	for n in mundo.get_children():
		if n is Area2D:
			proj = n
	_chk(proj != null, "el enemigo dispara un proyectil")
	if proj != null:
		var d: Vector2 = proj.get("direction")
		var al_origen: Vector2 = (obj.global_position - proj.global_position).normalized()
		var al_cuerpo: Vector2 = (obj.global_position + Vector2(0, 70) - proj.global_position).normalized()
		_chk(d.distance_to(al_cuerpo) < 0.01 and d.distance_to(al_origen) > 0.03, "apunta al centro del cuerpo (dir.y=%.3f; al origen %.3f)" % [d.y, al_origen.y])
	print("DIAG PROYECTIL ENEMIGO FALLOS = ", fallos)
	quit()
