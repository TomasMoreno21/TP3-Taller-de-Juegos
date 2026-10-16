extends SceneTree
## El diálogo de la enredadera sale al completarse EncounterGuardian (nivel 3), no antes.
func _init() -> void:
	await process_frame
	var prog := root.get_node("Progresion")
	prog.reset()
	var nivel: Node = (load("res://scenes/nivel3.tscn") as PackedScene).instantiate()
	root.add_child(nivel)
	await process_frame
	var enc: Node = nivel.get_node("EncounterGuardian")
	var d := root.get_node("Dialogo")
	var fallos := 0
	if prog.dialogo_visto("n3_liana"):
		fallos += 1; print("[FAIL] ya estaba visto")
	enc.completado.emit()
	await create_timer(2.0).timeout
	if not prog.dialogo_visto("n3_liana"):
		fallos += 1; print("[FAIL] no salió el diálogo al completar la arena")
	else:
		print("[OK] sale al completar la arena")
	print("DIAG_DIALOGO_LIANA: FALLOS = %d" % fallos)
	quit()
