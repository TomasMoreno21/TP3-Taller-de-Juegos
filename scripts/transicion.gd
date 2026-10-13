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
var _pedidas := {}   ## rutas con carga en segundo plano pedida (ver `precargar`)

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


## Pide cargar `ruta` en un hilo aparte para que el cambio de escena no espere a leer el
## archivo (nivel1.tscn pesa ~7 MB: ~1.4 s). Llamarlo con antelación (durante el cómic,
## al ver la puerta de salida...). Sin efecto en headless ni si ya estaba pedida.
func precargar(ruta: String) -> void:
	if DisplayServer.get_name() == "headless" or ruta.is_empty() or _pedidas.has(ruta):
		return
	if ResourceLoader.load_threaded_request(ruta, "PackedScene", true) == OK:
		_pedidas[ruta] = true


func cambiar_escena(ruta: String) -> void:
	# precargar(ruta)   # deshabilitado para nivel1/comic largo por fallo threaded
	fundido(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file(ruta))


## Espera (sin congelar el fundido) a que termine la carga en segundo plano.
func _esperar_carga(ruta: String) -> PackedScene:
	if not _pedidas.has(ruta):
		return null
	while ResourceLoader.load_threaded_get_status(ruta) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	_pedidas.erase(ruta)
	if ResourceLoader.load_threaded_get_status(ruta) != ResourceLoader.THREAD_LOAD_LOADED:
		return null
	return ResourceLoader.load_threaded_get(ruta) as PackedScene


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
	await accion.call()
	# Dos frames: la escena nueva termina de entrar al árbol antes de descubrir.
	await get_tree().process_frame
	await get_tree().process_frame
	await _fundir(0.0, duracion_entrada)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	velo.visible = false
	_ocupado = false


func _fundir(alfa: float, dur: float) -> void:
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(velo, "color", Color(color, alfa), maxf(dur, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
