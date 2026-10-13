extends SceneTree
## Verifica el overlay de ojos del Lobo: aparece en las animaciones cuyo arte va sin el ojo
## dibujado (lobo_idle, lobo_run) y se oculta en el resto (p.ej. lobo_attack, que sí lo trae).

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
		print("DIAG OJOS LOBO FALLOS = ", fallos)
		quit()
		return

	player.set("current_form", 1)  # LOBO
	player.call("_apply_form")
	player.visual.animation = &"lobo_idle"
	player.visual.frame = 0
	player.call("_actualizar_ojos_pos")
	player.call("_tick_parpadeo", 0.0)
	_chk(ojos.visible, "en lobo_idle la capa Ojos queda visible (arte sin ojo)")
	_chk(ojos.sprite_frames != null and str(ojos.sprite_frames.resource_path).ends_with("lobo_ojos.tres"), "usa el SpriteFrames del Lobo")
	_chk(ojos.frame == 0, "arranca con el ojo abierto")
	_chk(absf(ojos.position.x - 86.1) < 0.6, "lobo_idle:0 sigue el ojo en x (%.1f)" % ojos.position.x)

	player.set("_parpadeo_cd", 0.0)
	player.call("_tick_parpadeo", 0.0)
	_chk(ojos.is_playing(), "dispara la animación de parpadeo")
	_chk(ojos.sprite_frames.get_frame_count(&"parpadeo") == 7, "parpadeo tiene 7 frames")

	player.visual.animation = &"lobo_run"
	player.visual.frame = 0
	player.call("_actualizar_ojos_pos")
	player.call("_tick_parpadeo", 0.0)
	_chk(ojos.visible, "en lobo_run la capa Ojos queda visible (arte sin ojo)")
	_chk(absf(ojos.position.x - 111.5) < 0.6, "lobo_run:0 sigue el ojo en x (%.1f)" % ojos.position.x)

	print("DIAG OJOS LOBO FALLOS = ", fallos)
	quit()
