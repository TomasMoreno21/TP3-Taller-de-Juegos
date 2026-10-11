extends CanvasLayer

## Autoload "Dialogo": el Amuleto habla con globos de cómic junto al jugador, SIN frenar el juego,
## y una lista de tareas (tutorial / objetivos) que se tachan solas.
##
## Uso:
##   Dialogo.mostrar(["línea 1", "[alerta]línea 2"], "Amuleto")   # narrativa (globos en cadena)
##   Dialogo.mostrar_tip(["texto"])                                # consejo corto (globo chico)
##   Dialogo.lista_agregar("id", "Saltá con {jump}")               # tarea en la lista
##   Dialogo.lista_completar("id")
## Etiquetas de tono al inicio de una línea: [alerta] [grito] [susurro].
## `marcado` (escenas importantes): globo más grande y un instante de cámara lenta.

signal dialogo_terminado
## El jugador hizo por primera vez una acción (mover, saltar, golpe_ligero, golpe_fuerte, bloquear, parry, transformar).
signal accion_hecha(clave: String)

enum Fase { LIBRE, ESCRIBIENDO, LEYENDO, SALIENDO }

const AJUSTES := "user://ajustes.cfg"
const NOMBRES_AYUDA := ["Ninguna", "Ligera", "Completa"]

const SEG_POR_CARACTER := 0.016
const LIMITE_TROZO := 44   ## un texto más largo se parte en globos cortos

@export var volumen_tipeo_db := -9.0     ## volumen del "blip" de cada letra al escribir
@export var letras_por_sonido := 2       ## cada cuántas letras suena (espacios y signos no cuentan)
@export var radio_peligro := 480.0       ## enemigos más cerca que esto → el globo se hace chico y translúcido
@export var seg_tras_dano := 1.5         ## tras recibir daño el globo sigue chico este tiempo
@export var seg_calma_tras_dano := 2.0   ## el Amuleto espera este tiempo sin daño para hablar
@export var seg_entre_charlas := 7.0     ## respiro mínimo entre una charla y la siguiente (no se pisan ni se encadenan)
@export var seg_charla_vence := 30.0     ## una charla que esperó más que esto ya no viene al caso (el jugador siguió de largo) y se descarta
@export var seg_tip_vence := 25.0        ## un consejo que esperó la calma más que esto ya no tiene sentido y se descarta
@export_group("Game feel del globo")
@export var flotacion_px := 3.0          ## cuánto sube y baja el globo mientras está en pantalla
@export var inercia_globo := 9.0         ## qué tan rápido alcanza al jugador (menor = más retraso y cola más estirada)
@export var inclinacion_max := 0.05      ## rad: el globo se inclina hacia donde lo arrastra el movimiento
@export var pausa_coma := 0.10           ## s de pausa al escribir "," ";" ":"
@export var pausa_frase := 0.22          ## s de pausa al escribir "." "!" "?" "…"
@export var sacudida_alerta := 3.0       ## temblor de cámara al aparecer un globo de ALERTA (0 = sin)
@export var sacudida_grito := 5.0        ## ídem para GRITO
@export var tono_voz_amuleto := 1.0      ## pitch base del blip al escribir (cada tipo de globo lo modifica)
@export var tono_voz_humano := 0.85
@export_group("")

var _cola: Array[Dictionary] = []
var _en_espera: Array[Dictionary] = []   # charlas y consejos que esperan un lugar sin acción
var _t_calma := 0.0
var _fase := Fase.LIBRE
var _item: Dictionary = {}
var _espera := 0.0
var _ratio := 0.0
var _texto_actual := ""
var _idx_c := 0            ## letras ya escritas del globo actual
var _acum := 0.0           ## tiempo acumulado hacia la próxima letra
var _pausa := 0.0          ## pausa de puntuación en curso
var _globo_pos := Vector2.ZERO   ## posición con inercia del globo (la real sigue al jugador con retraso)
var _globo_nuevo := true
var _letras_sin_sonar := 0
var _chico := 0.0          ## 0 = normal … 1 = compacto (peligro)
var _chico_objetivo := 0.0
var _peligro_t := 0.0
var _ultimo_dano := -99.0
var _t := 0.0
var _gema_pos := Vector2.ZERO
var _gema_a := 0.0
var _jugador: Node2D
var _tw_globo: Tween
var _tw_gema: Tween

## true si lo último que tocó el jugador fue un joystick: los tokens {accion} del
## texto se muestran como botones del mando; si no, como teclas.
var _usa_joypad := false
## Cuánta ayuda quiere el jugador: 0 = Ninguna, 1 = Ligera (lista sin pistas ni comentarios), 2 = Completa.
var nivel_ayuda := 2
var _t_fin_charla := -99.0   ## reloj interno en que terminó la última charla de historia
var t_ultimo_globo := -99.0   ## reloj interno del último globo (lo usan las reacciones para no hablar de más)
var _t_ultima_accion := 0.0
var _pulso_gema := 0.0
var _re_token := RegEx.create_from_string("\\{(\\w+)\\}")
var _re_tag := RegEx.create_from_string("^\\[(\\w+)\\]\\s*")
var _re_frase := RegEx.create_from_string("(?<=[.!?…])\\s+")

const NOMBRES_BOTON := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Select", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_DPAD_UP: "cruceta ↑", JOY_BUTTON_DPAD_DOWN: "cruceta ↓",
	JOY_BUTTON_DPAD_LEFT: "cruceta ←", JOY_BUTTON_DPAD_RIGHT: "cruceta →",
}
const NOMBRES_EJE := {
	JOY_AXIS_LEFT_X: "joystick izquierdo", JOY_AXIS_LEFT_Y: "joystick izquierdo",
	JOY_AXIS_RIGHT_X: "joystick derecho", JOY_AXIS_RIGHT_Y: "joystick derecho",
	JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT",
}
## Tokens que agrupan varias acciones (movimiento en ejes): en el mando se nombra
## el joystick, en teclado se listan las teclas de cada acción ("A / D").
const ALIAS := {
	"mover": ["move_left", "move_right"],
	"trepar": ["move_up", "move_down"],
	"camara": ["cam_izq", "cam_der", "cam_arr", "cam_abj"],
}
const NOMBRES_TECLA := {
	"Space": "Espacio", "Enter": "Enter", "Escape": "Esc", "Shift": "Shift",
	"Up": "↑", "Down": "↓", "Left": "←", "Right": "→", "Ctrl": "Ctrl", "Tab": "Tab",
}

@onready var gema: Control = $Gema
@onready var globo: Control = $Globo
@onready var lista: Control = $Lista


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 85
	globo.visible = false
	gema.modulate.a = 0.0
	gema.visible = false
	_cargar_ajustes()
	# Con un mando conectado los textos nombran sus botones desde el inicio (sin esperar un toque).
	_usa_joypad = not Input.get_connected_joypads().is_empty()
	Input.joy_connection_changed.connect(func(_id: int, conectado: bool) -> void:
		if conectado:
			_usa_joypad = true)


## El diálogo ya no bloquea el control del jugador (se sigue jugando mientras habla).
## Se conserva por compatibilidad con quien pregunta si debe frenar el input.
func esta_activo() -> bool:
	return false


## True si hay un globo de narrativa en pantalla o en cola (los tips se callan en ese caso).
func hay_narrativa() -> bool:
	if _fase != Fase.LIBRE and not bool(_item.get("tip", false)):
		return true
	for it in _cola:
		if not bool(it.get("tip", false)):
			return true
	for w in _en_espera:
		if bool(w["narr"]):
			return true
	return false


func texto_actual() -> String:
	return _texto_actual


func mostrar(lineas: Array, hablante: String = "Amuleto", marcado: bool = false) -> void:
	if not marcado and (not _es_calma() or _charla_reciente()):
		_en_espera.append({"narr": true, "lineas": lineas, "hablante": hablante, "t": _t})
		return
	_quitar_tips()
	for l in lineas:
		for it in _armar(String(l), hablante, false, marcado):
			_cola.append(it)
	if _fase != Fase.LIBRE and bool(_item.get("tip", false)):
		_cortar_actual()
	elif _fase == Fase.LIBRE:
		_siguiente()


## Consejo corto, sin bloquear: globo chico. Se ignora si hay narrativa en curso.
func mostrar_tip(lineas: Array, hablante: String = "Amuleto", guardar_en_ayuda: bool = true) -> void:
	if hay_narrativa() or nivel_ayuda == 0:
		return
	if not _es_calma():
		for w in _en_espera:
			if not bool(w["narr"]) and w["lineas"] == lineas:
				return
		_en_espera.append({"narr": false, "lineas": lineas, "hablante": hablante, "guardar": guardar_en_ayuda, "t": _t})
		return
	if guardar_en_ayuda:
		for l in lineas:
			_registrar_ayuda(String(l))
	for l in lineas:
		for it in _armar(String(l), hablante, true, false):
			_cola.append(it)
	if _fase == Fase.LIBRE:
		_siguiente()


func _quitar_tips() -> void:
	var resto: Array[Dictionary] = []
	for it in _cola:
		if not bool(it.get("tip", false)):
			resto.append(it)
	_cola = resto


## Separa la etiqueta de tono y parte los textos largos en globos cortos.
func _armar(linea: String, hablante: String, tip: bool, marcado: bool) -> Array[Dictionary]:
	var tono := 0
	var m := _re_tag.search(linea)
	while m != null:   # se pueden combinar: "[humano][susurro] ..."
		match m.get_string(1).to_lower():
			"alerta": tono = 1
			"grito": tono = 2
			"susurro": tono = 3
			"humano": hablante = "Humano"   # habla el jugador: el globo sale de su cabeza, no de la gema
		linea = linea.substr(m.get_end())
		m = _re_tag.search(linea)
	var trozos: Array[String] = []
	var actual := ""
	for fr in _re_frase.sub(linea, "\n", true).split("\n"):
		if actual.is_empty():
			actual = fr
		elif actual.length() + fr.length() + 1 <= LIMITE_TROZO:
			actual += " " + fr
		else:
			trozos.append(actual)
			actual = fr
	if not actual.is_empty():
		trozos.append(actual)
	var res: Array[Dictionary] = []
	for t in trozos:
		res.append({"texto": t, "hablante": hablante, "tono": tono, "tip": tip, "marcado": marcado})
	return res


func _siguiente() -> void:
	if _cola.is_empty():
		var era_narrativa := not _item.is_empty() and not bool(_item.get("tip", false))
		_fase = Fase.LIBRE
		_item = {}
		_texto_actual = ""
		_ocultar_gema_luego()
		if era_narrativa:
			_t_fin_charla = _t
			dialogo_terminado.emit()
		return
	_item = _cola.pop_front()
	t_ultimo_globo = _t
	var marcado: bool = bool(_item.get("marcado", false))
	var tip: bool = bool(_item.get("tip", false))
	_texto_actual = _tokens(String(_item["texto"]))
	var tam := 20 if tip else (30 if marcado else 24)
	var ancho := 380.0 if tip else (520.0 if marcado else 420.0)
	var tono_i: int = int(_item["tono"])
	if marcado and tono_i == 0:
		tono_i = 2 if String(_item["texto"]).contains("!") else 1
	globo.configurar(_texto_actual, str(_item.get("hablante", "Amuleto")), tono_i, tam, ancho)
	_ratio = 0.0
	_idx_c = 0
	_acum = 0.0
	_pausa = 0.0
	_letras_sin_sonar = 0
	_fase = Fase.ESCRIBIENDO
	_globo_nuevo = true
	globo.rotation = 0.0
	_colocar()
	globo.visible = true
	globo.modulate.a = 0.0
	if _tw_globo != null and _tw_globo.is_valid():
		_tw_globo.kill()
	if DisplayServer.get_name() == "headless":
		globo.modulate.a = 1.0
	else:
		_entrada_globo(tono_i, marcado)
	_pulso_gema = 0.5
	_mostrar_gema()
	if marcado:
		var hs := get_node_or_null("/root/Hitstop")
		if hs != null and DisplayServer.get_name() != "headless":
			hs.slowmo(0.5, 0.4)


## El globo nace en la punta de la cola (su pivote): crece, se pasa un poco (estirado a lo alto) y asienta con resorte.
## ALERTA y GRITO llegan con más golpe y un temblor de cámara corto.
func _entrada_globo(tono_i: int, marcado: bool) -> void:
	var fuerte := tono_i >= 1 or marcado
	var pico := Vector2(1.08, 1.2) if fuerte else Vector2(0.96, 1.1)
	var final := Vector2.ONE * lerpf(1.0, 0.78, _chico)
	globo.scale = Vector2(0.3, 0.3)
	_tw_globo = create_tween().set_parallel(true)
	_tw_globo.tween_property(globo, "modulate:a", 1.0, 0.09)
	_tw_globo.tween_property(globo, "scale", pico, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw_globo.chain().tween_property(globo, "scale", final, 0.38).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var fuerza := sacudida_grito if tono_i == 2 else (sacudida_alerta if tono_i == 1 else 0.0)
	var cam := get_viewport().get_camera_2d()
	if fuerza > 0.0 and cam != null and cam.has_method("shake"):
		cam.call("shake", fuerza, 0.2)


## Corta el globo actual al instante (cuando entra una narrativa encima de un tip).
func _cortar_actual() -> void:
	if _tw_globo != null and _tw_globo.is_valid():
		_tw_globo.kill()
	globo.visible = false
	_fase = Fase.LIBRE
	_siguiente()


func _salir() -> void:
	_fase = Fase.SALIENDO
	if _tw_globo != null and _tw_globo.is_valid():
		_tw_globo.kill()
	_tw_globo = create_tween().set_parallel(true)
	# se repliega hacia la gema (el pivote es la punta de la cola) y se desvanece
	_tw_globo.tween_property(globo, "modulate:a", 0.0, 0.2).set_delay(0.04)
	_tw_globo.tween_property(globo, "scale", Vector2(0.45, 0.45), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tw_globo.chain().tween_callback(func() -> void:
		globo.visible = false
		_siguiente())


func _mostrar_gema() -> void:
	gema.visible = true
	if _tw_gema != null and _tw_gema.is_valid():
		_tw_gema.kill()
	_tw_gema = create_tween()
	_tw_gema.tween_property(gema, "modulate:a", 1.0, 0.2)


func _ocultar_gema_luego() -> void:
	await get_tree().create_timer(0.5, false).timeout
	if _fase != Fase.LIBRE:
		return
	if _tw_gema != null and _tw_gema.is_valid():
		_tw_gema.kill()
	_tw_gema = create_tween()
	_tw_gema.tween_property(gema, "modulate:a", 0.0, 0.35)
	_tw_gema.tween_callback(func() -> void:
		if _fase == Fase.LIBRE:
			gema.visible = false)


func _process(delta: float) -> void:
	_t += delta
	_rastrear_acciones()
	_revisar_espera(delta)
	_pulso_gema = maxf(_pulso_gema - delta * 2.0, 0.0)
	if _fase == Fase.LIBRE and not gema.visible:
		return
	_actualizar_peligro(delta)
	_colocar()
	if _fase == Fase.ESCRIBIENDO:
		_escribir(delta)
	elif _fase == Fase.LEYENDO:
		_espera -= delta
		if _espera <= 0.0:
			_salir()
	var r := gema.get_node_or_null("Retrato")
	if r != null and r.has_method("set_hablando"):
		r.set_hablando(_fase == Fase.ESCRIBIENDO)


func _escribir(delta: float) -> void:
	var total: int = maxi(_texto_actual.length(), 1)
	if _pausa > 0.0:
		_pausa -= delta
		return
	var tono_i := int(_item.get("tono", 0))
	var seg := SEG_POR_CARACTER * (1.3 if tono_i == 3 else (0.8 if tono_i == 2 else 1.0))   # susurro lento, grito rápido
	_acum += delta
	var sonar := false
	while _acum >= seg and _idx_c < total:
		_acum -= seg
		var c := _texto_actual[_idx_c]
		_idx_c += 1
		if c.to_lower() != c.to_upper() or c.is_valid_int():
			globo.golpe_letra()
			_letras_sin_sonar += 1
			if _letras_sin_sonar >= maxi(letras_por_sonido, 1):
				_letras_sin_sonar = 0
				sonar = true
		if _idx_c < total and _texto_actual[_idx_c] == " ":   # respira al final de cada cláusula
			if c in [",", ";", ":"]:
				_pausa = pausa_coma
			elif c in [".", "!", "?", "…"]:
				_pausa = pausa_frase
			if _pausa > 0.0:
				_acum = 0.0
				break
	_ratio = float(_idx_c) / float(total)
	globo.set_ratio(_ratio)
	if sonar:
		_blip(tono_i)
	if _idx_c >= total:
		_fase = Fase.LEYENDO
		_espera = maxf(1.2 if not bool(_item.get("tip", false)) else 1.6, total * 0.04)


## Sonido de cada letra: la voz del Humano es más grave y el tono del globo la sube o la baja
## (susurro grave y suave, alerta y grito agudos); un poco de variación para que no suene a máquina.
func _blip(tono_i: int) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio == null or not ResourceLoader.exists("res://assets/audio/sfx/gen/dialogo_tecla.wav"):
		return
	var base := tono_voz_humano if str(_item.get("hablante", "")) == "Humano" else tono_voz_amuleto
	var por_tono: float = [1.0, 1.12, 1.28, 0.82][clampi(tono_i, 0, 3)]
	var vol := volumen_tipeo_db + (-4.0 if tono_i == 3 else (2.0 if tono_i == 2 else 0.0))
	audio.play_sfx(load("res://assets/audio/sfx/gen/dialogo_tecla.wav"), vol, 0.05, base * por_tono)


## Sigue al jugador: la gema flota detrás de su hombro y el globo va encima, dentro de la pantalla.
func _colocar() -> void:
	var vp := get_viewport().get_visible_rect().size
	var centro := Vector2(vp.x * 0.5, vp.y * 0.6)
	var mirando := 1.0
	if not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("player") as Node2D
		if _jugador != null:
			_conectar_jugador(_jugador)
	if is_instance_valid(_jugador):
		centro = get_viewport().get_canvas_transform() * _jugador.global_position
		var f: Variant = _jugador.get("facing")
		mirando = float(f) if f != null else 1.0
	var objetivo := centro + Vector2(-mirando * 85.0, -215.0) + Vector2(0, sin(_t * 2.2) * 6.0)
	if _gema_pos == Vector2.ZERO:
		_gema_pos = objetivo
	_gema_pos = _gema_pos.lerp(objetivo, clampf(get_process_delta_time() * 6.0, 0.0, 1.0))
	_gema_pos.x = clampf(_gema_pos.x, 60.0, vp.x - 60.0)
	_gema_pos.y = clampf(_gema_pos.y, 90.0, vp.y - 60.0)
	gema.position = _gema_pos - gema.size * 0.5
	gema.pivot_offset = gema.size * 0.5
	gema.scale = Vector2.ONE * (1.0 + 0.35 * sin(_pulso_gema * PI))
	if not globo.visible:
		return
	var esc := lerpf(1.0, 0.78, _chico)
	globo.self_modulate.a = lerpf(1.0, 0.55, _chico)   # translúcido en peligro (sin pisar el fundido de entrada/salida)
	var tam := globo.size
	var pos := _gema_pos + Vector2(-tam.x * 0.3, -tam.y - 62.0)
	pos.x = clampf(pos.x, 24.0, maxf(vp.x - tam.x - 24.0, 24.0))
	pos.y = clampf(pos.y, 24.0, maxf(vp.y - tam.y - 24.0, 24.0))
	var punta := _gema_pos + Vector2(0, -34.0)
	if str(_item.get("hablante", "")) == "Humano":
		var cabeza := centro + Vector2(0, -158.0)
		var lado := 0.12 if mirando >= 0.0 else 0.88   # el globo se abre hacia donde mira, lejos de la gema
		pos = cabeza + Vector2(-tam.x * lado, -tam.y - 52.0)
		pos.x = clampf(pos.x, 24.0, maxf(vp.x - tam.x - 24.0, 24.0))
		pos.y = clampf(pos.y, 24.0, maxf(vp.y - tam.y - 24.0, 24.0))
		punta = cabeza
	if _fase != Fase.SALIENDO:
		var dt := get_process_delta_time()
		pos += Vector2(0.0, sin(_t * 1.8) * flotacion_px)
		if _globo_nuevo:
			_globo_pos = pos
			_globo_nuevo = false
		else:
			_globo_pos = _globo_pos.lerp(pos, clampf(dt * inercia_globo, 0.0, 1.0))
		globo.position = _globo_pos.round()
		# se inclina hacia donde lo arrastra el movimiento y vuelve a la vertical al frenar
		var arrastre := clampf((pos.x - _globo_pos.x) * 0.0012, -inclinacion_max, inclinacion_max)
		globo.rotation = lerpf(globo.rotation, arrastre, clampf(dt * 10.0, 0.0, 1.0))
	if _tw_globo == null or not _tw_globo.is_running():
		globo.scale = Vector2.ONE * esc
	# la cola apunta a la gema (o a la cabeza) y se estira por el retraso; con el giro se pasa a coordenadas locales
	var pivote := globo.position + globo.pivot_offset
	globo.cola_a = globo.pivot_offset + (punta - pivote).rotated(-globo.rotation)


## Lugar sin acción: ningún enemigo cerca y sin daño reciente. El Amuleto habla (casi siempre) solo ahí,
## para que el jugador pueda leerlo sin que le moleste una pelea.
## True si hay una charla de historia en curso o terminó hace poco: la siguiente espera su turno.
func _charla_reciente() -> bool:
	if _fase != Fase.LIBRE and not bool(_item.get("tip", false)):
		return true
	for it in _cola:
		if not bool(it.get("tip", false)):
			return true
	return _t - _t_fin_charla < seg_entre_charlas


func _es_calma() -> bool:
	if not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(_jugador):
		return true
	if _t - _ultimo_dano < seg_calma_tras_dano:
		return false
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Node2D and is_instance_valid(e) and (e as Node2D).global_position.distance_to(_jugador.global_position) < radio_peligro:
			return false
	return true


func _revisar_espera(delta: float) -> void:
	if _en_espera.is_empty():
		return
	_t_calma -= delta
	if _t_calma > 0.0:
		return
	_t_calma = 0.3
	if not _es_calma():
		return
	var pendientes := _en_espera
	_en_espera = []
	for w in pendientes:
		if bool(w["narr"]):
			if _t - float(w["t"]) < seg_charla_vence:
				mostrar(w["lineas"], w["hablante"])
				if _charla_reciente() and not _en_espera.is_empty():
					_en_espera.back()["t"] = w["t"]   # si volvió a esperar, conserva su antigüedad
		elif _t - float(w["t"]) < seg_tip_vence:
			mostrar_tip(w["lineas"], w["hablante"], bool(w["guardar"]))


func _on_dano(_cant: int) -> void:
	_ultimo_dano = _t


func _actualizar_peligro(delta: float) -> void:
	_peligro_t -= delta
	if _peligro_t <= 0.0:
		_peligro_t = 0.25
		var cerca := _t - _ultimo_dano < seg_tras_dano
		if not cerca and is_instance_valid(_jugador):
			for e in get_tree().get_nodes_in_group("enemy"):
				if e is Node2D and is_instance_valid(e) and (e as Node2D).global_position.distance_to(_jugador.global_position) < radio_peligro:
					cerca = true
					break
		_chico_objetivo = 1.0 if cerca else 0.0
	_chico = move_toward(_chico, _chico_objetivo, delta * 3.0)



# --------------------------------------------------------------- lista de tareas

func lista_agregar(id: String, texto: String, total: int = 1) -> void:
	if lista != null:
		lista.agregar(id, _tokens(texto), total)
		_registrar_ayuda(texto)


func lista_marcar_actual(id: String) -> void:
	if lista != null:
		lista.marcar_actual(id)


func lista_progreso(id: String, cuenta: int) -> void:
	if lista != null:
		lista.progreso(id, cuenta)


func lista_completar(id: String) -> void:
	if lista != null:
		lista.completar(id)


func lista_existe(id: String) -> bool:
	return lista != null and lista.existe(id)


func lista_pista(id: String) -> void:
	if lista != null:
		lista.pista(id)


## Atenúa o devuelve la lista de tareas (cinemáticas: no debe tapar el encuadre).
func lista_ocultar(oculta: bool, seg := 0.4) -> void:
	if lista != null:
		create_tween().tween_property(lista, "modulate:a", 0.0 if oculta else 1.0, seg)


# --------------------------------------------------------------- acciones del jugador y ayuda

func _conectar_jugador(j: Node) -> void:
	if j.has_signal("dano_recibido") and not j.dano_recibido.is_connected(_on_dano):
		j.dano_recibido.connect(_on_dano)
		j.attack_performed.connect(_on_ataque)
		j.parry_exitoso.connect(func() -> void: hecho("parry"))
		j.form_changed.connect(func(_n: String) -> void: hecho("transformar"))


func _on_ataque(tipo: String, _paso: Variant) -> void:
	_t_ultima_accion = _t
	if tipo == "light":
		hecho("golpe_ligero")
	elif tipo == "heavy":
		hecho("golpe_fuerte")


func _rastrear_acciones() -> void:
	if get_tree().paused:
		return
	if absf(Input.get_axis("move_left", "move_right")) > 0.3:
		_t_ultima_accion = _t
		hecho("mover")
	if Input.is_action_just_pressed("jump"):
		_t_ultima_accion = _t
		hecho("saltar")
	if Input.is_action_pressed("block"):
		_t_ultima_accion = _t
		hecho("bloquear")


func hecho(clave: String) -> void:
	var prog := get_node_or_null("/root/Progresion")
	if prog == null or prog.acciones_hechas.has(clave):
		return
	prog.acciones_hechas[clave] = true
	accion_hecha.emit(clave)


func ya_hizo(clave: String) -> bool:
	var prog := get_node_or_null("/root/Progresion")
	return prog != null and prog.acciones_hechas.has(clave)


## Segundos desde que el jugador hizo algo (moverse, saltar, atacar, bloquear).
func segundos_inactivo() -> float:
	return _t - _t_ultima_accion


## La gema da un pulso breve (reconocimiento de un logro), aunque no esté hablando.
func celebrar() -> void:
	_pulso_gema = 1.0
	_mostrar_gema()
	_ocultar_gema_luego()


func _registrar_ayuda(texto: String) -> void:
	var prog := get_node_or_null("/root/Progresion")
	if prog == null:
		return
	var t := _tokens(texto)
	if not prog.ayuda_vista.has(t):
		prog.ayuda_vista.append(t)


func set_nivel_ayuda(n: int) -> void:
	nivel_ayuda = clampi(n, 0, 2)
	var cf := ConfigFile.new()
	cf.load(AJUSTES)
	cf.set_value("ayuda", "nivel", nivel_ayuda)
	cf.save(AJUSTES)


func _cargar_ajustes() -> void:
	var cf := ConfigFile.new()
	if cf.load(AJUSTES) == OK:
		nivel_ayuda = clampi(int(cf.get_value("ayuda", "nivel", 2)), 0, 2)


# --------------------------------------------------------------- entrada y tokens

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.4):
		_usa_joypad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		_usa_joypad = false
	# Enter (solo teclado) adelanta el globo; el mando no, para no chocar con salto/ataque.
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo \
			and (event as InputEventKey).keycode == KEY_ENTER and _fase != Fase.LIBRE and not get_tree().paused:
		if _fase == Fase.ESCRIBIENDO:
			_ratio = 1.0
			globo.set_ratio(1.0)
			_idx_c = _texto_actual.length()
			_pausa = 0.0
			_fase = Fase.LEYENDO
			_espera = 0.9
		elif _fase == Fase.LEYENDO:
			_espera = 0.0


## Reemplaza {accion} por la tecla o el botón asignado en el InputMap según el
## dispositivo que se está usando. Acciones desconocidas quedan como estaban.
func _tokens(texto: String) -> String:
	var salida := texto
	for m in _re_token.search_all(texto):
		var accion := m.get_string(1)
		if ALIAS.has(accion):
			salida = salida.replace(m.get_string(0), _nombre_alias(ALIAS[accion]))
		elif InputMap.has_action(accion):
			salida = salida.replace(m.get_string(0), nombre_accion(accion))
	return salida


func _nombre_alias(acciones: Array) -> String:
	var teclas: Array[String] = []
	var eje := ""
	for a in acciones:
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey:
				var k := ev as InputEventKey
				var n := OS.get_keycode_string(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
				n = NOMBRES_TECLA.get(n, n)
				if not teclas.has(n):
					teclas.append(n)
				break
		if eje.is_empty():
			for ev in InputMap.action_get_events(a):
				if ev is InputEventJoypadMotion:
					eje = NOMBRES_EJE.get((ev as InputEventJoypadMotion).axis, "joystick")
					break
	var teclado := " / ".join(teclas)
	if _usa_joypad or teclado.is_empty():
		return eje if not eje.is_empty() else teclado
	return teclado


func nombre_accion(accion: String) -> String:
	var teclado := ""
	var mando := ""
	for ev in InputMap.action_get_events(accion):
		if ev is InputEventKey and teclado.is_empty():
			var k := ev as InputEventKey
			var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			var n := OS.get_keycode_string(code)
			teclado = NOMBRES_TECLA.get(n, n)
		elif ev is InputEventMouseButton and teclado.is_empty():
			teclado = "clic izquierdo" if (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT else "clic derecho"
		elif ev is InputEventJoypadButton and mando.is_empty():
			mando = NOMBRES_BOTON.get((ev as InputEventJoypadButton).button_index, "botón")
		elif ev is InputEventJoypadMotion and mando.is_empty():
			mando = NOMBRES_EJE.get((ev as InputEventJoypadMotion).axis, "joystick")
	if _usa_joypad:
		return mando if not mando.is_empty() else teclado
	return teclado if not teclado.is_empty() else mando
