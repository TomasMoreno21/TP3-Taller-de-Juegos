extends SceneTree
## El combate no arranca mientras el muro requerido siga entero; arranca al romperlo con el jugador dentro.
func _initialize() -> void:
	var fallos := 0
	var enc := (load("res://scenes/encounter.tscn") as PackedScene).instantiate()
	var muro := (load("res://scenes/muro_piedra.tscn") as PackedScene).instantiate()
	root.add_child(muro)
	muro.name = "Muro"
	enc.requiere_muro_roto = NodePath("../Muro")
	root.add_child(enc)
	await process_frame
	var jugador := Node2D.new()
	jugador.add_to_group("player")
	enc._on_body_entered(jugador)
	if enc.estado != 0:
		fallos += 1
		print("[FAIL] con el muro entero no debe empezar")
	muro.abrir()
	if enc._muro_pendiente:
		fallos += 1
		print("[FAIL] al romper el muro debe liberarse")
	enc._on_body_entered(jugador)
	if enc.estado == 0:   # sin olas se completa al instante (2): basta con que haya empezado
		fallos += 1
		print("[FAIL] tras romper el muro debe empezar")
	print("DIAG ENCOUNTER MURO FALLOS = ", fallos)
	quit()
