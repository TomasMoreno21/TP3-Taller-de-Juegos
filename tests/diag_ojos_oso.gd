extends SceneTree
## Verifica el overlay de ojos del Oso: existe, sigue el frame del cuerpo y solo en Oso.

var fallos := 0


func _chk(ok: bool, msg: String) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + msg)
	if not ok:
		fallos += 1


func _initialize() -> void:
	var nivel: Node = load("res://scenes/nivel3.tscn").instantiate()
	root.add_child(nivel)
	for n in nivel.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("dialog_trigger.gd"):
			n.queue_free()
	await physics_frame
	await physics_frame
	var player: CharacterBody2D = nivel.get_node("Player")
	var ojos: AnimatedSprite2D = player.get_node_or_null("Sprite2D/Ojos")
	_chk(ojos != null, "el Player tiene la capa Ojos")
	if ojos == null:
		print("DIAG OJOS OSO FALLOS = ", fallos)
		quit()
		return
	_chk(ojos.sprite_frames != null and ojos.sprite_frames.has_animation("parpadeo"), "Ojos tiene la animación parpadeo")

	_chk(not ojos.visible, "los ojos arrancan ocultos")

	player.set("current_form", 2)  # OSO
	player.call("_apply_form")
	player.visual.animation = &"oso_caminar"
	player.visual.frame = 2
	player.call("_actualizar_ojos_pos")
	player.call("_tick_parpadeo", 0.0)
	_chk(ojos.visible, "en caminar la capa Ojos queda visible (arte sin ojo)")
	_chk(ojos.frame == 0, "arranca con el ojo abierto")
	_chk(absf(ojos.position.x - 162.5) < 0.6, "caminar:2 sigue el ojo en x (%.1f)" % ojos.position.x)

	player.visual.frame = 3
	player.call("_actualizar_ojos_pos")
	_chk(absf(ojos.position.x - 170.5) < 0.6, "caminar:3 sigue el ojo en x (%.1f)" % ojos.position.x)

	player.set("_parpadeo_cd", 0.0)
	player.call("_tick_parpadeo", 0.0)
	_chk(ojos.is_playing(), "dispara la animación de parpadeo")
	_chk(ojos.sprite_frames.get_frame_count(&"parpadeo") == 7, "parpadeo tiene 7 frames")

	player.visual.animation = &"oso_idle"
	player.visual.frame = 0
	player.call("_actualizar_ojos_pos")
	player.call("_tick_parpadeo", 0.0)
	_chk(ojos.visible, "en idle la capa Ojos queda visible (arte sin ojo)")
	_chk(absf(ojos.position.x - 159.5) < 0.6, "idle:0 sigue el ojo en x (%.1f)" % ojos.position.x)

	player.set("current_form", 0)  # HUMANO
	player.call("_apply_form")
	player.call("_tick_parpadeo", 10.0)
	_chk(not ojos.visible, "en Humano los ojos quedan ocultos")

	print("DIAG OJOS OSO FALLOS = ", fallos)
	quit()
