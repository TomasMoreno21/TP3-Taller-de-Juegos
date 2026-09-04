extends Area2D

signal completado

enum Estado { INACTIVE, RUNNING, COMPLETED }

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

@export var olas: Array[WaveOla] = []
@export var camara: Camera2D
@export var arena_center := Vector2.ZERO
@export var arena_medio_ancho := 300.0

# Diálogo opcional al completar la arena (post-combate). Vacío = no habla.
@export var lineas_post_combate: PackedStringArray = []
@export var hablante_post_combate := "Amuleto"

# Cerco de la arena: 2 paredes laterales generadas según el nodo "Arena" (o los @export).
@export var paredes_auto := true    # generar las 2 paredes que contienen al jugador
@export var paredes_en_borde_pantalla := true  # reubica las paredes justo en el borde visible de la cámara
@export var ancho_pared := 30.0     # grosor de cada pared
@export var altura_pared := 9000.0  # tan alto que no se puede saltar por arriba
@export var separacion_pared := 60.0  # holgura fuera de arena_medio_ancho (si no es borde de pantalla)

var estado: int = Estado.INACTIVE
var _ola_idx := -1
var _vivos_ola := 0
var _manuales: Array[Array] = []
var _spawned: Array[Node] = []
var _bounds: Array[CollisionShape2D] = []
var _arena_base_y := 0.0  # borde inferior del rect Arena (ancla el piso de las paredes)


func _ready() -> void:
	add_to_group("encounter")
	var arena_visual := get_node_or_null("Arena/ArenaVisual")
	if arena_visual != null:
		arena_visual.visible = false
	if camara == null:
		camara = get_viewport().get_camera_2d()
	_generar_paredes()
	_agrupar_manuales()
	body_entered.connect(_on_body_entered)
	_preparar_manuales()
	_ocultar_bounds()


func _physics_process(_delta: float) -> void:
	# Mientras pelea, las paredes acompañan el borde visible de la cámara
	# (así el escenario de combate es toda la pantalla aunque cambie el zoom).
	if estado == Estado.RUNNING and paredes_en_borde_pantalla:
		_actualizar_paredes_a_borde()


# --- Público (tests / consola) ---

func empezar() -> void:
	if estado != Estado.INACTIVE:
		return
	_empezar()


func _liberar_enemigos() -> void:
	for e in _manuales:
		for n in e:
			if is_instance_valid(n):
				n.queue_free()
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()
	_manuales.clear()


# --- Interno ---

func _agrupar_manuales() -> void:
	_manuales.clear()
	var contenedor := get_node_or_null("Enemies")
	for hijo in get_children():
		if hijo.has_method("activar"):
			_agregar_manual(hijo)
	if contenedor != null:
		for hijo in contenedor.get_children():
			if hijo.has_method("activar"):
				_agregar_manual(hijo)


func _agregar_manual(hijo: Node) -> void:
	var idx := int(hijo.get("ola_asignada"))
	while _manuales.size() <= idx:
		_manuales.append([])
	_manuales[idx].append(hijo)


func _preparar_manuales() -> void:
	for grupo in _manuales:
		for e in grupo:
			if e.has_method("preparar_ola"):
				e.preparar_ola()
			if e.has_signal("died"):
				e.died.connect(_on_enemy_died)


func _on_body_entered(body: Node) -> void:
	if estado != Estado.INACTIVE:
		return
	if body.is_in_group("player"):
		_empezar()


func _empezar() -> void:
	estado = Estado.RUNNING
	_mostrar_bounds()
	if camara != null and camara.has_method("modo_arena"):
		camara.modo_arena(arena_center)
	_ola_idx = -1
	_siguiente_ola()


func _siguiente_ola() -> void:
	_ola_idx += 1
	if _ola_idx >= _total_olas():
		_completar()
		return
	var delay := 0.0
	if _ola_idx < olas.size():
		delay = olas[_ola_idx].delay
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if _ola_idx >= _total_olas():
		_completar()
		return
	_lanzar_ola(_ola_idx)


func _lanzar_ola(idx: int) -> void:
	_vivos_ola = 0
	if idx < _manuales.size():
		for e in _manuales[idx]:
			if is_instance_valid(e):
				e.activar()
				_vivos_ola += 1
	if idx < olas.size():
		_vivos_ola += _spawnear_auto(olas[idx])
	if _vivos_ola <= 0:
		_ola_resuelta()


func _spawnear_auto(ola: WaveOla) -> int:
	if ola.cantidad <= 0:
		return 0
	for i in range(ola.cantidad):
		var e: Node = ENEMY_SCENE.instantiate()
		e.set("tipo", ola.tipo)
		e.set("spawn_telegrafiado", true)
		add_child(e)
		e.global_position = _posicion_spawn(i, ola, ola.cantidad)
		e.activar()
		e.died.connect(_on_enemy_died)
		_spawned.append(e)
	return ola.cantidad


func _posicion_spawn(i: int, ola: WaveOla, total: int) -> Vector2:
	if ola.edge:
		var lado := -1.0 if i % 2 == 0 else 1.0
		var fila := floori(i / 2.0)
		return arena_center + Vector2(lado * (arena_medio_ancho + 140.0) - lado * 60.0 * fila, 0.0)
	var desvio := (float(i) - float(total - 1) * 0.5) * ola.offset.x
	return arena_center + Vector2(desvio, ola.offset.y)


func _on_enemy_died() -> void:
	_vivos_ola -= 1
	if estado == Estado.RUNNING and _vivos_ola <= 0:
		_siguiente_ola()


func _ola_resuelta() -> void:
	if estado != Estado.RUNNING:
		return
	_siguiente_ola()


func _total_olas() -> int:
	return maxi(olas.size(), _manuales.size())


func _completar() -> void:
	estado = Estado.COMPLETED
	_ocultar_bounds()
	if camara != null and camara.has_method("modo_normal"):
		camara.modo_normal()
	if not lineas_post_combate.is_empty():
		get_node("/root/Dialogo").mostrar(Array(lineas_post_combate), hablante_post_combate)
	completado.emit()


# --- Cerco de la arena (paredes laterales) ---

func _generar_paredes() -> void:
	_derivar_arena_desde_nodo()
	if not paredes_auto:
		return
	_bounds.clear()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(ancho_pared, altura_pared)
	for lado in [-1.0, 1.0]:
		var pared := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		shape.shape = rect
		pared.add_child(shape)
		add_child(pared)
		pared.global_position = Vector2(
			arena_center.x + lado * (arena_medio_ancho + separacion_pared),
			_arena_base_y - altura_pared * 0.5
		)
		_bounds.append(shape)


func _derivar_arena_desde_nodo() -> void:
	# La zona de pelea se define con el nodo visual "Arena" (rectángulo editable),
	# SEPARADO del trigger de inicio: así estirar la zona no agranda cuándo arranca.
	# arena_center/arena_medio_ancho se deducen de ArenaShape (incluida su escala)
	# para que estirar/escalar la hitbox en el editor reubique las paredes y la cámara.
	var shape := get_node_or_null("Arena/ArenaShape")
	if shape is CollisionShape2D and shape.shape is RectangleShape2D:
		var shape_node := shape as CollisionShape2D
		var rect: RectangleShape2D = shape_node.shape
		var esc: Vector2 = shape_node.global_scale
		arena_center = shape_node.global_position
		arena_medio_ancho = rect.size.x * 0.5 * absf(esc.x)
		_arena_base_y = arena_center.y + rect.size.y * 0.5 * absf(esc.y)
	else:
		_arena_base_y = arena_center.y


func _mostrar_bounds() -> void:
	for b in _bounds:
		b.set_deferred("disabled", false)
	if paredes_en_borde_pantalla:
		_actualizar_paredes_a_borde()


func _actualizar_paredes_a_borde() -> void:
	# Coloca cada pared sobre el borde visible de la cámara (mitad del viewport
	# dividida por el zoom): con el jugador en el centro, el combate ocupa toda
	# la pantalla. Reacciona a transformaciones/cambios de zoom en el camino.
	if _bounds.is_empty():
		return
	var vista_ancho: float = 1920.0
	if camara != null:
		vista_ancho = camara.get_viewport_rect().size.x
	var media_vista := vista_ancho * 0.5 / maxf(camara.zoom.x if camara != null else 1.0, 0.01)
	for i in _bounds.size():
		var lado := -1.0 if i == 0 else 1.0
		var body := _bounds[i].get_parent() as Node2D
		if body != null:
			body.global_position.x = arena_center.x + lado * media_vista


func _ocultar_bounds() -> void:
	for b in _bounds:
		b.set_deferred("disabled", true)
