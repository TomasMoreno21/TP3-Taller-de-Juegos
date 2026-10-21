extends CanvasLayer
## Créditos del final (después de la frase «Lo que el bosque se llevó…» de victoria_jefe.gd).
## Sobre negro aparece cada integrante de a uno: su forma, nombre, institución, rol y contacto.
## Al final, el cierre y vuelve al menú. Enter / ataque adelanta la tarjeta; Esc va directo al menú.
## Todo el texto y los tiempos se editan en el Inspector.

signal terminada

@export_group("Integrantes")
@export var nombres := PackedStringArray(["Tomás Moreno", "Micaela Córdoba", "Franco Hereñú"])
@export var institucion := "Estudiante de UNRaf"
@export var roles := PackedStringArray(["Game Design y Programación", "Artista", "Game Design y Programación"])
@export var contactos := PackedStringArray(["Instagram: @tomasss_moreno", "Instagram: @miccacordoba_", "Instagram: @frann_here"])
@export var formas := PackedInt32Array([3, 1, 2])   ## forma de cada uno (0 Humano, 1 Lobo, 2 Oso, 3 Murciélago)
@export_group("Cierre")
@export var titulo_cierre := "SPIRIT KEEPER"
@export var texto_cierre := "Gracias por jugar"
@export var creditos_musica := "Música del jefe: «(Blood) Stained Glass» de FoxSynergy (CC-BY 3.0)"   ## atribución obligatoria
@export_group("Música")
@export var musica: AudioStream = preload("res://assets/audio/musica/jefe_vitral_sangre.ogg")   ## tema del jefe
@export var volumen_musica_db := -8.0
@export var fundido_musica := 8.0           ## s de entrada lenta
@export var fundido_musica_salida := 1.0
@export_group("Tiempos (s)")
@export var entrada := 0.8
@export var duracion_tarjeta := 4.0
@export var salida := 0.8
@export var pausa_inicial := 0.6
@export_group("")
@export var color_texto := Color(0.96, 0.93, 0.85)
@export_file("*.tscn") var escena_siguiente := "res://scenes/main_menu.tscn"   ## vacío = no cambiar de escena (tests)

var tarjeta_actual := -1   # índice del integrante en pantalla (nombres.size() = cierre)
var _saltar := false
var _saliendo := false
var _player_musica: AudioStreamPlayer

@onready var tarjeta: Control = $Centro/Tarjeta
@onready var icono = $Centro/Tarjeta/Icono   # form_icon.gd
@onready var nombre: Label = $Centro/Tarjeta/Nombre
## Nombres animados en loop (anim_frames_ui.gd): el nodo `NombreAnim<i>` reemplaza al texto del integrante i.
@onready var nombres_anim: Array[TextureRect] = _buscar_nombres_anim()
@onready var filete: ColorRect = $Centro/Tarjeta/Filete
@onready var titulo_anim: TextureRect = $Centro/Tarjeta/Titulo   # el título animado del menú (anim_frames_ui.gd)
@onready var linea_institucion: Label = $Centro/Tarjeta/Institucion
@onready var rol: Label = $Centro/Tarjeta/Rol
@onready var contacto: Label = $Centro/Tarjeta/Contacto


func _buscar_nombres_anim() -> Array[TextureRect]:
	var r: Array[TextureRect] = []
	for i in nombres.size():
		r.append(get_node_or_null("Centro/Tarjeta/NombreAnim%d" % i) as TextureRect)
	return r


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	icono.color_icono = color_texto
	tarjeta.modulate.a = 0.0
	_iniciar_musica()
	_secuencia()


func _iniciar_musica() -> void:
	if musica == null:
		return
	_player_musica = AudioStreamPlayer.new()
	_player_musica.stream = musica
	_player_musica.volume_db = -60.0
	_player_musica.bus = &"Musica" if AudioServer.get_bus_index(&"Musica") >= 0 else &"Master"
	add_child(_player_musica)
	_player_musica.play()
	create_tween().tween_property(_player_musica, "volume_db", volumen_musica_db, fundido_musica).set_trans(Tween.TRANS_SINE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_ir_al_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("attack") or event.is_action_pressed("jump"):
		_saltar = true
		get_viewport().set_input_as_handled()


func _secuencia() -> void:
	await _espera(pausa_inicial)
	for i in nombres.size():
		tarjeta_actual = i
		icono.visible = true
		titulo_anim.visible = false
		filete.visible = true
		for k in nombres_anim.size():
			if nombres_anim[k] != null:
				nombres_anim[k].visible = k == i
		nombre.visible = i >= nombres_anim.size() or nombres_anim[i] == null
		icono.forma = formas[i] if i < formas.size() else 0
		nombre.text = nombres[i]
		linea_institucion.text = institucion
		rol.text = roles[i] if i < roles.size() else ""
		contacto.text = contactos[i] if i < contactos.size() else ""
		await _mostrar_tarjeta()
		if _saliendo:
			return
	tarjeta_actual = nombres.size()
	icono.visible = false
	for n in nombres_anim:
		if n != null:
			n.visible = false
	nombre.visible = false   # en el cierre va el título animado del menú, no texto
	titulo_anim.visible = true
	filete.visible = false   # la línea de abajo no va con el título
	linea_institucion.text = texto_cierre
	rol.text = ""
	contacto.text = creditos_musica
	await _mostrar_tarjeta()
	terminada.emit()
	_ir_al_menu()


func _mostrar_tarjeta() -> void:
	_saltar = false
	var t := create_tween()
	t.tween_property(tarjeta, "modulate:a", 1.0, entrada).set_trans(Tween.TRANS_SINE)
	await _espera(entrada + duracion_tarjeta, true)
	var t2 := create_tween()
	t2.tween_property(tarjeta, "modulate:a", 0.0, salida).set_trans(Tween.TRANS_SINE)
	await _espera(salida)


## Espera en tiempo real; con `saltable`, Enter/ataque la corta.
func _espera(seg: float, saltable: bool = false) -> void:
	var t := 0.0
	while t < seg and not _saliendo:
		if saltable and _saltar:
			return
		await get_tree().process_frame
		t += get_process_delta_time()


func _ir_al_menu() -> void:
	if _saliendo:
		return
	_saliendo = true
	if _player_musica != null:
		create_tween().tween_property(_player_musica, "volume_db", -60.0, fundido_musica_salida)
	if escena_siguiente.is_empty():
		return
	TransicionPantalla.de(get_tree()).cambiar_escena(escena_siguiente)
