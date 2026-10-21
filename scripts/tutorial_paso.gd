extends Area2D

## Paso de tutorial colocable en el editor: lo agrega a la lista de tareas y espera a que el jugador
## haga la acción pedida (como los tutoriales de Alien Force). Al cumplirlo lo tacha y pasa al
## `paso_siguiente`. El texto sale de res://data/dialogos.json por `paso_id` ("lineas"[0], "hablante",
## y opcionales "pista" y "cierre"); `texto` es el respaldo.
## Se adapta al jugador: si ya hizo la acción (o la hace antes de su turno) se tacha sola; si se
## traba `segundos_pista` segundos, el Amuleto da una pista. Respeta el nivel de ayuda elegido.
## Se marca como visto en Progresion: no se repite tras morir ni al reiniciar el nivel.

enum Accion { MOVER, SALTAR, GOLPE_LIGERO, GOLPE_FUERTE, BLOQUEAR, PARRY, TRANSFORMAR, SALTO_LARGO, SALTO_AIRE, ESPECIAL }

const CLAVES := ["mover", "saltar", "golpe_ligero", "golpe_fuerte", "bloquear", "parry", "transformar", "salto_largo", "salto_aire", "especial"]

@export var paso_id: String = ""
@export_multiline var texto: String = ""
@export var hablante: String = "Amuleto"
@export var accion: Accion = Accion.MOVER
@export var paso_siguiente: NodePath
@export var segundos_pista := 20.0
@export var segundos_salto_largo := 0.3   ## SALTO_LARGO: tiempo sosteniendo el salto en el aire para cumplirlo
@export var forma_requerida := -1   ## SALTO_AIRE / ESPECIAL: solo cuenta con esta forma (-1 = cualquiera; también TRANSFORMAR; 1 Lobo, 2 Oso, 3 Murciélago)
@export var ignorar_hecho := false   ## se enseña aunque el jugador ya haya hecho la acción (p. ej. la transformación automática del tótem)
@export_group("Tecla en el mundo")
@export var mostrar_tecla := true                 ## cartel con la tecla de la acción sobre el jugador (no frena nada; se va al cumplir el paso)
@export var tecla_margen_cabeza := 60.0   ## px sobre la cabeza del personaje; se adapta al alto de cada forma
@export var tecla_etiqueta_tam := 16
@export var segundos_bloqueo_tips := 20.0   ## mientras el paso está activo, el Amuleto no suelta otros consejos (hasta este tiempo)
@export var tecla_tam_fuente := 28
@export var tecla_color_fondo := Color(0.08, 0.08, 0.08, 0.7)
@export var tecla_color_borde := Color(0.72, 0.72, 0.72, 0.9)
@export var tecla_color_texto := Color(0.93, 0.93, 0.93)

var _activo := false
var _jugador: Node = null
var _pista := ""
var _cierre := ""
var _espera := 0.0
var _pista_dada := false
var _cartel: Node2D
var _capa_cartel: CanvasLayer   # sobre la capa de noche (5) y bajo el HUD (10): si no, la oscuridad lo tapa
var _salto_t := 0.0
var _etiqueta := ""
var _bloquea := false
var _t_bloqueo := 0.0


func _ready() -> void:
	_cargar_texto()
	collision_layer = 0
	collision_mask = 4
	monitoring = true
	body_entered.connect(_on_body_entered)
	var dlg := get_node_or_null("/root/Dialogo")
	if dlg != null:
		dlg.accion_hecha.connect(_on_accion_hecha)


func _cargar_texto() -> void:
	if paso_id.is_empty():
		return
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogos.json"))
	if datos is Dictionary and datos.get(paso_id) is Dictionary:
		var entrada: Dictionary = datos[paso_id]
		var lineas: Array = entrada.get("lineas", [])
		if not lineas.is_empty():
			texto = str(lineas[0])
		hablante = str(entrada.get("hablante", hablante))
		_pista = str(entrada.get("pista", ""))
		_cierre = str(entrada.get("cierre", ""))
		_etiqueta = str(entrada.get("etiqueta", ""))


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		activar(body)


func _visto() -> bool:
	var prog := get_node_or_null("/root/Progresion")
	return prog != null and not paso_id.is_empty() and prog.dialogo_visto(paso_id)


func _clave() -> String:
	return CLAVES[accion]


func _ya_hecho(dlg: Node) -> bool:
	return not ignorar_hecho and dlg.ya_hizo(_clave())


## Activa el paso (por entrar a la zona o por encadenado): aparece en la lista junto con los
## que siguen en la cadena. Lo ignora si ya se hizo.
func activar(jugador: Node = null) -> void:
	if _activo or texto.is_empty():
		return
	var dlg := get_node_or_null("/root/Dialogo")
	if dlg == null or dlg.nivel_ayuda == 0:
		return
	if dlg.hay_narrativa() and not _visto():
		_activo = true   # reserva el paso mientras espera a que termine la charla
		while dlg.hay_narrativa():
			await dlg.dialogo_terminado
		_activo = false
	if _visto() or _ya_hecho(dlg):
		_marcar_visto()
		_pasar_al_siguiente(jugador)   # ya aprendido: no se muestra, sigue la cadena
		return
	_jugador = jugador if jugador != null else get_tree().get_first_node_in_group("player")
	if _jugador == null:
		return
	if accion == Accion.TRANSFORMAR and forma_requerida >= 0 and _forma_ok():
		_marcar_visto()   # ya tiene la forma pedida: no hace falta enseñar cómo transformarse
		_pasar_al_siguiente(_jugador)
		return
	_activo = true
	_bloquear_tips(dlg)
	_espera = 0.0
	_pista_dada = false
	_conectar()
	_registrar_cadena(dlg)
	dlg.lista_marcar_actual(paso_id)
	_mostrar_cartel(dlg)


## Para encadenar tras una cinemática (señal `desbloqueada`): espera a que el jugador recupere el control.
func activar_diferido(seg: float = 0.5) -> void:
	await get_tree().create_timer(seg, false).timeout
	var j := get_tree().get_first_node_in_group("player")
	while j != null and j.get("cinematica_activa") == true:
		await get_tree().process_frame
	activar(j)


## Cartel con la tecla de la acción, pulsando sobre el jugador: se ve de reojo sin leer nada.
func _mostrar_cartel(dlg: Node) -> void:
	_quitar_cartel()
	if not mostrar_tecla or DisplayServer.get_name() == "headless" or _jugador == null:
		return
	var re := RegEx.create_from_string("\\{(\\w+)\\}")
	var m := re.search(texto)
	if m == null:
		return
	var tecla: String = dlg._tokens(m.get_string(0))
	if tecla.is_empty() or tecla == m.get_string(0):
		return
	_capa_cartel = CanvasLayer.new()
	_capa_cartel.layer = 6
	_cartel = Node2D.new()
	var l := Label.new()
	l.text = tecla.to_upper()
	l.add_theme_font_size_override("font_size", tecla_tam_fuente)
	l.add_theme_color_override("font_color", tecla_color_texto)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = tecla_color_fondo
	estilo.border_color = tecla_color_borde
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	estilo.content_margin_left = 16
	estilo.content_margin_right = 16
	estilo.content_margin_top = 5
	estilo.content_margin_bottom = 5
	l.add_theme_stylebox_override("normal", estilo)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cartel.add_child(l)
	_capa_cartel.add_child(_cartel)
	add_child(_capa_cartel)
	_seguir_jugador()
	l.reset_size()
	l.position = -l.size * 0.5
	if not _etiqueta.is_empty():   # qué hace la tecla, bajo el cartel: no hace falta leer la tarea
		var e := Label.new()
		e.text = _etiqueta.to_upper()
		e.add_theme_font_size_override("font_size", tecla_etiqueta_tam)
		e.add_theme_color_override("font_color", tecla_color_borde)
		e.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		e.add_theme_constant_override("outline_size", 5)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_cartel.add_child(e)
		e.reset_size()
		e.position = Vector2(-e.size.x * 0.5, l.size.y * 0.5 + 3.0)
	_cartel.scale = Vector2(0.9, 0.9)
	var tw := _cartel.create_tween().set_loops()
	tw.tween_property(_cartel, "scale", Vector2(1.04, 1.04), 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_cartel, "scale", Vector2(0.97, 0.97), 0.8).set_trans(Tween.TRANS_SINE)


## El cartel vive en pantalla (capa propia) y sigue al jugador con la transformación de la cámara.
func _seguir_jugador() -> void:
	if is_instance_valid(_cartel) and is_instance_valid(_jugador):
		var col: CollisionShape2D = _jugador.collision_shape
		var cabeza := col.global_position.y - (col.shape as RectangleShape2D).size.y * 0.5
		_cartel.position = get_viewport().get_canvas_transform() * Vector2(_centro_x_sprite(), cabeza - tecla_margen_cabeza)


## x del centro dibujado del sprite (el cuerpo no siempre está centrado en el origen del jugador).
func _centro_x_sprite() -> float:
	var vis = _jugador.get("visual")
	if vis is Node2D:
		return vis.to_global(vis.get("offset") if vis.get("offset") != null else Vector2.ZERO).x
	return _jugador.global_position.x


## Al cumplir el paso, la tecla se vuelve un tilde que se desvanece (en vez de desaparecer de golpe).
func _cartel_exito() -> void:
	if not is_instance_valid(_cartel) or not is_instance_valid(_capa_cartel):
		_quitar_cartel()
		return
	var capa := _capa_cartel
	var cartel := _cartel
	_capa_cartel = null
	_cartel = null
	var tecla := cartel.get_child(0) as Label
	tecla.text = "OK"   # la fuente no trae el tilde
	tecla.reset_size()
	tecla.position = -tecla.size * 0.5
	if cartel.get_child_count() > 1:
		cartel.get_child(1).queue_free()   # la etiqueta ya no hace falta
	var tw := cartel.create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(cartel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(capa.queue_free)


func _quitar_cartel() -> void:
	if is_instance_valid(_capa_cartel):
		_capa_cartel.queue_free()
	_capa_cartel = null
	_cartel = null


func _conectar() -> void:
	match accion:
		Accion.GOLPE_LIGERO, Accion.GOLPE_FUERTE, Accion.ESPECIAL:
			_jugador.attack_performed.connect(_on_ataque)
		Accion.PARRY:
			_jugador.parry_exitoso.connect(_completar)
		Accion.TRANSFORMAR:
			_jugador.form_changed.connect(_on_forma)


func _desconectar() -> void:
	if _jugador == null or not is_instance_valid(_jugador):
		return
	if _jugador.attack_performed.is_connected(_on_ataque):
		_jugador.attack_performed.disconnect(_on_ataque)
	if _jugador.parry_exitoso.is_connected(_completar):
		_jugador.parry_exitoso.disconnect(_completar)
	if _jugador.form_changed.is_connected(_on_forma):
		_jugador.form_changed.disconnect(_on_forma)


func _on_ataque(tipo: String, _paso: Variant) -> void:
	if _forma_ok() and ((accion == Accion.GOLPE_LIGERO and tipo == "light") or (accion == Accion.GOLPE_FUERTE and tipo == "heavy") \
			or (accion == Accion.ESPECIAL and tipo == "special")):
		_completar()


func _forma_ok() -> bool:
	return forma_requerida < 0 or int(_jugador.current_form) == forma_requerida


func _on_forma(_nombre: String) -> void:
	if _forma_ok():
		_completar()


## El jugador hizo la acción de este paso (aunque no sea su turno): se tacha sola.
func _on_accion_hecha(clave: String) -> void:
	if clave != _clave() or _visto() or (ignorar_hecho and not _activo):
		return
	if _activo and _jugador != null:
		_completar()
		return
	var dlg := get_node_or_null("/root/Dialogo")
	if dlg != null and not _activo and dlg.lista_existe(paso_id):
		_marcar_visto()
		dlg.lista_completar(paso_id)


## Mientras haya una tarea en curso, los consejos sueltos esperan (si no, los globos tapan la tarea).
func _bloquear_tips(dlg: Node) -> void:
	if _bloquea or dlg == null:
		return
	_bloquea = true
	_t_bloqueo = 0.0
	dlg.pasos_activos += 1


func _liberar_tips() -> void:
	if not _bloquea:
		return
	_bloquea = false
	var dlg := get_node_or_null("/root/Dialogo")
	if dlg != null:
		dlg.pasos_activos = maxi(dlg.pasos_activos - 1, 0)


func _exit_tree() -> void:
	_liberar_tips()


func _process(delta: float) -> void:
	if not _activo:
		return
	_seguir_jugador()
	if _bloquea:
		_t_bloqueo += delta
		if _t_bloqueo >= segundos_bloqueo_tips:
			_liberar_tips()   # el jugador no la hace: que los demás consejos sigan saliendo
	if accion == Accion.MOVER and absf(Input.get_axis("move_left", "move_right")) > 0.3:
		_completar()
		return
	if accion == Accion.SALTO_LARGO:
		_salto_t = _salto_t + delta if Input.is_action_pressed("jump") and not _jugador.is_on_floor() else 0.0
		if _salto_t >= segundos_salto_largo:
			_completar()
			return
	if _pista_dada or _pista.is_empty():
		return
	_espera += delta
	if _espera >= segundos_pista:
		_dar_pista()


## Si el jugador se traba, el Amuleto da una pista en su voz y la tarea late en la lista.
func _dar_pista() -> void:
	_pista_dada = true
	var dlg := get_node_or_null("/root/Dialogo")
	if dlg == null or dlg.nivel_ayuda < 2:
		return
	dlg.lista_pista(paso_id)
	dlg.mostrar_tip([_pista], hablante, false, true)


func _input(event: InputEvent) -> void:
	if not _activo:
		return
	if accion == Accion.SALTO_AIRE and event.is_action_pressed("jump") and not _jugador.is_on_floor() and _forma_ok():
		_completar()
		return
	if (accion == Accion.SALTAR and event.is_action_pressed("jump")) \
			or (accion == Accion.BLOQUEAR and event.is_action_pressed("block")):
		_completar()


func _marcar_visto() -> void:
	var prog := get_node_or_null("/root/Progresion")
	if prog != null and not paso_id.is_empty():
		prog.marcar_dialogo_visto(paso_id)


func _completar() -> void:
	if not _activo:
		return
	_activo = false
	_liberar_tips()
	_cartel_exito()
	_desconectar()
	_marcar_visto()
	var dlg := get_node_or_null("/root/Dialogo")
	if dlg != null:
		dlg.lista_completar(paso_id)
	if get_node_or_null(paso_siguiente) == null and not _cierre.is_empty():
		_cerrar_bloque(dlg)
	_pasar_al_siguiente(_jugador)


## Último paso de una cadena: el Amuleto lo reconoce con una frase sobria.
func _cerrar_bloque(dlg: Node) -> void:
	await get_tree().create_timer(1.0, false).timeout
	if dlg != null and dlg.nivel_ayuda == 2 and not dlg.hay_narrativa():
		dlg.celebrar()
		dlg.mostrar_tip([_cierre], hablante, false, true)


func _pasar_al_siguiente(jugador: Node) -> void:
	var sig := get_node_or_null(paso_siguiente)
	if sig == null or not sig.has_method("activar"):
		return
	# Deja un respiro para que se vea el "✓" antes de pasar al siguiente.
	await get_tree().create_timer(0.7, false).timeout
	if is_instance_valid(sig):
		sig.activar(jugador)


## Agrega a la lista este paso y los siguientes de la cadena que aún no se hicieron.
func _registrar_cadena(dlg: Node) -> void:
	var paso: Node = self
	for _i in 12:
		if paso == null or not paso.has_method("registrar_en_lista"):
			break
		paso.registrar_en_lista(dlg)
		paso = paso.get_node_or_null(paso.paso_siguiente)


func registrar_en_lista(dlg: Node) -> void:
	if not paso_id.is_empty() and not _visto() and not _ya_hecho(dlg) and not dlg.lista_existe(paso_id):
		dlg.lista_agregar(paso_id, texto)
