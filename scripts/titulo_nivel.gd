extends CanvasLayer
class_name TituloNivel
## Cartel de nivel: al llegar (no al reaparecer tras morir) la pantalla queda en negro unos segundos,
## aparece el nombre en grande, y se desvanece de a poco para dar paso al juego.
## Mientras dura, el jugador no tiene control. Si hay una IntroNivel, ella espera a `listo`.

signal listo       ## empieza el desvanecimiento: lo que sigue (intro) ya puede arrancar
signal terminado

static var _ultimo := ""    ## título ya mostrado: recargar el mismo nivel (morir) no repite el cartel

@export var titulo := "NIVEL 1"
@export var subtitulo := ""
@export var espera_inicial := 1.6      ## s en negro antes del texto
@export var aparicion := 0.9
@export var duracion := 2.6            ## s con el texto completo
@export var desvanecer := 2.2          ## s en desaparecer (negro y texto juntos)
@export var tam_titulo := 110
@export var tam_subtitulo := 44
@export var color_texto := Color(0.96, 0.93, 0.85)
@export var color_fondo := Color(0, 0, 0)
@export var siempre := false           ## mostrarlo aunque sea el mismo nivel que el anterior

var activo := false
var _fondo: ColorRect
var _caja: VBoxContainer


func _ready() -> void:
	layer = 110
	add_to_group("titulo_nivel")
	if DisplayServer.get_name() == "headless" or (not siempre and _ultimo == titulo):
		return
	_ultimo = titulo
	activo = true
	_construir()
	_jugador_congelar.call_deferred(true)
	_correr()


func _construir() -> void:
	_fondo = ColorRect.new()
	_fondo.color = color_fondo
	_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fondo)
	_caja = VBoxContainer.new()
	_caja.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_caja.alignment = BoxContainer.ALIGNMENT_CENTER
	_caja.modulate.a = 0.0
	_caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caja)
	_caja.add_child(_etiqueta(titulo, tam_titulo))
	if subtitulo != "":
		_caja.add_child(_etiqueta(subtitulo, tam_subtitulo))


func _etiqueta(texto: String, tam: int) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color_texto)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 8)
	return l


func _correr() -> void:
	await get_tree().create_timer(espera_inicial).timeout
	var tw := create_tween()
	tw.tween_property(_caja, "modulate:a", 1.0, aparicion)
	await tw.finished
	await get_tree().create_timer(duracion).timeout
	listo.emit()
	var sal := create_tween().set_parallel(true)
	sal.tween_property(_fondo, "color:a", 0.0, desvanecer)
	sal.tween_property(_caja, "modulate:a", 0.0, desvanecer)
	await sal.finished
	if not _hay_intro_activa():
		_jugador_congelar(false)
	activo = false
	terminado.emit()
	queue_free()


func _hay_intro_activa() -> bool:
	for h in get_parent().get_children():
		if h is IntroNivel and h.get("_activa"):
			return true
	return false


func _jugador_congelar(si: bool) -> void:
	var j := get_tree().get_first_node_in_group("player")
	if j != null and (si or not _hay_intro_activa()):
		j.set("cinematica_activa", si)
		if si:
			j.set("cinematica_dir", 0.0)
