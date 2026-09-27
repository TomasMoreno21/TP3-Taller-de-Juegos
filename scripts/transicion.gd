class_name TransicionPantalla
extends CanvasLayer
## Transiciones de pantalla (singleton perezoso colgado de root, sobrevive a los
## cambios de escena; se obtiene con TransicionPantalla.de(get_tree())): fundido a negro → acción (cambiar/recargar escena,
## reaparecer en el checkpoint) → fundido de vuelta. Corre en pausa y con cámara
## lenta (reloj real). En headless es instantáneo para no demorar los tests.

@export var duracion_salida := 0.35      ## s del fundido a negro
@export var duracion_entrada := 0.45     ## s del fundido de vuelta
@export var color := Color(0.02, 0.025, 0.035)

var _ocupado := false

@onready var velo: ColorRect = $Velo


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	velo.color = Color(color, 0.0)
	velo.visible = false


static func de(arbol: SceneTree) -> TransicionPantalla:
	var t := arbol.root.get_node_or_null("Transicion") as TransicionPantalla
	if t == null:
		t = (load("res://scenes/transicion.tscn") as PackedScene).instantiate()
		t.name = "Transicion"
		arbol.root.add_child(t)
	return t


func esta_ocupado() -> bool:
	return _ocupado


func cambiar_escena(ruta: String) -> void:
	fundido(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file(ruta))


func recargar() -> void:
	fundido(func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())


## Cubre la pantalla, ejecuta `accion` con la pantalla en negro y descubre.
func fundido(accion: Callable) -> void:
	if DisplayServer.get_name() == "headless":
		accion.call()
		return
	if _ocupado:
		return
	_ocupado = true
	velo.visible = true
	velo.mouse_filter = Control.MOUSE_FILTER_STOP   # bloquea clics a medio fundido
	await _fundir(1.0, duracion_salida)
	accion.call()
	# Dos frames: la escena nueva termina de entrar al árbol antes de descubrir.
	await get_tree().process_frame
	await get_tree().process_frame
	await _fundir(0.0, duracion_entrada)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	velo.visible = false
	_ocupado = false


func _fundir(alfa: float, dur: float) -> void:
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(velo, "color", Color(color, alfa), maxf(dur, 0.01))
	await tw.finished
