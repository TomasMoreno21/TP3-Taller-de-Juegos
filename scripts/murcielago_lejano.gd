extends Node2D

## Murciélago lejano: muy de vez en cuando una silueta oscura cruza despacio el fondo de la cueva, detrás
## del terreno, con un aleteo apenas audible. Reusa el vuelo de MurcielagosPasan (un solo murciélago, chico y lento).

const PASAN := preload("res://scenes/murcielagos_pasan.tscn")

@export var activo := true
@export var primera_espera_min := 25.0   ## s hasta la primera aparición
@export var primera_espera_max := 50.0
@export var intervalo_min := 50.0        ## s entre apariciones (se sortea entre min y max)
@export var intervalo_max := 110.0
@export var escala := 0.5
@export var color := Color(0.07, 0.06, 0.14, 0.7)
@export var velocidad_min := 360.0
@export var velocidad_max := 520.0
@export var recorrido := 2800.0          ## px de ida; más que el ancho de la vista para que entre y salga solo
@export var volumen_db := -28.0
@export var tension_max := 0.25          ## con más tensión (pelea) no aparece

var _espera := 0.0


func _ready() -> void:
	_espera = randf_range(primera_espera_min, primera_espera_max)


func _process(delta: float) -> void:
	if not activo:
		return
	_espera -= delta
	if _espera > 0.0:
		return
	var amb := get_node_or_null("/root/Ambiente")
	if amb != null and float(amb.tension) > tension_max:
		_espera = 5.0
		return
	_espera = randf_range(intervalo_min, intervalo_max)
	lanzar()


func lanzar() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var p: Area2D = PASAN.instantiate()
	p.set("cantidad", 1)
	p.set("altura", 0.0)
	p.set("dispersion_y", 0.0)
	p.set("distancia", recorrido)
	p.set("velocidad_min", velocidad_min)
	p.set("velocidad_max", velocidad_max)
	p.set("escala", escala)
	p.set("color", color)
	p.set("volumen_db", volumen_db)
	p.set("una_vez", false)
	p.set("hacia_la_izquierda", randf() < 0.5)
	p.monitoring = false
	p.z_index = -3
	add_child(p)
	p.global_position = cam.get_screen_center_position() + Vector2(0.0, randf_range(-380.0, -120.0))
	p.call("lanzar")
	get_tree().create_timer(recorrido / velocidad_min + 2.0).timeout.connect(p.queue_free)
