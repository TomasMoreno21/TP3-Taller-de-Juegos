extends SceneTree
## Evento del cultista arrepentido (nivel 3): jugador congelado, aparece, habla con el globo anclado a él,
## desaparece, devuelve el control y no vuelve.
## Uso: godot --headless --script tests/diag_cultista.gd

var fallos := 0

func _chk(nombre: String, ok: bool) -> void:
	print("[%s] %s" % ["OK" if ok else "FAIL", nombre])
	if not ok:
		fallos += 1


func _init() -> void:
	await process_frame
	var prog := root.get_node("Progresion")
	var dialogo := root.get_node("Dialogo")
	prog.reset()
	var j := CharacterBody2D.new()
	j.add_to_group("player")
	var gs := GDScript.new()
	gs.source_code = "extends CharacterBody2D\nvar cinematica_activa := false\nvar cinematica_dir := 0.0\n"
	gs.reload()
	j.set_script(gs)
	root.add_child(j)
	var c: Area2D = load("res://scenes/cultista_arrepentido.tscn").instantiate()
	c.caminata_seg = 0.6
	c.tiempo_camara = 0.1
	c.pausa_antes = 0.1
	c.tiempo_aparicion = 0.3
	c.pausa_antes_de_hablar = 0.1
	c.pausa_final = 0.1
	c.tiempo_desaparicion = 0.3
	root.add_child(c)
	c.position = Vector2(500, 0)
	await physics_frame
	_chk("invisible al inicio", c.get_node("Animado").modulate.a == 0.0)
	_chk("carga 3 líneas", c._lineas.size() == 3)
	c._on_body_entered(j)
	await create_timer(0.1).timeout
	_chk("jugador congelado y sin daño", j.get("cinematica_activa") == true)
	_chk("camina hacia el cultista", j.get("cinematica_dir") > 0.0)
	await create_timer(0.7).timeout
	_chk("frena tras caminar", j.get("cinematica_dir") == 0.0)
	await create_timer(0.6).timeout
	_chk("aparece", c.get_node("Animado").modulate.a > 0.99)
	_chk("globo anclado al cultista, sin rótulo", dialogo.ancla_hablante == c and dialogo.nombre_ancla == "")
	_chk("marcado como visto", prog.dialogo_visto("n3_cultista"))
	dialogo.dialogo_terminado.emit()
	await create_timer(1.1).timeout
	_chk("jugador recupera el control antes de la charla final", j.get("cinematica_activa") == false)
	_chk("charla final encolada en juego", dialogo.hay_narrativa())
	await create_timer(1.2).timeout
	_chk("desaparece y se libera", not is_instance_valid(c) or c.is_queued_for_deletion())
	_chk("ancla liberada", dialogo.ancla_hablante == null)
	print("DIAG_CULTISTA: FALLOS = %d" % fallos)
	quit()
