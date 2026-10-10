extends SceneTree
## El daño debe caer cuando se ve el frame de impacto de la animación (no antes), y los golpes
## aéreos del Humano deben animarse. Humano: attack1 impacto en 2, attack2 en 1, attack_full en 2; Lobo: 1.

var fallos := 0

func _mundo() -> Node2D:
	var raiz := Node2D.new()
	root.add_child(raiz)
	var suelo := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(4000, 200)
	cs.shape = r
	suelo.add_child(cs)
	suelo.position = Vector2(0, 700)
	raiz.add_child(suelo)
	return raiz


func _caso(forma: int, accion: String, anim_esperada: String, impacto: int) -> void:
	var raiz := _mundo()
	var p: CharacterBody2D = load("res://scenes/player.tscn").instantiate()
	p.position = Vector2(0, 400)
	raiz.add_child(p)
	p.set("current_form", forma)
	p.call("_apply_form")
	p.set("energia", 100.0)
	var d: StaticBody2D = load("res://tests/dummy.gd").new()
	var dcs := CollisionShape2D.new()
	var dr := RectangleShape2D.new()
	dr.size = Vector2(60, 200)
	dcs.shape = dr
	d.add_child(dcs)
	d.position = Vector2(110, 550)
	raiz.add_child(d)
	for i in 40:
		await physics_frame
	var vis: AnimatedSprite2D = p.get("visual")
	Input.action_press(accion)
	var frame_hit := -1
	var anim_hit := ""
	var t := 0.0
	var t_hit := -1.0
	for i in 90:
		await physics_frame
		if i == 1:
			Input.action_release(accion)
		p.set("energia", 100.0)
		t += 1.0 / 60.0
		if t_hit < 0.0 and d.hits > 0:
			t_hit = t
			frame_hit = vis.frame
			anim_hit = vis.animation
	var ok := anim_hit == anim_esperada and frame_hit >= impacto and frame_hit <= impacto + 1
	var msg := "forma=%d %-7s daño a %.2fs en %s frame %d (impacto %d)" % [forma, accion, t_hit, anim_hit, frame_hit, impacto]
	if ok:
		print("ok   ", msg)
	else:
		fallos += 1
		print("FAIL ", msg)
	raiz.queue_free()
	await physics_frame


func _aereo(accion: String, anim_esperada: String) -> void:
	var raiz := _mundo()
	var p: CharacterBody2D = load("res://scenes/player.tscn").instantiate()
	p.position = Vector2(0, 100)
	raiz.add_child(p)
	for i in 5:
		await physics_frame
	var vis: AnimatedSprite2D = p.get("visual")
	var en_aire := not p.is_on_floor()
	Input.action_press(accion)
	await physics_frame
	await physics_frame
	await physics_frame
	Input.action_release(accion)
	var ok := en_aire and vis.animation == anim_esperada
	var msg := "aéreo %-7s anim=%s (esperada %s) en_aire=%s" % [accion, vis.animation, anim_esperada, en_aire]
	if ok:
		print("ok   ", msg)
	else:
		fallos += 1
		print("FAIL ", msg)
	raiz.queue_free()
	await physics_frame



## Recibir daño en pleno avance del golpe: el retroceso no debe ser pisado por el avance.
func _dano_en_golpe() -> void:
	var raiz := _mundo()
	var p: CharacterBody2D = load("res://scenes/player.tscn").instantiate()
	p.position = Vector2(0, 400)
	raiz.add_child(p)
	p.set("current_form", 1)   # Lobo: tiene avance al golpear
	p.call("_apply_form")
	for i in 40:
		await physics_frame
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	await physics_frame
	var avance: float = p.get("_lunge_t")
	p.call("take_damage", 5, 420.0, -1)
	var vmin := 0.0
	var vmax := -1e9
	for i in 4:
		await physics_frame
		vmin = minf(vmin, p.velocity.x)
		vmax = maxf(vmax, p.velocity.x)
	var ok := avance > 0.0 and vmax < 0.0
	var msg := "daño en pleno avance (avance %.2fs): velocidad.x entre %.0f y %.0f (debe quedar siempre negativa)" % [avance, vmin, vmax]
	if ok:
		print("ok   ", msg)
	else:
		fallos += 1
		print("FAIL ", msg)
	raiz.queue_free()
	await physics_frame

func _initialize() -> void:
	await _caso(0, "attack", "attack1", 2)
	await _caso(0, "heavy", "attack2", 1)
	await _caso(0, "special", "attack_full", 2)
	await _caso(1, "attack", "lobo_attack", 1)
	await _caso(1, "heavy", "lobo_attack", 1)
	await _aereo("attack", "attack1")
	await _aereo("heavy", "attack2")
	await _dano_en_golpe()
	print("DIAG SYNC GOLPES FALLOS = ", fallos)
	quit()
