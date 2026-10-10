extends SceneTree
## Nivel 3 (cueva profunda): el muro solo cae con el Oso, la losa abre la compuerta solo con Oso,
## el suelo quebradizo pesado solo cede al Oso y el nivel carga con su fondo.

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
	_chk(nivel.get_node_or_null("FondoProfundo") != null, "nivel3 tiene FondoProfundo")
	_chk(nivel.get_node_or_null("NocheProfunda") != null, "nivel3 tiene NocheProfunda")
	var player: CharacterBody2D = nivel.get_node("Player")
	player.set("god_mode", true)

	# Muro: Humano no lo rompe; Oso con golpe flojo tampoco; Oso con golpe pesado sí (3 golpes).
	var muro: StaticBody2D = (load("res://scenes/muro_piedra.tscn") as PackedScene).instantiate()
	nivel.add_child(muro)
	player.set("current_form", 0)
	for i in 5:
		muro.registrar_golpe(50)
	_chk(muro.golpes == 0 and not muro.abierto, "muro: el Humano no lo daña")
	player.set("current_form", 2)
	muro.registrar_golpe(10)
	_chk(muro.golpes == 0, "muro: golpe flojo del Oso no cuenta")
	for i in muro.golpes_para_romper:
		muro.registrar_golpe(24)
	_chk(muro.abierto and muro.collision_layer == 0, "muro: 3 golpes pesados del Oso lo rompen")

	# Compuerta + losa.
	var puerta: StaticBody2D = (load("res://scenes/muro_piedra.tscn") as PackedScene).instantiate()
	puerta.solo_por_losa = true
	nivel.add_child(puerta)
	var losa: Area2D = (load("res://scenes/losa_peso.tscn") as PackedScene).instantiate()
	losa.global_position = Vector2(900, 400)   # dentro de los límites de la cámara (el jugador queda confinado a ellos) y en el aire de la entrada
	nivel.add_child(losa)
	var rutas: Array[NodePath] = [losa.get_path_to(puerta)]
	losa.objetivos = rutas
	player.global_position = losa.global_position + Vector2(0, -60)
	player.velocity = Vector2.ZERO
	await physics_frame
	await physics_frame
	puerta.registrar_golpe(99)
	_chk(not puerta.abierto, "compuerta: no se rompe a golpes")
	player.set("current_form", 0)
	player.pisoton.emit(player.global_position)
	_chk(not puerta.abierto, "losa: el Humano no la activa")
	player.set("current_form", 2)
	player.aterrizaje_fuerte.emit(player.global_position, 100.0)
	_chk(not puerta.abierto, "losa: un aterrizaje flojo no la activa")
	player.pisoton.emit(player.global_position)
	_chk(puerta.abierto, "losa: el pisotón del Oso abre la compuerta")

	# Suelo quebradizo pesado.
	var pf: StaticBody2D = (load("res://scenes/plataforma_fragil.tscn") as PackedScene).instantiate()
	pf.forma_requerida = 2
	pf.global_position = Vector2(-30000, -30000)
	nivel.add_child(pf)
	_chk(pf.forma_requerida == 2, "plataforma frágil: exporta forma_requerida")

	print("DIAG NIVEL3 OSO FALLOS = ", fallos)
	quit()
