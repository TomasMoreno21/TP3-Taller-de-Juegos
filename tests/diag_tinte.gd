extends SceneTree

var _failures := 0


func _init() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var player = scene.get_node("Player")

	# Debe estar en la escena (humano por defecto)
	_check(player.visual != null, "Visual node existe")

	# Revisar cada forma y reportar valores exactos de tinte
	for idx in range(player.forms.size()):
		player.current_form = idx
		await process_frame
		await process_frame
		var data = player.forms[idx]
		var self_col: Color = player.visual.self_modulate
		var mod_a: float = player.visual.modulate.a
		print("FORMA %d (%s): self_modulate=(%.3f,%.3f,%.3f,%.3f) modulate.a=%.3f" % [
			idx, data.form_name,
			self_col.r, self_col.g, self_col.b, self_col.a,
			mod_a
		])

		# No debe haber transparencia oculta
		_check(absf(mod_a - 1.0) < 0.01,
			"%s: modulate.a == 1.0 (sin transparencia rara)" % data.form_name)
		_check(self_col.a > 0.9,
			"%s: self_modulate.a > 0.9" % data.form_name)

		# El self_modulate debe ser luminoso (lerp con WHITE >= 0.55)
		_check(self_col.r > 0.5 and self_col.g > 0.5 and self_col.b > 0.5,
			"%s: self_modulate luminosa (lerp WHITE 0.55 ok)" % data.form_name)

	print("DIAG TINTE: FALLOS = " + str(_failures))
	if _failures == 0:
		print("DIAG TINTE: OK")
		quit(0)
	else:
		quit(1)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		print("[FAIL] " + msg)
