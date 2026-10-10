extends CanvasLayer
class_name TituloNivel
## Cartel de nivel: al llegar (no al reaparecer tras morir) la pantalla queda en negro unos segundos,
## aparece el nombre de la zona con dos filetes que se abren desde el centro, una lenta ampliación
## mientras se lee, y todo se desvanece de a poco para dar paso al juego.
## Mientras dura, el jugador no tiene control. Si hay una IntroNivel, ella espera a `listo`.

signal listo       ## empieza el desvanecimiento: lo que sigue (intro) ya puede arrancar
signal terminado

static var _ultimo := ""    ## respaldo si no hay Progresion: título ya mostrado (recargar el mismo nivel no repite el cartel)

@export var titulo := "El Bosque"        ## nombre de la zona (sin "Nivel X")
@export var subtitulo := ""              ## opcional: línea chica debajo
@export var mayusculas := true
@export var espera_inicial := 1.2      ## s en negro antes del texto
@export var aparicion := 1.0           ## s en aparecer el texto y abrirse los filetes
@export var duracion := 1.8            ## s con el texto completo
@export var desvanecer := 1.9          ## s en desaparecer (negro y texto juntos)
@export var tam_titulo := 120
@export var tam_subtitulo := 38
@export var color_texto := Color(0.96, 0.93, 0.85)
@export var color_filete := Color(0.85, 0.72, 0.40)
@export var color_fondo := Color(0, 0, 0)
@export var largo_filete := 0.0           ## 0 = automático (ancho del título + margen)
@export var margen_filete := 90.0       ## cuánto sobresalen los filetes a cada lado del texto (solo con largo automático)
@export var siempre := false           ## mostrarlo aunque ya se haya visto en esta partida
@export var probar_en_headless := false   ## en headless el cartel se omite (los tests esperan control inmediato)

var activo := false
var _fondo: ColorRect
var _caja: VBoxContainer
var _filetes: Array[Control] = []
var _adorno: Control


func _ready() -> void:
	layer = 110
	add_to_group("titulo_nivel")
	if DisplayServer.get_name() == "headless" and not probar_en_headless:
		return
	if not siempre and _ya_visto():
		return
	_marcar_visto()
	activo = true
	_construir()
	_jugador_congelar.call_deferred(true)
	_correr()


## Se muestra una vez por partida: morir y recargar el nivel no lo repite, pero "Jugar" de nuevo
## (Progresion.reset) sí, igual que la intro. Sin Progresion cae en el título guardado en memoria.
func _ya_visto() -> bool:
	var prog := get_node_or_null("/root/Progresion")
	if prog != null:
		return prog.dialogo_visto("titulo_" + titulo)
	return _ultimo == titulo


func _marcar_visto() -> void:
	_ultimo = titulo
	var prog := get_node_or_null("/root/Progresion")
	if prog != null:
		prog.marcar_dialogo_visto("titulo_" + titulo)


func _construir() -> void:
	_fondo = ColorRect.new()
	_fondo.color = color_fondo
	_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fondo)
	_caja = VBoxContainer.new()
	_caja.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_caja.alignment = BoxContainer.ALIGNMENT_CENTER
	_caja.add_theme_constant_override("separation", 26)
	_caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caja.modulate.a = 0.0
	add_child(_caja)
	_caja.add_child(_crear_filete())
	_caja.add_child(_etiqueta(titulo.to_upper() if mayusculas else titulo, tam_titulo))
	if subtitulo != "":
		_caja.add_child(_etiqueta(subtitulo, tam_subtitulo, 0.8))
	_caja.add_child(_crear_filete())
	# Rombo hijo del filete de abajo, anclado a su centro: se mueve y se desvanece con él.
	_adorno = ColorRect.new()
	_adorno.color = color_filete
	_adorno.set_anchors_preset(Control.PRESET_CENTER)
	_adorno.offset_left = -7.0
	_adorno.offset_right = 7.0
	_adorno.offset_top = -7.0
	_adorno.offset_bottom = 7.0
	_adorno.pivot_offset = Vector2(7, 7)
	_adorno.rotation = PI * 0.25
	_adorno.modulate.a = 0.0
	_adorno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_filetes[_filetes.size() - 1].add_child(_adorno)


func _crear_filete() -> Control:
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := ColorRect.new()
	f.color = color_filete
	f.custom_minimum_size = Vector2(0, 2)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(f)
	_filetes.append(f)
	return c


func _etiqueta(texto: String, tam: int, alfa := 1.0) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", Color(color_texto, alfa))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 4)
	return l


func _correr() -> void:
	await get_tree().create_timer(espera_inicial).timeout
	# Solo desvanecimientos y filetes que se abren: escalar el texto lo re-rasteriza cada frame y se ve vibrar.
	var largo := largo_filete
	if largo <= 0.0:
		largo = (_caja.get_child(1) as Control).get_combined_minimum_size().x + margen_filete * 2.0
	var ap := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ap.tween_property(_caja, "modulate:a", 1.0, aparicion)
	for f in _filetes:
		ap.tween_property(f, "custom_minimum_size:x", largo, aparicion * 1.2)
	await ap.finished
	create_tween().tween_property(_adorno, "modulate:a", 1.0, 0.4)
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
