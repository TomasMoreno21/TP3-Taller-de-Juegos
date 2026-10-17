extends SceneTree
## Eco del hijo: existe en N1 y N3, dispara una sola vez, deja el flag y no deja al jugador bloqueado.
var fallos := 0
func _chk(ok: bool, msg: String) -> void:
	if not ok:
		fallos += 1
		print("[FAIL] ", msg)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for n in ["nivel1", "nivel3"]:
		var escena: Node = (load("res://scenes/%s.tscn" % n) as PackedScene).instantiate()
		root.add_child(escena)
		await process_frame
		var eco: Node = escena.get_node_or_null("EcoHijo")
		_chk(eco != null, n + ": hay EcoHijo")
		if eco != null:
			_chk(not eco.lineas_grito.is_empty(), n + ": tiene diálogo del grito")
			var j: Node = get_first_node_in_group("player")
			root.get_node("Progresion").dialogos_vistos.erase("eco_hijo")
			if j != null:
				eco._on_body_entered(j)
				await process_frame
				_chk(root.get_node("Progresion").dialogos_vistos.has("eco_hijo"), n + ": marca el eco como oído")
				_chk(j.get("cinematica_activa") != true, n + ": no deja al jugador bloqueado")
				eco._on_body_entered(j)
				_chk(true, n + ": segundo disparo ignorado")
		escena.queue_free()
		await process_frame
	print("DIAG ECO HIJO FALLOS = ", fallos)
	quit()
