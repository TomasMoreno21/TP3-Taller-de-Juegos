extends SceneTree
## Medición (no test): por forma y ataque, compara la punta VISIBLE del sprite (píxeles opacos del frame
## de impacto, en px del mundo) con el fin de la hitbox del golpe. Todo relativo al centro del jugador,
## mirando a la derecha. Uso: godot --headless --path . --script res://tests/medir_alcance_anim.gd

var _cache := {}


func _mundo() -> Node2D:
	var raiz := Node2D.new()
	root.add_child(raiz)
	var suelo := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(6000, 200)
	cs.shape = r
	suelo.add_child(cs)
	suelo.position = Vector2(0, 700)
	raiz.add_child(suelo)
	return raiz


## [min_x, max_x] de los píxeles opacos del frame actual, en coordenadas globales.
func _bbox_visible(vis: AnimatedSprite2D) -> Vector2:
	var tex := vis.sprite_frames.get_frame_texture(vis.animation, vis.frame)
	if tex == null:
		return Vector2.ZERO
	var img: Image
	if _cache.has(tex):
		img = _cache[tex]
	else:
		img = tex.get_image()
		if img != null and img.is_compressed():
			img.decompress()
		_cache[tex] = img
	if img == null:
		return Vector2.ZERO
	var w := img.get_width()
	var h := img.get_height()
	var x0 := w
	var x1 := -1
	for y in range(0, h, 2):
		for x in w:
			if img.get_pixel(x, y).a > 0.15:
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
	if x1 < 0:
		return Vector2.ZERO
	var base := vis.offset - (Vector2(w, h) * 0.5 if vis.centered else Vector2.ZERO)
	var lx0 := float(x0)
	var lx1 := float(x1 + 1)
	if vis.flip_h:
		lx0 = w - float(x1 + 1)
		lx1 = w - float(x0)
	var a := vis.global_transform * (base + Vector2(lx0, h * 0.5))
	var b := vis.global_transform * (base + Vector2(lx1, h * 0.5))
	return Vector2(minf(a.x, b.x), maxf(a.x, b.x))


func _caso(forma: int, accion: String) -> void:
	var raiz := _mundo()
	var p: CharacterBody2D = load("res://scenes/player.tscn").instantiate()
	p.position = Vector2(0, 400)
	raiz.add_child(p)
	p.set("current_form", forma)
	p.call("_apply_form")
	p.set("energia", 100.0)
	for i in 40:
		await physics_frame
	var vis: AnimatedSprite2D = p.get("visual")
	var data = p.get("forms")[forma]
	var medio: float = (p.get("collision_shape").shape as RectangleShape2D).size.x * 0.5
	var hb: CollisionShape2D = p.get("attack_hitbox")
	Input.action_press(accion)
	var punta_imp := -1.0
	var punta_max := -1.0
	var fin_hb := -1.0
	var anim := ""
	var frame_imp := -1
	for i in 60:
		await physics_frame
		if i == 1:
			Input.action_release(accion)
		p.set("energia", 100.0)
		if hb.disabled:
			continue
		var cx := p.global_position.x
		fin_hb = (hb.global_transform * hb.shape.get_rect()).end.x - cx   # incluye la escala del nodo
		var bb := _bbox_visible(vis)
		punta_max = maxf(punta_max, bb.y - cx)
		var imp: int = int(data.anim_impacto.get(vis.animation, -1))
		if imp >= 0 and vis.frame == imp and punta_imp < 0.0:
			punta_imp = bb.y - cx
			anim = vis.animation
			frame_imp = imp
		elif anim == "":
			anim = vis.animation
	print("forma=%d %-7s anim=%-12s cuerpo=%4.0f  punta_impacto=%5.0f  punta_max=%5.0f  fin_hitbox=%5.0f  (hitbox-punta=%+.0f)" % [
		forma, accion, anim, medio, punta_imp, punta_max, fin_hb, fin_hb - (punta_imp if punta_imp > 0.0 else punta_max)])
	raiz.queue_free()
	await physics_frame


func _initialize() -> void:
	await process_frame
	var prog := root.get_node_or_null("Progresion")
	if prog != null:
		prog.set("formas_forzadas", [0, 1, 2, 3])
	for f in 4:
		for acc in ["attack", "heavy", "special"]:
			if f == 3 and acc == "special":
				continue   # el especial del Murciélago es un proyectil
			await _caso(f, acc)
	quit()
