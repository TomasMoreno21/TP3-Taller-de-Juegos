extends SceneTree
## Herramienta manual (necesita ventana, sin --headless): en qué momento aparece el frame del tajo del
## cultista respecto del instante del daño (fin del windup). attack1 impacto en 3, attack2 en 2.
## godot --path . --resolution 1920x1080 --script res://tests/medir_sync_enemigo.gd

func _initialize() -> void:
	var suelo := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(4000, 200)
	cs.shape = r
	suelo.add_child(cs)
	suelo.position = Vector2(960, 800)
	root.add_child(suelo)
	for tipo in ["attack1", "attack2"]:
		var e: CharacterBody2D = load("res://scenes/enemy.tscn").instantiate()
		e.set("tipo", "cultista")
		e.position = Vector2(960, 600)
		root.add_child(e)
		for i in 40:
			await physics_frame
		var t_imp: float = e.get("enemy_data").windup_tiempo
		e.call("_reproducir_animacion_ataque", tipo, t_imp)
		var anim: AnimatedSprite2D = e.get("animated")
		var t := 0.0
		var t_frame := {}
		for i in 80:
			await physics_frame
			t += 1.0 / 60.0
			if not t_frame.has(anim.frame) and anim.animation == tipo:
				t_frame[anim.frame] = t
		var txt := ""
		for k in t_frame.keys():
			txt += " f%d@%.2fs" % [k, t_frame[k]]
		print("%s: daño previsto a %.2fs -> frames:%s" % [tipo, t_imp, txt])
		e.queue_free()
		await physics_frame
	quit()
