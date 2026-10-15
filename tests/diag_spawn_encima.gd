extends SceneTree
## Un enemigo que se materializa encima del jugador se corre al costado y no lo empuja hacia el piso.
## Uso: godot --headless --script tests/diag_spawn_encima.gd

var fallos := 0

func _chk(nombre: String, ok: bool) -> void:
	print("[%s] %s" % ["OK" if ok else "FAIL", nombre])
	if not ok:
		fallos += 1


func _init() -> void:
	await process_frame
	var suelo := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(6000, 40)
	col.shape = rect
	suelo.add_child(col)
	suelo.position = Vector2(0, 100)
	root.add_child(suelo)
	var player: Node2D = load("res://scenes/player.tscn").instantiate()
	player.position = Vector2(0, 60)
	root.add_child(player)
	var enemigo: Node2D = load("res://scenes/enemy.tscn").instantiate()
	enemigo.position = Vector2(0, 80)   # justo donde está el jugador
	root.add_child(enemigo)
	for i in 5:
		await physics_frame
	var y0: float = player.global_position.y
	enemigo._colision(true)
	for i in 90:
		await physics_frame
	_chk("el jugador no se hunde (y %.1f -> %.1f)" % [y0, player.global_position.y], player.global_position.y <= y0 + 3.0)
	_chk("el enemigo quedó al costado (x=%.0f)" % enemigo.global_position.x, absf(enemigo.global_position.x - player.global_position.x) > 100.0)
	print("DIAG_SPAWN_ENCIMA: FALLOS = %d" % fallos)
	quit()
