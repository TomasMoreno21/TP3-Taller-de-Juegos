extends Node
## Opciones del jugador (autoload "Opciones"): volumen de música y efectos y pantalla completa.
## Crea los buses "Musica" y "SFX" (hijos de Master) y guarda/lee user://opciones.cfg.
## El volumen se guarda lineal (0-1); la pantalla completa solo se aplica con ventana (no en headless).

const RUTA := "user://opciones.cfg"
const BUS_MUSICA := &"Musica"
const BUS_SFX := &"SFX"
## Ganancia general de todo el juego (dB sobre Master). Un limitador en Master evita que los picos distorsionen.
const GANANCIA_MASTER_DB := 1.5

signal cambiado

var volumen_musica := 1.0
var volumen_sfx := 1.0
var pantalla_completa := true   ## el proyecto arranca en pantalla completa (window/size/mode)


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_crear_bus(BUS_MUSICA)
	_crear_bus(BUS_SFX)
	_cargar()
	_aplicar_audio()
	_aplicar_pantalla()


func _crear_bus(nombre: StringName) -> void:
	if AudioServer.get_bus_index(nombre) >= 0:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, nombre)
	AudioServer.set_bus_send(i, &"Master")


var _guardado_pendiente := false


## Arrastrar un slider dispara decenas de cambios por segundo: se escribe a disco una sola vez, medio segundo después del último.
func _guardar_diferido() -> void:
	if _guardado_pendiente:
		return
	_guardado_pendiente = true
	await get_tree().create_timer(0.5).timeout
	_guardado_pendiente = false
	_guardar()


## Salir del juego antes de los 0,5 s del guardado agrupado no debe perder el último cambio.
func _exit_tree() -> void:
	if _guardado_pendiente:
		_guardar()


func fijar_musica(v: float) -> void:
	volumen_musica = clampf(v, 0.0, 1.0)
	_aplicar_audio()
	_guardar_diferido()


func fijar_sfx(v: float) -> void:
	volumen_sfx = clampf(v, 0.0, 1.0)
	_aplicar_audio()
	_guardar_diferido()


func fijar_pantalla_completa(activa: bool) -> void:
	pantalla_completa = activa
	_aplicar_pantalla()
	_guardar()


func _aplicar_ganancia_master() -> void:
	var m := AudioServer.get_bus_index(&"Master")
	if m < 0:
		return
	AudioServer.set_bus_volume_db(m, GANANCIA_MASTER_DB)
	for k in AudioServer.get_bus_effect_count(m):
		if AudioServer.get_bus_effect(m, k) is AudioEffectLimiter:
			return
	var lim := AudioEffectLimiter.new()
	lim.ceiling_db = -0.5
	AudioServer.add_bus_effect(m, lim)


func _aplicar_audio() -> void:
	_aplicar_ganancia_master()
	_volumen_bus(BUS_MUSICA, volumen_musica)
	_volumen_bus(BUS_SFX, volumen_sfx)
	cambiado.emit()


func _volumen_bus(nombre: StringName, v: float) -> void:
	var i := AudioServer.get_bus_index(nombre)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


func _aplicar_pantalla() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if pantalla_completa else DisplayServer.WINDOW_MODE_WINDOWED)


func _cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RUTA) != OK:
		return
	volumen_musica = clampf(float(cfg.get_value("audio", "musica", 1.0)), 0.0, 1.0)
	volumen_sfx = clampf(float(cfg.get_value("audio", "sfx", 1.0)), 0.0, 1.0)
	pantalla_completa = bool(cfg.get_value("video", "pantalla_completa", true))


func _guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "musica", volumen_musica)
	cfg.set_value("audio", "sfx", volumen_sfx)
	cfg.set_value("video", "pantalla_completa", pantalla_completa)
	cfg.save(RUTA)
