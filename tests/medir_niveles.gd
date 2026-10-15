extends SceneTree
## Mide un nivel: celdas del TileMap (con/sin colisión, capa Profundo), nodos por tipo, carga y RAM.
## Uso: godot --headless --path . --script tests/medir_niveles.gd -- res://scenes/nivel1.tscn

func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var ruta := args[0] if args.size() > 0 else "res://scenes/nivel1.tscn"
	var t0 := Time.get_ticks_msec()
	var ps := load(ruta) as PackedScene
	var t1 := Time.get_ticks_msec()
	var nivel := ps.instantiate()
	var t2 := Time.get_ticks_msec()
	root.add_child(nivel)
	var t3 := Time.get_ticks_msec()
	await physics_frame
	await physics_frame
	print("== ", ruta)
	print("carga(parseo)=%d ms  instanciar=%d ms  ready=%d ms  RAM=%d MB" % [t1 - t0, t2 - t1, t3 - t2, int(OS.get_static_memory_usage() / 1048576.0)])
	var tipos := {}
	var total := 0
	for n in nivel.find_children("*", "", true, false):
		total += 1
		tipos[n.get_class()] = int(tipos.get(n.get_class(), 0)) + 1
	var orden := tipos.keys()
	orden.sort_custom(func(a, b): return tipos[a] > tipos[b])
	var top := []
	for k in orden.slice(0, 10):
		top.append("%s=%d" % [k, tipos[k]])
	print("nodos=%d  top: %s" % [total, ", ".join(top)])
	for capa in nivel.find_children("*", "TileMapLayer", true, false):
		var c: TileMapLayer = capa
		var usadas := c.get_used_cells()
		var con := 0
		var sin := 0
		for v in usadas:
			if c.get_cell_alternative_tile(v) == 1:
				sin += 1
			else:
				con += 1
		print("TileMapLayer %s: celdas=%d (alt0/colision=%d, alt1/enterradas=%d) visible=%s" % [c.get_path(), usadas.size(), con, sin, c.visible])
	var parts := 0
	var luces := 0
	var anim := 0
	for n in nivel.find_children("*", "", true, false):
		if n is CPUParticles2D or n is GPUParticles2D:
			parts += 1
		elif n is PointLight2D:
			luces += 1
		elif n is AnimatedSprite2D:
			anim += 1
	print("particulas=%d luces=%d animados=%d" % [parts, luces, anim])
	quit()
