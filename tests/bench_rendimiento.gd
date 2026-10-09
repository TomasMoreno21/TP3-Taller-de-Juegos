extends SceneTree
## Bench de rendimiento de un nivel (con ventana, para medir GPU). Uso:
## godot --path . --windowed --resolution 1920x1080 --script res://tests/bench_rendimiento.gd -- res://scenes/nivel1.tscn [segundos]
## Imprime una línea "BENCH": carga del .tscn, add_child (_ready), 1er frame, frame promedio/máximo,
## frames lentos (>34 ms), draw calls, GPU, física, nodos y memoria.

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var ruta: String = a[0]
	var segundos := float(a[1]) if a.size() > 1 else 8.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	await process_frame

	var t0 := Time.get_ticks_usec()
	var escena := load(ruta) as PackedScene
	var t1 := Time.get_ticks_usec()
	var nivel := escena.instantiate()
	root.add_child(nivel)
	var t2 := Time.get_ticks_usec()
	await process_frame
	var t3 := Time.get_ticks_usec()

	var frames := 0
	var lentos := 0
	var maximo := 0.0
	var gpu := 0.0
	var draw_calls := 0.0
	var fisica := 0.0
	var inicio := Time.get_ticks_usec()
	var previo := inicio
	while Time.get_ticks_usec() - inicio < int(segundos * 1000000.0):
		await process_frame
		var ahora := Time.get_ticks_usec()
		var dt := (ahora - previo) / 1000.0
		previo = ahora
		frames += 1
		maximo = maxf(maximo, dt)
		if dt > 34.0:
			lentos += 1
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		fisica += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var prom := (Time.get_ticks_usec() - inicio) / 1000.0 / frames
	print("BENCH %s | carga=%dms ready=%dms frame1=%dms | prom=%.2fms (%.0f fps) max=%.1fms lentos=%d/%d | dc=%.0f gpu=%.2fms fis=%.2fms | nodos=%d mem=%.0fMB" % [
		ruta.get_file(), (t1 - t0) / 1000, (t2 - t1) / 1000, (t3 - t2) / 1000,
		prom, 1000.0 / prom, maximo, lentos, frames,
		draw_calls / frames, gpu / frames, fisica / frames,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / 1e6])
	quit()
