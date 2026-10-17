extends SceneTree
## Combo ligero+fuerte rápido: el golpe fuerte en cola sale al conectar el ligero, sin esperar la recuperación.
## Uso: --headless --script res://tests/diag_combo_rapido.gd
var fallos := 0
func _check(c: bool, m: String) -> void:
	print(("[PASS] " if c else "[FAIL] ") + m)
	if not c:
		fallos += 1
func _initialize() -> void:
	var nivel: Node = load("res://scenes/nivel1.tscn").instantiate()
	root.add_child(nivel)
	await process_frame
	await process_frame
	var p := get_first_node_in_group("player") as CharacterBody2D
	p.set("god_mode", true)
	var prog := root.get_node("Progresion")
	prog.reset()
	prog.elegir_mejora(0)   # combo del Humano (ligero + fuerte)
	for i in 40:
		await physics_frame
	var nombres: Array = []
	p.attack_performed.connect(func(t: String, s: Variant) -> void: nombres.append(str(s) if t == "combo" else t))
	# Ligero y, al instante, fuerte (se encola). Con el ligero conectado/fallado sale el combo sin esperar la recuperación.
	p._procesar_ataque("light", p.forms[0], false)
	p.set("_buffered_attack", "heavy")
	p.set("_hit_applied", true)
	var rec: float = p.get("_attack_rec")
	var t0 := 0.0
	while not nombres.has("Remate") and t0 < rec + 0.5:
		await physics_frame
		t0 += 1.0 / 60.0
	_check(nombres.has("Remate"), "ligero+fuerte rápido ejecuta el combo (%.2f s de %.2f s de recuperación)" % [t0, rec])
	_check(t0 < rec * 0.6, "sale antes de agotar la recuperación del ligero")
	print("FALLOS = %d" % fallos)
	quit(fallos)
