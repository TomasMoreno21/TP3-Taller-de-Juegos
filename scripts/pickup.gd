extends Area2D
## Alma recolectable: flota y late en reposo; al recogerla da energía + fragmento
## y deja un estallido azul con "pop" (el efecto vive aparte: el pickup se libera ya).

@export var flote_amplitud := 6.0        ## px de subida/bajada en reposo
@export var flote_velocidad := 2.2
@export var pulso_velocidad := 3.0       ## latido del halo y la luz
@export var color_burst := Color(0.45, 0.72, 1.0)
@export var sonido_recoger: AudioStream = preload("res://assets/audio/sfx/gen/pickup.wav")
@export var volumen_recoger_db := -8.0
@export var texto_recoger := "+1 alma"   ## texto flotante al recoger ("" = sin texto)
@export var iman_radio := 150.0         ## px: dentro de este radio el alma vuela hacia el jugador (0 = sin imán)
@export var iman_velocidad := 700.0      ## velocidad máxima del imán (px/s)
@export var iman_aceleracion := 1800.0
@export_group("Aspecto de alma")
@export var color_cabeza := Color(0.82, 0.94, 1.0, 0.95)   ## centro de la cabeza del espíritu
@export var color_borde := Color(0.38, 0.62, 1.0, 0.85)     ## contorno de la cabeza
@export var color_cola := Color(0.3, 0.5, 1.0, 0.0)         ## punta de la cola (se desvanece)
@export var radio_cabeza := 22.0
@export var largo_cola := 66.0
@export var oleaje_cola := 10.0              ## px que se mece la cola
@export var velocidad_oleaje := 3.2
@export_group("")
@export var da_subida_de_nivel := false   ## al recogerlo completa los fragmentos y sube de nivel (ajustar FRAGMENTOS_NIVEL en progresion.gd)
@export var recoger_radio := 50.0        ## px: si el imán la acerca tanto, se recoge aunque no toque el collider (planeo, formas chicas)

var _t := randf() * TAU
var _recogido := false
var _pos_inicial := Vector2.ZERO
var _base_visual := Vector2.ZERO
var _base_halo := Vector2.ZERO
var _alpha_halo := 1.0
var _energia_luz := 1.0
var _iman_vel := 0.0
var _jugador: Node2D

@onready var visual: Polygon2D = $Visual
@onready var halo: Sprite2D = get_node_or_null("Halo")
@onready var luz: PointLight2D = get_node_or_null("Luz")


func _clave() -> String:
	var escena := get_tree().current_scene
	return "%s|%s" % [escena.scene_file_path if escena != null else "", str(get_path())]


func _ready() -> void:
	var prog := get_node_or_null("/root/Progresion")
	if prog != null and prog.almas_recogidas.has(_clave()):
		queue_free()   # ya recogida en esta partida: no se vuelve a contar
		return
	_pos_inicial = global_position
	monitoring = true
	collision_mask = 4
	body_entered.connect(_on_body_entered)
	_base_visual = visual.position
	_dibujar_alma(0.0)
	if halo != null:
		_base_halo = halo.position
		_alpha_halo = halo.modulate.a
	if luz != null:
		_energia_luz = luz.energy


func _process(delta: float) -> void:
	if _recogido:
		return
	_t += delta
	if _jugador != null and is_instance_valid(_jugador) and global_position.distance_squared_to(_jugador.global_position) > 6250000.0:
		return   # lejos de la cámara: ni flote ni imán
	_atraer(delta)
	var dy := sin(_t * flote_velocidad) * flote_amplitud
	visual.position = _base_visual + Vector2(0, dy)
	_dibujar_alma(_t)
	var latido := 0.8 + 0.2 * sin(_t * pulso_velocidad)
	if halo != null:
		halo.position = _base_halo + Vector2(0, dy)
		halo.modulate.a = _alpha_halo * latido
	if luz != null:
		luz.energy = _energia_luz * latido


## Espíritu: cabeza redonda y una cola ondulante que se desvanece (como un alma suelta).
## El contorno se recalcula cada cuadro con un vaivén; los colores van por vértice (cabeza clara → cola transparente).
const _N_CABEZA := 9
const _N_COLA := 8


func _dibujar_alma(t: float) -> void:
	var cy := -radio_cabeza * 0.5
	_contorno(visual, radio_cabeza, largo_cola, oleaje_cola, t, 0.0, color_borde.lerp(color_cabeza, 0.15), color_borde, color_cola, 0.85)
	# Dos velos translúcidos más grandes que se mecen a otro ritmo: el alma parece flotar en su propia estela.
	var n := 0
	for v in visual.get_children():
		if v.name.begins_with("Velo"):
			n += 1
			_contorno(v as Polygon2D, radio_cabeza * (1.3 + 0.15 * n), largo_cola * (1.2 + 0.15 * n), oleaje_cola * (1.4 + 0.3 * n), t, 1.7 * n,
				Color(color_cabeza, 0.28), Color(color_borde, 0.2), Color(color_cola, 0.0), 1.0)
	var nucleo := visual.get_node_or_null("Nucleo") as Polygon2D
	if nucleo != null:
		nucleo.position = Vector2(0, cy)
		nucleo.scale = Vector2.ONE * (radio_cabeza / 15.0) * (1.0 + 0.08 * sin(t * pulso_velocidad))


## Contorno de espíritu (cabeza + cola ondulante) con color por vértice en `destino`.
func _contorno(destino: Polygon2D, radio: float, largo: float, oleaje: float, t: float, fase: float, c_cab: Color, c_borde: Color, c_cola: Color, opacidad: float) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var cy := -radio * 0.5
	for i in _N_CABEZA:   # semicírculo superior, de izquierda a derecha
		var a := PI + PI * float(i) / float(_N_CABEZA - 1)
		pts.append(Vector2(cos(a) * radio, cy + sin(a) * radio))
		cols.append(c_cab)
	var der := PackedVector2Array()
	var izq := PackedVector2Array()
	var cols_l := PackedColorArray()
	for k in range(1, _N_COLA + 1):
		var f := float(k) / float(_N_COLA)
		var ancho := radio * pow(1.0 - f, 0.75)
		var mece := sin(t * velocidad_oleaje + fase + f * 3.4) * oleaje * f
		var y := cy + f * largo
		der.append(Vector2(ancho + mece, y))
		izq.append(Vector2(-ancho + mece, y))
		var c := c_borde.lerp(c_cola, pow(f, 0.9))
		c.a *= opacidad
		cols_l.append(c)
	pts.append_array(der)
	cols.append_array(cols_l)
	for k in range(_N_COLA - 2, -1, -1):   # vuelve por el lado izquierdo (sin repetir la punta)
		pts.append(izq[k])
		cols.append(cols_l[k])
	destino.polygon = pts
	destino.vertex_colors = cols


## Imán suave: cerca del jugador el alma acelera hacia él (más rápido cuanto más cerca).
func _atraer(delta: float) -> void:
	if iman_radio <= 0.0:
		return
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("player") as Node2D
	var p := _jugador
	if p == null:
		return
	var d := (p.global_position + Vector2(0, -60)) - global_position
	var dist := d.length()
	if dist < iman_radio and dist > 1.0:
		_iman_vel = minf(_iman_vel + iman_aceleracion * delta, iman_velocidad)
		global_position += d / dist * minf(_iman_vel * delta, dist)
		if dist <= recoger_radio and p.has_method("recoger_energia"):
			_recoger(p)
	else:
		_iman_vel = 0.0


func _on_body_entered(body: Node2D) -> void:
	_recoger(body)


func _recoger(body: Node2D) -> void:
	if _recogido or not body.has_method("recoger_energia"):
		return
	_recogido = true
	body.recoger_energia()
	var prog: Node = get_node("/root/Progresion")
	prog.almas_recogidas[_clave()] = true
	prog.almas_pendientes.append(_clave())   # si morís antes del próximo checkpoint, se devuelve
	# El alma contribuye a subir de nivel (fragmentos → desbloqueo de combos).
	var nivel_antes: int = prog.nivel
	prog.add_fragmentos(1)
	if da_subida_de_nivel and prog.nivel == nivel_antes:   # si el fragmento ya cruzó el umbral, no se fuerza una segunda subida
		prog.forzar_subida()
	_efecto_recoger()
	# Se oculta en vez de liberarse: puede reaparecer si morís antes del próximo checkpoint.
	visible = false
	set_deferred("monitoring", false)
	add_to_group("alma_recogida")


## Vuelve a su lugar si ya no cuenta como recogida (ver Progresion.revertir_almas_pendientes).
func reaparecer() -> void:
	if not _recogido or get_node("/root/Progresion").almas_recogidas.has(_clave()):
		return
	_recogido = false
	_iman_vel = 0.0
	global_position = _pos_inicial
	visible = true
	set_deferred("monitoring", true)
	remove_from_group("alma_recogida")


func _efecto_recoger() -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_sfx(sonido_recoger, volumen_recoger_db, 0.08)
	if DisplayServer.get_name() == "headless":
		return
	Burst.emitir(self, visual.global_position, color_burst, 14)
	if texto_recoger != "":
		var lbl := Label.new()
		lbl.text = texto_recoger
		lbl.add_theme_font_size_override("font_size", 26)
		lbl.add_theme_color_override("font_color", color_burst.lightened(0.3))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		lbl.add_theme_constant_override("outline_size", 6)
		lbl.z_index = 20
		lbl.global_position = global_position + Vector2(-40, -70)
		var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
		destino.add_child(lbl)
		var tl := lbl.create_tween().set_parallel(true)
		tl.tween_property(lbl, "position:y", lbl.position.y - 60.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tl.tween_property(lbl, "modulate:a", 0.0, 0.7).set_delay(0.25)
		tl.chain().tween_callback(lbl.queue_free)
	# Copia del rombo + halo que se infla y desvanece donde estaba el alma.
	var fx := Node2D.new()
	fx.global_position = global_position
	fx.z_index = z_index + 1
	var rombo := visual.duplicate() as Polygon2D
	fx.add_child(rombo)
	var h: Sprite2D = null
	if halo != null:
		h = halo.duplicate() as Sprite2D
		fx.add_child(h)
	(get_tree().current_scene if get_tree().current_scene != null else get_parent()).add_child(fx)
	var tw := fx.create_tween().set_parallel(true)
	tw.tween_property(rombo, "scale", Vector2.ONE * 1.9, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(rombo, "modulate:a", 0.0, 0.2)
	if h != null:
		tw.tween_property(h, "scale", h.scale * 2.4, 0.3)
		tw.tween_property(h, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(fx.queue_free)
