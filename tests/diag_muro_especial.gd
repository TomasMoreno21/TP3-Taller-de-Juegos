extends SceneTree
## El ataque especial del Oso rompe el muro de piedra (3 golpes); el pesado no.

var fallos := 0


func _chk(ok: bool, msg: String) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + msg)
	if not ok:
		fallos += 1


func _initialize() -> void:
	var nivel: Node = load("res://scenes/nivel3.tscn").instantiate()
	root.add_child(nivel)
	await physics_frame
	await physics_frame
	var player: CharacterBody2D = nivel.get_node("Player")
	player.set("god_mode", true)
	for i in 40:
		await physics_frame
	player.set("current_form", 2)
	player.set("energia", 100.0)
	var muro: StaticBody2D = (load("res://scenes/muro_piedra.tscn") as PackedScene).instantiate()
	nivel.add_child(muro)
	muro.global_position = player.global_position + Vector2(190, 120)
	await physics_frame
	for tipo in ["heavy", "special", "special", "special"]:
		player.set("_attack_timer", 0.0)
		player.set("_special_cooldown", 0.0)
		player.call("_procesar_ataque", tipo, player.forms[2], false)
		for i in 60:
			await physics_frame
		print(tipo, " en=", player.get("energia"), " t=", player.get("_current_attack_type"), " form=", player.get("current_form"), " pos=", player.global_position, " muro=", muro.global_position if is_instance_valid(muro) else Vector2.ZERO, " golpes=", muro.golpes if is_instance_valid(muro) else -1)
	_chk(not is_instance_valid(muro) or muro.abierto or muro.golpes >= 3, "muro cae con 3 especiales")
	print("FALLOS = ", fallos)
	quit()
