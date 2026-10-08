extends SceneTree
## Herramienta manual (necesita ventana, sin --headless): dispara tajo+onomatopeya, transformación y parry
## sobre el nivel 1 y guarda capturas en user://juice_*.png.
## godot --path . --resolution 1920x1080 --script res://tests/medir_juice.gd

func _initialize() -> void:
	var nivel: Node = load("res://scenes/nivel1.tscn").instantiate()
	root.add_child(nivel)
	for i in 60:
		await physics_frame
	var p: CharacterBody2D = get_first_node_in_group("player")
	if p == null:
		print("sin player")
		quit()
		return
	p.global_position = p.global_position
	# Golpes
	p.set("_current_attack_type", "heavy")
	p.call("_juice_golpe", p.global_position + Vector2(150, 40), Color(1, 0.9, 0.4), 0)
	for i in 2:
		await process_frame
	_captura("golpe")
	for i in 4:
		await process_frame
	_captura("golpe2")
	await create_timer(0.6, true, false, true).timeout
	# Transformación
	p.call("_transformar", 1, true)
	await create_timer(0.05, true, false, true).timeout
	_captura("transf_a")
	await create_timer(0.3, true, false, true).timeout
	_captura("transf_b")
	await create_timer(1.2, true, false, true).timeout
	# Parry
	p.call("_parry_perfecto", 1)
	for k in 6:
		await create_timer(0.12, true, false, true).timeout
		_captura("parry_%d" % k)
		var info := "t=%d ts=%s" % [k, str(Engine.time_scale)]
		for n in root.get_children():
			if n is ParryBN:
				var m: ShaderMaterial = n._mat
				info += " BN cant=%s radio=%s" % [str(m.get_shader_parameter("cantidad")), str(m.get_shader_parameter("radio"))]
			if n is CanvasLayer and not (n is ParryBN):
				info += " CL%d" % n.layer
		print(info)
	await create_timer(1.5, true, false, true).timeout
	print("JUICE listo; time_scale=", Engine.time_scale)
	quit()


func _captura(nombre: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("user://juice_%s.png" % nombre)
