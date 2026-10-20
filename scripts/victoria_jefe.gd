extends CanvasLayer
## Cierre del juego (lo agrega nivel_jefe.gd al morir el Arzobispo y pausa el árbol; esta escena
## corre igual con process_mode = ALWAYS). Secuencia: destello del estallido → negro total → líneas del
## guion (Humano y Amuleto, ver docs/sesiones/final.md) como texto central, letra a letra y pesado →
## frase final → créditos (`escena_siguiente`).
## Todo se edita desde el Inspector. (El hijo placeholder ya no se muestra; sus @export quedan para cuando tenga arte.)

const SONIDO_TECLA := preload("res://assets/audio/sfx/gen/dialogo_tecla.wav")

signal terminada  ## la secuencia acabó (justo antes de cambiar de escena)

@export_group("Guion")
@export var lineas := PackedStringArray([
	"[humano][susurro] Hijo…",
	"El sello cede. Él está dentro, a salvo.",
	"[humano] Estoy aquí. Ya pasó.",
	"Sostenelo. Yo contengo lo que queda.",
])
@export var hablante := "Amuleto"
@export_group("Hijo (placeholder)")
@export var textura_hijo: Texture2D                       ## arte del hijo; vacío = silueta de luz
@export var escala_hijo := 1.0
@export var seguir_al_jefe := true                        ## aparece donde murió el jefe (si no, en `pos_hijo`)
@export var pos_hijo := Vector2(1260, 925)                ## posición en pantalla (px) si no sigue al jefe
@export var color_luz := Color(1.0, 0.86, 0.55)
@export var color_silueta := Color(0.07, 0.05, 0.08)
@export var oscurecer_mundo := 0.6                        ## cuánto se apaga la arena detrás
@export_group("Tiempos (s)")
@export var aparicion_hijo := 2.4
@export var pausa_tras_dialogo := 1.0
@export var seg_por_letra := 0.055  ## ritmo del texto: más alto = más pesado
@export var volumen_tipeo_db := -9.0   ## volumen del sonido de cada letra
@export var tono_tipeo := 0.8          ## pitch del sonido de cada letra (grave = más pesado)
@export var pausa_linea := 1.6       ## cuánto se sostiene cada línea completa
@export var pausa_entre_lineas := 0.8
@export var fundido_negro := 1.6
@export var pausa_negro := 0.8
@export var aparicion_frase := 1.6
@export var duracion_frase := 4.0
@export var desaparicion_frase := 1.4
@export_group("Frase final")
@export_multiline var frase := "Lo que el bosque se llevó,\nel bosque lo devuelve."
@export var tam_frase := 64
@export var color_texto := Color(0.96, 0.93, 0.85)
@export var color_filete := Color(0.85, 0.72, 0.40)
@export var largo_filete := 560.0
@export_group("Después")
@export_file("*.tscn") var escena_siguiente := "res://scenes/creditos_final.tscn"   ## vacío = no cambiar de escena (tests)

var _luz := 0.0           ## intensidad de la luz del hijo (0..1)
var _t := 0.0
var _saltar := false
var _frase_activa := false

@onready var velo: ColorRect = $Velo
@onready var resplandor: Node2D = $Escena/Resplandor
@onready var silueta: Node2D = $Escena/Resplandor/Silueta
@onready var hijo_sprite: Sprite2D = $Escena/Resplandor/Hijo
@onready var flash: ColorRect = $Flash
@onready var negro: ColorRect = $Negro
@onready var caja_frase: VBoxContainer = $Frase
@onready var etiqueta: Label = $Frase/Etiqueta
@onready var filete_a: ColorRect = $Frase/FileteArriba/Linea
@onready var filete_b: ColorRect = $Frase/FileteAbajo/Linea


func _ready() -> void:
	add_to_group("victoria")   # con la secuencia de cierre en juego no se puede pausar (pause.gd)
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80   # bajo el diálogo (85): los globos se ven encima
	var dlg := get_node_or_null("/root/Dialogo")
	if dlg != null:
		dlg.gema.visible = false   # el logo del Amuleto se quedaba fijo con el árbol pausado
	resplandor.material = _material_suma()
	resplandor.draw.connect(_dibujar_luz)
	silueta.draw.connect(_dibujar_silueta)
	silueta.material = null
	hijo_sprite.texture = textura_hijo
	hijo_sprite.visible = textura_hijo != null
	silueta.visible = textura_hijo == null
	hijo_sprite.scale = Vector2.ONE * escala_hijo
	silueta.scale = Vector2.ONE * escala_hijo
	etiqueta.text = frase
	etiqueta.add_theme_font_size_override("font_size", tam_frase)
	etiqueta.add_theme_color_override("font_color", color_texto)
	for f in [filete_a, filete_b]:
		f.color = color_filete
		f.custom_minimum_size = Vector2(0, 2)
	velo.color = Color(0.02, 0.015, 0.04, 0.0)
	flash.color = Color(1, 0.97, 0.9, 0.0)
	negro.color = Color(0, 0, 0, 0)
	caja_frase.modulate.a = 0.0
	resplandor.position = _posicion_inicial()
	hijo_sprite.modulate.a = 0.0
	silueta.modulate.a = 0.0
	_correr()


func _material_suma() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


func _posicion_inicial() -> Vector2:
	if seguir_al_jefe:
		var jefe := get_tree().get_first_node_in_group("boss") as Node2D
		if jefe != null and is_instance_valid(jefe):
			var p: Vector2 = get_viewport().get_canvas_transform() * jefe.global_position + Vector2(0, 80)
			if Rect2(Vector2(200, 200), get_viewport().get_visible_rect().size - Vector2(400, 300)).has_point(p):
				return p   # si el jefe quedó fuera de cuadro, usa `pos_hijo`
	return pos_hijo


func _process(delta: float) -> void:
	_t += delta
	resplandor.queue_redraw()


func _espera(seg: float) -> void:
	await get_tree().create_timer(maxf(seg, 0.01), true, false, true).timeout


func _tween() -> Tween:
	return create_tween().set_ignore_time_scale(true).set_parallel(true)


func _correr() -> void:
	# 1) Espera a que el destello del jefe (JefeCine.destello_final) termine de cubrir la pantalla.
	var velos := get_tree().get_nodes_in_group("destello_final")
	while velos.any(func(c: Node) -> bool: return is_instance_valid(c) and c.get_child(0).color.r > 0.0):
		await get_tree().process_frame
	# 2) Corte seco a negro (queda bajo el velo, que se libera) y el diálogo sale como texto central, letra a letra.
	negro.color.a = 1.0
	for c in velos:
		if is_instance_valid(c):
			c.queue_free()
	await _espera(pausa_negro)
	for l in lineas:
		await _linea(String(l))
	await _espera(pausa_tras_dialogo)
	# 3) Frase final.
	await _mostrar_frase()
	_terminar()


func _terminar() -> void:
	terminada.emit()
	if escena_siguiente.is_empty():
		return
	TransicionPantalla.de(get_tree()).cambiar_escena(escena_siguiente)


## Una línea del guion en el centro: aparece letra a letra, se sostiene y se apaga.
func _linea(l: String) -> void:
	var humano := l.begins_with("[humano]")
	etiqueta.text = RegEx.create_from_string("^(\\[[^\\]]*\\]\\s*)+").sub(l, "")
	etiqueta.add_theme_color_override("font_color", color_texto if humano else color_filete)
	caja_frase.modulate.a = 1.0
	for f in [filete_a, filete_b]:
		f.custom_minimum_size.x = 0.0
	await _escribir()
	await _espera(pausa_linea)
	var s := _tween()
	s.tween_property(caja_frase, "modulate:a", 0.0, desaparicion_frase)
	await _espera(desaparicion_frase + pausa_entre_lineas)


## Letras pesadas: cada una cae despacio y los signos de pausa se sostienen.
func _escribir() -> void:
	etiqueta.visible_characters = 0
	for i in etiqueta.text.length():
		etiqueta.visible_characters = i + 1
		var c := etiqueta.text[i]
		if c != " " and c != "\n":
			AudioManager.play_sfx(SONIDO_TECLA, volumen_tipeo_db, 0.05, tono_tipeo)
		await _espera(seg_por_letra * (6.0 if c in "…,.;:" else 1.0))


func _mostrar_frase() -> void:
	_frase_activa = true
	etiqueta.text = frase
	etiqueta.add_theme_color_override("font_color", color_texto)
	caja_frase.modulate.a = 1.0
	var t := _tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for f in [filete_a, filete_b]:
		t.tween_property(f, "custom_minimum_size:x", largo_filete, aparicion_frase * 1.2)
	await _escribir()
	var resto := duracion_frase
	while resto > 0.0 and not _saltar:   # Confirmar adelanta el final
		await get_tree().process_frame
		resto -= get_process_delta_time()
	var s := _tween()
	s.tween_property(caja_frase, "modulate:a", 0.0, desaparicion_frase)
	await _espera(desaparicion_frase + 0.3)
	_frase_activa = false


func _unhandled_input(event: InputEvent) -> void:
	if _frase_activa and event.is_action_pressed("menu_confirm"):
		_saltar = true


# ------------------------------------------------------------------ dibujo (placeholder)

## Aura cálida del hijo: halo suave y rayos que giran despacio.
func _dibujar_luz() -> void:
	var l := _luz
	if l <= 0.001:
		return
	var c := color_luz
	var pulso := 1.0 + 0.05 * sin(_t * 2.4)
	for i in 16:
		var r := (270.0 - float(i) * 15.0) * l * pulso
		resplandor.draw_circle(Vector2.ZERO, r, Color(c, 0.02 + 0.007 * float(i)))
	for i in 12:
		var a := _t * 0.12 + float(i) * TAU / 12.0
		var largo := (330.0 + 90.0 * sin(_t * 0.9 + float(i) * 1.7)) * l
		var ancho := 0.07
		var pts := PackedVector2Array([Vector2.ZERO, Vector2(cos(a - ancho), sin(a - ancho)) * largo, Vector2(cos(a + ancho), sin(a + ancho)) * largo])
		resplandor.draw_polygon(pts, PackedColorArray([Color(c, 0.22 * l), Color(c, 0.0), Color(c, 0.0)]))
	# Motas que suben.
	for i in 14:
		var u := fposmod(_t * 0.18 + float(i) * 0.071, 1.0)
		var x := sin(float(i) * 5.7 + _t * 0.6) * (60.0 + float(i) * 9.0)
		resplandor.draw_circle(Vector2(x, 40.0 - u * 260.0), 2.0 + float(i % 3), Color(c, sin(u * PI) * 0.7 * l))


## Silueta de un niño (provisoria): cabeza, cuerpo y brazos algo abiertos, a contraluz.
func _dibujar_silueta() -> void:
	var c := color_silueta
	var cuerpo := PackedVector2Array([
		Vector2(-20, -70), Vector2(20, -70), Vector2(30, -20), Vector2(26, 60), Vector2(10, 60), Vector2(6, 10),
		Vector2(-6, 10), Vector2(-10, 60), Vector2(-26, 60), Vector2(-30, -20)])
	silueta.draw_colored_polygon(cuerpo, c)
	var cabeza := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		cabeza.append(Vector2(0, -98) + Vector2(cos(a) * 24.0, sin(a) * 26.0))
	silueta.draw_colored_polygon(cabeza, c)
	# Brazos abiertos hacia el padre.
	silueta.draw_colored_polygon(PackedVector2Array([Vector2(-24, -62), Vector2(-62, -30), Vector2(-56, -22), Vector2(-20, -44)]), c)
	silueta.draw_colored_polygon(PackedVector2Array([Vector2(24, -62), Vector2(62, -30), Vector2(56, -22), Vector2(20, -44)]), c)
	# Filo de luz en el contorno.
	var borde := PackedVector2Array(cuerpo)
	borde.append(cuerpo[0])
	silueta.draw_polyline(borde, Color(color_luz, 0.55), 2.0, true)
	silueta.draw_polyline(cabeza + PackedVector2Array([cabeza[0]]), Color(color_luz, 0.55), 2.0, true)
