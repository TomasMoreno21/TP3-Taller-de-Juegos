extends SceneTree
## Verifica que la base visible de cada frame de cada forma quede a la altura del piso (±2 px).

func _initialize() -> void:
	var fallos := 0
	var player: CharacterBody2D = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	await physics_frame
	var visual: AnimatedSprite2D = player.get("visual")
	var sf := visual.sprite_frames
	var col: CollisionShape2D = player.get("collision_shape")
	var hundidos: float = player.get("pies_hundidos")
	var esc_y := absf(visual.scale.y)
	var con_relleno := 0
	for f in 4:
		player.set("current_form", f)
		player.call("_apply_form")
		var suelo: float = 142.5 - float(player.get("forms")[f].flight_lift) - float(player.get("forms")[f].patas_alto) + hundidos
		for anim in sf.get_animation_names():
			for i in sf.get_frame_count(anim):
				visual.animation = anim
				visual.frame = i
				player.call("_anclar_pies")
				var tex := sf.get_frame_texture(anim, i)
				var pad: float = Pies.relleno_inferior(tex)
				if pad > 0.0:
					con_relleno += 1
				var base_y := visual.position.y + (visual.offset.y + tex.get_height() * 0.5 - pad) * esc_y
				if absf(base_y - suelo) > 2.0:
					fallos += 1
					print("FAIL forma %d %s[%d]: pies %.1f vs suelo %.1f" % [f, anim, i, base_y, suelo])
	print("frames con relleno inferior detectado: ", con_relleno)
	print("DIAG PIES FALLOS = ", fallos)
	quit()
