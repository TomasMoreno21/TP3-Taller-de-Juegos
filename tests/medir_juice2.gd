extends SceneTree
## Herramienta manual (necesita ventana, sin --headless): daño, almas, grietas del Oso, escombros,
## cristal y cine del jefe sobre el nivel 1. Guarda user://juice2_*.png.
## godot --path . --resolution 1920x1080 --script res://tests/medir_juice2.gd

func _initialize() -> void:
	var nivel: Node = load("res://scenes/nivel1.tscn").instantiate()
	root.add_child(nivel)
	for i in 60:
		await physics_frame
	var p: CharacterBody2D = get_first_node_in_group("player")
	if p == null:
		quit()
		return
	# Daño
	p.set("god_mode", false)
	p.call("_juice_dano", 14)
	await create_timer(0.12, true, false, true).timeout
	_captura("dano")
	await create_timer(1.0, true, false, true).timeout
	# Almas
	AlmaEnergia.lanzar(self, p.global_position + Vector2(500, -100), p, 5, Color(0.55, 0.95, 1.0))
	await create_timer(0.25, true, false, true).timeout
	_captura("alma_a")
	await create_timer(0.25, true, false, true).timeout
	_captura("alma_b")
	await create_timer(1.0, true, false, true).timeout
	# Oso: grietas y escombros
	p.call("_restaurar_forma", 2)
	p.call("_juice_oso_suelo", 900.0)
	JuiceFx.escombros(self, p.global_position + Vector2(300, 100), Color(0.5, 0.45, 0.4), 12, 1.0)
	JuiceFx.nota_cristal(self)
	await create_timer(0.2, true, false, true).timeout
	_captura("oso")
	await create_timer(1.8, true, false, true).timeout
	# Jefe cine
	JefeCine.entrada(self, "EL ARZOBISPO", Color(0.28, 0.5, 0.32), 2.6)
	await create_timer(1.6, true, false, true).timeout
	_captura("jefe_entrada")
	for n in root.get_children():
		if n is CanvasLayer and n.layer == 9:
			print("CAPA9 ts=", Engine.time_scale, " hijos=", n.get_child_count(), " arriba.y=", n.get_child(0).position.y, " titulo.a=", n.get_child(2).modulate.a)
	await create_timer(1.5, true, false, true).timeout
	JefeCine.grieta(self, Color(0.45, 0.32, 0.6))
	await create_timer(0.3, true, false, true).timeout
	_captura("jefe_grieta")
	await create_timer(1.0, true, false, true).timeout
	print("JUICE2 listo; time_scale=", Engine.time_scale)
	quit()


func _captura(nombre: String) -> void:
	root.get_texture().get_image().save_png("user://juice2_%s.png" % nombre)
