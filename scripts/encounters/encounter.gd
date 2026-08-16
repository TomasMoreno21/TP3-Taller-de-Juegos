extends Area2D

signal completado

enum Estado { INACTIVE, RUNNING, COMPLETED }

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

@export var olas: Array[WaveOla] = []
@export var camara: Camera2D
@export var arena_center := Vector2.ZERO
@export var arena_medio_ancho := 300.0

# Límites de la arena generados automáticamente según arena_center/arena_medio_ancho.
@export var paredes_auto := true    # generar 2 paredes laterales muy altas
@export var ancho_pared := 30.0     # grosor de cada pared
@export var altura_pared := 9000.0  # tan alto que no se puede saltar por arriba
@export var separacion_pared := 60.0  # espacio extra fuera de arena_medio_ancho

var estado: int = Estado.INACTIVE
var _ola_idx := -1
var _vivos_ola := 0
var _manuales: Array[Array] = []
var _spawned: Array[Node] = []
var _bounds: Array[CollisionShape2D] = []


func _ready() -> void:
	if camara == null:
		camara = get_viewport().get_camera_2d()
	_recolectar_bounds()
	_generar_paredes()
	_agrupar_manuales()
	body_entered.connect(_on_body_entered)
	_preparar_manuales()
	_ocultar_bounds()


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
		return arena_center + Vector2(lado * (arena_medio_ancho + 140.0), 0.0)
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
	completado.emit()


# --- Bounds (paredes invisibles de la arena) ---

func _generar_paredes() -> void:
	_derivar_arena_desde_nodo()
	if not paredes_auto or not _bounds.is_empty():
		return
	var contenedor := get_node_or_null("Bounds")
	if contenedor == null:
		return
	var rect := RectangleShape2D.new()
	rect.size = Vector2(ancho_pared, altura_pared)
	for lado in [-1.0, 1.0]:
		var pared := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		shape.shape = rect
		pared.add_child(shape)
		contenedor.add_child(pared)
		pared.position = Vector2(
			arena_center.x + lado * (arena_medio_ancho + separacion_pared),
			arena_center.y - altura_pared * 0.5
		)
		_bounds.append(shape)


func _derivar_arena_desde_nodo() -> void:
	# Si existe el nodo visual "Arena" (con su "ArenaShape" rectángulo), usá su
	# centro y ancho en vez de los @export. Así mover/estirar Arena en el editor
	# redefine la arena automáticamente.
	var shape := get_node_or_null("Arena/ArenaShape")
	if shape is CollisionShape2D and shape.shape is RectangleShape2D:
		var rect: RectangleShape2D = shape.shape
		arena_center = (shape as CollisionShape2D).global_position
		arena_medio_ancho = rect.size.x * 0.5


func _recolectar_bounds() -> void:
	_bounds.clear()
	var contenedor := get_node_or_null("Bounds")
	if contenedor == null:
		return
	for pared in contenedor.get_children():
		for hijo in pared.get_children():
			if hijo is CollisionShape2D:
				_bounds.append(hijo)


func _mostrar_bounds() -> void:
	for b in _bounds:
		b.set_deferred("disabled", false)


func _ocultar_bounds() -> void:
	for b in _bounds:
		b.set_deferred("disabled", true)
