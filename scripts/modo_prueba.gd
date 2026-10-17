extends Node
## Modo prueba (autoload "ModoPrueba") para las pruebas públicas: salto a cualquier nivel con el equipo que
## tendrías al llegar, ubicación y mapa de lo ya probado, teletransporte entre checkpoints, práctica
## (vida y energía infinitas) y "Nuevo tester" que deja el juego limpio para la persona siguiente.
## Cada sesión se anota en `archivo_registro` (tiempo por nivel, muertes) para ver qué probó cada tester.
## Para la versión final: `habilitado = false` en scenes/modo_prueba.tscn oculta todo (menú, pausa y etiqueta).

signal practica_cambiada(activa: bool)

const ESCENA_MENU := "res://scenes/main_menu.tscn"
const NOMBRES_FORMAS: Array[String] = ["Humano", "Lobo", "Oso", "Murciélago"]

@export var habilitado := true
@export var version_texto := "PRUEBA PÚBLICA"
@export var nombres: Array[String] = ["NIVEL 1 · EL BOSQUE", "NIVEL 2 · LAS CUEVAS", "NIVEL 3 · EL LATIDO", "JEFE · EL SANTUARIO"]
@export_file("*.tscn") var rutas: Array[String] = ["res://scenes/nivel1.tscn", "res://scenes/nivel2.tscn", "res://scenes/nivel3.tscn", "res://scenes/nivel_jefe.tscn"]
## Fragmentos acumulados con los que se llega a cada nivel (orbes de los niveles anteriores; ver Progresion.FRAGMENTOS_NIVEL).
@export var fragmentos_inicio: Array[int] = [0, 11, 28, 49]
## Formas que ya habrían desbloqueado los tótems anteriores (índices de Form: 1 Lobo, 2 Oso, 3 Murciélago).
@export var formas_inicio: Array = [[], [1], [1, 3], [1, 2, 3]]
@export var archivo_registro := "user://pruebas_log.txt"
@export var texto_practica := "MODO PRÁCTICA"
@export var color_practica := Color(0.95, 0.78, 0.35, 0.85)

var practica := false
var visitados: Dictionary = {}     ## índice de nivel → true (secciones ya probadas por este tester)
var segundos: Dictionary = {}      ## índice de nivel → segundos jugados
var muertes_total := 0
var n_tester := 1

var _uso_practica := false
var _muertes_prev := 0
var _escena_id := 0
var _acum := 0.0
var _etiqueta: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var capa := CanvasLayer.new()
	capa.layer = 80
	add_child(capa)
	_etiqueta = Label.new()
	_etiqueta.text = texto_practica
	_etiqueta.add_theme_font_size_override("font_size", 18)
	_etiqueta.add_theme_color_override("font_color", color_practica)
	_etiqueta.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_etiqueta.add_theme_constant_override("outline_size", 6)
	_etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_etiqueta.anchor_left = 1.0
	_etiqueta.anchor_right = 1.0
	_etiqueta.anchor_top = 1.0
	_etiqueta.anchor_bottom = 1.0
	_etiqueta.offset_left = -320.0
	_etiqueta.offset_right = -20.0
	_etiqueta.offset_top = -44.0
	_etiqueta.offset_bottom = -16.0
	_etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_etiqueta.visible = false
	capa.add_child(_etiqueta)


func _exit_tree() -> void:
	registrar_sesion("cierre del juego")


func _process(delta: float) -> void:
	if not habilitado:
		return
	var esc := get_tree().current_scene
	if esc == null:
		return
	if esc.get_instance_id() != _escena_id:
		_escena_id = esc.get_instance_id()
		_al_cambiar_escena(esc)
	var idx := indice_de_escena(esc)
	if idx >= 0 and not get_tree().paused:
		segundos[idx] = float(segundos.get(idx, 0.0)) + delta
	_acum += delta
	if _acum >= 0.5:
		_acum = 0.0
		_contar_muertes()


func indice_de_escena(esc: Node = null) -> int:
	if esc == null:
		esc = get_tree().current_scene
	if esc == null:
		return -1
	return rutas.find(esc.scene_file_path)


func nombre_nivel(i: int) -> String:
	return nombres[i] if i >= 0 and i < nombres.size() else ""


func _al_cambiar_escena(esc: Node) -> void:
	var idx := indice_de_escena(esc)
	if idx >= 0:
		visitados[idx] = true
	_etiqueta.visible = practica and idx >= 0
	_aplicar_practica_diferido()


func _aplicar_practica_diferido() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_aplicar_practica()


func _aplicar_practica() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	if practica:
		p.god_mode = true
		p.energia_infinita = true
	elif _uso_practica:
		p.god_mode = false
		p.energia_infinita = false


func fijar_practica(activa: bool) -> void:
	practica = activa
	if activa:
		_uso_practica = true
	_etiqueta.visible = activa and indice_de_escena() >= 0
	_aplicar_practica()
	practica_cambiada.emit(activa)


func _contar_muertes() -> void:
	var prog := get_node_or_null("/root/Progresion")
	if prog == null:
		return
	var m := int(prog.muertes)
	if m > _muertes_prev:
		muertes_total += m - _muertes_prev
	_muertes_prev = m


# ---------------------------------------------------------------- niveles

## Salta a un nivel con el equipo que tendrías al llegar ahí (el 0 es el inicio limpio del juego).
func ir_a_nivel(i: int) -> void:
	if i < 0 or i >= rutas.size():
		return
	var prog := get_node("/root/Progresion")
	if i == 0:
		prog.reset()
	else:
		prog.saltar_a_punto(fragmentos_inicio[i], formas_inicio[i])
	_muertes_prev = 0
	TransicionPantalla.de(get_tree()).cambiar_escena(rutas[i])


## Desbloquea todas las formas y todos los combos (para probar el equipo completo sin recorrer los tótems).
func desbloquear_todo() -> void:
	var prog := get_node("/root/Progresion")
	var p := get_tree().get_first_node_in_group("player")
	for f in 4:
		prog.desbloquear_forma(f)
		var total := 1
		if p != null and p.forms.size() > f:
			total = maxi(p.forms[f].combos.size(), 1)
		prog.combos_desbloqueados[f] = total


## Texto de las formas que el jugador tiene ahora.
func formas_texto() -> String:
	var prog := get_node("/root/Progresion")
	var lista: Array[String] = []
	for f in NOMBRES_FORMAS.size():
		if prog.forma_desbloqueada(f):
			lista.append(NOMBRES_FORMAS[f])
	return ", ".join(lista)


# ---------------------------------------------------------------- checkpoints

## Checkpoints del nivel actual en el orden de la lista del modo prueba: primero los que tienen `orden_prueba`
## (Inspector del checkpoint), después una cadena por cercanía que arranca en el "Inicio"
## (los niveles bajan y vuelven: ordenar por X no sirve). Es aproximado: `orden_prueba` lo corrige.
func checkpoints() -> Array[Node2D]:
	var fijos: Array[Node2D] = []
	var libres: Array[Node2D] = []
	for n in get_tree().get_nodes_in_group("checkpoint"):
		if not n is Node2D:
			continue
		if int(n.get("orden_prueba")) > 0:
			fijos.append(n)
		else:
			libres.append(n)
	fijos.sort_custom(func(a: Node2D, b: Node2D) -> bool: return int(a.get("orden_prueba")) < int(b.get("orden_prueba")))
	# La cadena arranca en el checkpoint "Inicio" (o el primero de la escena) y sigue siempre al más cercano sin usar.
	var cadena: Array[Node2D] = []
	var ref := Vector2.ZERO
	var primero := true
	while not libres.is_empty():
		var mejor := 0
		if primero:
			for i in libres.size():
				if String(libres[i].name).containsn("inicio") or (String(libres[i].name) == "Checkpoint" and not String(libres[mejor].name).containsn("inicio")):
					mejor = i
			primero = false
		else:
			for i in libres.size():
				if libres[i].global_position.distance_squared_to(ref) < libres[mejor].global_position.distance_squared_to(ref):
					mejor = i
		ref = libres[mejor].global_position
		cadena.append(libres[mejor])
		libres.remove_at(mejor)
	return fijos + cadena


## Nombre legible del checkpoint: `nombre_prueba` o el del nodo sin "Checkpoint" y con espacios ("CheckpointPostGuardian" → "Post Guardian").
func nombre_checkpoint(cp: Node) -> String:
	var propio := str(cp.get("nombre_prueba"))
	if not propio.is_empty():
		return propio
	var n := String(cp.name)
	if n.begins_with("Checkpoint"):
		n = n.substr(10)
	var re := RegEx.new()
	re.compile("(?<=[a-z])(?=[A-Z])")
	n = re.sub(n, " ", true).strip_edges()
	if n.is_empty():
		return "Primero"
	return "Punto " + n if n.unicode_at(0) >= 48 and n.unicode_at(0) <= 57 else n


## Índice en `checkpoints()` del punto donde reaparecerías (el último activado), o -1.
func checkpoint_actual_idx() -> int:
	var p := get_tree().get_first_node_in_group("player")
	if p == null or not p.tiene_checkpoint():
		return -1
	var cps := checkpoints()
	for i in cps.size():
		if cps[i].global_position.distance_to(p._spawn_position - Vector2(cps[i].get("offset_respawn"))) < 4.0:
			return i
	return -1


## Vector2i(activados, total) de los checkpoints del nivel.
func checkpoints_progreso() -> Vector2i:
	var cps := checkpoints()
	var act := 0
	for c in cps:
		if c.esta_activado():
			act += 1
	return Vector2i(act, cps.size())


func teletransportar_a(cp: Node2D, cerrar_pausa: Callable = Callable()) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null or not is_instance_valid(cp):
		return
	var pos: Vector2 = cp.global_position + cp.get("offset_respawn")
	TransicionPantalla.de(get_tree()).fundido(func() -> void:
		_cerrar_pausa(cerrar_pausa)
		p.actualizar_checkpoint(pos)
		p.reaparecer_en_checkpoint()
		_restaurar_camara_y_arenas(p)
		if cp.has_method("_on_body_entered"):
			cp._on_body_entered(p))


## Vuelve al último checkpoint activado (o recarga el nivel si no tocó ninguno).
func volver_a_checkpoint(cerrar_pausa: Callable = Callable()) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("tiene_checkpoint") and p.tiene_checkpoint():
		TransicionPantalla.de(get_tree()).fundido(func() -> void:
			_cerrar_pausa(cerrar_pausa)
			p.reaparecer_en_checkpoint()
			_restaurar_camara_y_arenas(p))
	else:
		TransicionPantalla.de(get_tree()).recargar()


func _cerrar_pausa(cerrar_pausa: Callable) -> void:
	if cerrar_pausa.is_valid():
		cerrar_pausa.call()
	get_tree().paused = false
	Input.action_release("jump")


## Igual que al reaparecer tras morir: cámara normal y arenas de combate reiniciadas.
func _restaurar_camara_y_arenas(p: Node) -> void:
	var cam := p.get_viewport().get_camera_2d()
	if cam != null and cam.has_method("modo_normal"):
		cam.modo_normal(true)
	for e in get_tree().get_nodes_in_group("encounter"):
		if e.has_method("reiniciar"):
			e.reiniciar()


# ---------------------------------------------------------------- tester

## Deja el juego como recién instalado para la persona siguiente: anota la sesión y borra progreso,
## secciones probadas, tiempos y práctica.
func nuevo_tester() -> void:
	registrar_sesion("nuevo tester")
	get_node("/root/Progresion").reset()
	visitados.clear()
	segundos.clear()
	muertes_total = 0
	_muertes_prev = 0
	_uso_practica = false
	fijar_practica(false)
	n_tester += 1


func volver_al_menu() -> void:
	TransicionPantalla.de(get_tree()).cambiar_escena(ESCENA_MENU)


func registrar_sesion(motivo: String) -> void:
	if DisplayServer.get_name() == "headless" or not habilitado:
		return
	var total := 0.0
	for k in segundos:
		total += float(segundos[k])
	if total < 5.0:
		return
	var partes: Array[String] = []
	for i in rutas.size():
		if visitados.has(i):
			partes.append("%s %s" % [nombre_nivel(i).get_slice(" · ", 0), tiempo_texto(float(segundos.get(i, 0.0)))])
	var f := FileAccess.open(archivo_registro, FileAccess.READ_WRITE if FileAccess.file_exists(archivo_registro) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line("[%s] tester %d · %s · muertes %d · práctica %s · %s" % [
		Time.get_datetime_string_from_system(), n_tester, " | ".join(partes), muertes_total,
		"sí" if _uso_practica else "no", motivo])
	f.close()


static func tiempo_texto(seg: float) -> String:
	var s := int(seg)
	return "%d:%02d" % [s / 60, s % 60]
