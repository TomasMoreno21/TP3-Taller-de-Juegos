extends SceneTree
## Diag Fase D ("El mundo te siente"): latido compartido, reacciones del HUD (curar, energía,
## parry, racha) y fundidos de pausa/derrota. Uso: --headless --script res://tests/diag_interfaz.gd

var fallos := 0

func _check(c: bool, m: String) -> void:
	print(("[PASS] " if c else "[FAIL] ") + m)
	if not c:
		fallos += 1

func _initialize() -> void:
	var nivel: Node = load("res://scenes/nivel1.tscn").instantiate()
	root.add_child(nivel)
	for n in nivel.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("dialog_trigger.gd"):
			n.queue_free()
	await process_frame
	await process_frame
	var p := get_first_node_in_group("player") as CharacterBody2D
	p.set("god_mode", true)
	var amb: Node = root.get_node_or_null("Ambiente")
	var hud: Node = get_first_node_in_group("hud")
	_check(amb != null and hud != null, "Ambiente y HUD presentes")
	# --- Latido compartido: solo con poca vida; el pulso queda en 0..1.
	await create_timer(0.6).timeout
	_check(float(amb.latido_severidad) < 0.05 and float(amb.latido) == 0.0, "vida llena: sin latido")
	p.set("health", 8)
	var maximo := 0.0
	for i in 90:
		await physics_frame
		maximo = maxf(maximo, float(amb.latido))
	_check(float(amb.latido_severidad) > 0.5, "vida casi en cero: latido severo (%.2f)" % float(amb.latido_severidad))
	_check(maximo > 0.3 and maximo <= 1.0001, "el pulso 'lub-dub' llega a un pico en 0..1 (%.2f)" % maximo)
	p.set("health", 100)
	await create_timer(1.0).timeout
	_check(float(amb.latido_severidad) < 0.05, "al curarse el latido se apaga (%.2f)" % float(amb.latido_severidad))
	# --- HUD: curar / energía / parry / racha no fallan y dejan el estado coherente.
	hud._on_health_changed(40, 100)
	hud._on_health_changed(80, 100)
	_check(int(hud.get("_hp_prev")) == 80, "el HUD recuerda la vida previa")
	hud._on_energia_changed(10.0)
	hud._on_energia_changed(60.0)
	_check(is_equal_approx(float(hud.get("_energia_prev")), 60.0), "el HUD recuerda la energía previa")
	hud._on_parry()
	_check(true, "parry en el HUD no falla")
	hud._on_racha_changed(2)
	hud._on_racha_changed(4)
	_check(hud.racha_box.visible, "la racha se muestra desde 2")
	hud._on_racha_changed(0)
	_check(not hud.racha_box.visible, "al perder la racha el indicador se oculta")
	# --- La señal de parry está conectada al HUD.
	_check(p.parry_exitoso.get_connections().size() > 0, "parry_exitoso conectado")
	# --- Pausa: abrir/cerrar deja el estado correcto (instantáneo en headless).
	var pausa: CanvasLayer = nivel.get_node_or_null("Pause")
	if pausa != null:
		pausa.abrir()
		_check(paused and (pausa.get_node("Panel") as Control).visible, "pausa abre: árbol pausado y panel visible")
		pausa.cerrar()
		_check(not paused and not (pausa.get_node("Panel") as Control).visible, "pausa cierra: árbol libre y panel oculto")
	else:
		print("   (no se encontró el nodo de pausa en root; se omite)")
	# --- Tips encolados no se saltean (bug del tween por frame).
	var dlg: Node = root.get_node_or_null("Dialogo")
	if dlg != null:
		dlg.mostrar_tip(["uno", "dos"])
		await create_timer(0.3).timeout
		_check(str(dlg.tip_texto.text) == "uno", "el primer tip se muestra (%s)" % str(dlg.tip_texto.text))
	print("DIAG INTERFAZ FALLOS = ", fallos)
	quit(1 if fallos > 0 else 0)
