extends CanvasLayer

const Jugador := preload("res://scripts/player.gd")

const SALIDA_DUR := 2.2
const GOLPES_MAX := 2
const FILA_PASO := 44.0

var _player: Node2D
var _idle_timer: Timer
var _top_timer: Timer
var _cola_avisos: Array[String] = []
var _filas: Array[RichTextLabel] = []
var _fila_tweens: Array[Tween] = []
var _historial: Array[String] = []
var _combo_base_pos: Vector2

@onready var info: RichTextLabel = $Margin/Info
@onready var combo_label: RichTextLabel = $ComboLabel
@onready var izquierda: Control = $Izquierda
@onready var derecha: Control = $Derecha
@onready var dial: Control = $Izquierda/Dial
@onready var hp_bar: ProgressBar = $Izquierda/Vida/HpBar
@onready var hp_bar_delayed: ProgressBar = $Izquierda/Vida/HpBarDelayed
@onready var hp_label: Label = $Izquierda/Vida/HpLabel
@onready var nivel_label: Label = $Derecha/Nivel
@onready var prog_bar: ProgressBar = $Derecha/ProgBar
@onready var prog_label: Label = $Derecha/ProgLabel
@onready var aviso: Label = $Aviso
@onready var racha_box: VBoxContainer = $Derecha/Racha
@onready var racha_valor: Label = $Derecha/Racha/Valor
@onready var flash_dano: ColorRect = $FlashDano
@onready var vineta_vida: TextureRect = $VinetaVida

@export var vineta_umbral := 0.3  # fracción de vida (0-1) a partir de la cual aparece la viñeta
@export var vineta_pulso_velocidad := 2.4
@export var vineta_alpha_min := 0.35
@export var vineta_alpha_max := 0.9
@export var vineta_fade_dur := 0.4
@onready var boss_bar: MarginContainer = $BossBar
@onready var boss_fill: ProgressBar = $BossBar/Panel/Col/Envoltura/Fill
@onready var boss_eco: ProgressBar = $BossBar/Panel/Col/Envoltura/FillEco   ## franja clara que baja con retraso tras un golpe
var _eco_tween: Tween
@onready var boss_valor: Label = $BossBar/Panel/Col/Fila/Valor
@onready var boss_pips: Array[PanelContainer] = [
	$BossBar/Panel/Col/Pips/P1,
	$BossBar/Panel/Col/Pips/P2,
	$BossBar/Panel/Col/Pips/P3,
]

var _flash_tween: Tween
var _energia_aviso_dado := false
var _prog_tween: Tween

@export var pop_fragmentos_escala := 1.35
@export var pop_fragmentos_color := Color(0.55, 0.8, 1.0)
## Con vida y energía llenas y sin combate, el HUD baja de opacidad para despejar la pantalla.
@export var auto_ocultar := true
@export var ocultar_tras := 3.0
@export_range(0.0, 1.0) var alpha_reposo := 0.45
var _hp_delayed_tween: Tween
var _hp_lleno := true
var _energia_llena := true
var _t_reposo := 0.0
var _boss: Node2D
var _boss_fill_style: StyleBoxFlat
var _pip_on_style: StyleBox
var _pip_off_style: StyleBox
var _vineta_activa := false
var _vineta_severidad := 0.0
var _vineta_fade_tween: Tween
var _racha_tween: Tween
var _hp_prev := 100
var _energia_prev := 100.0
var _racha_prev := 0
var _color_flash_base := Color(1, 0.1, 0.1, 0.0)
var _hp_tween: Tween
var _tween_idle: Tween
var _amb: Node
var _boss_tween: Tween
var _boss_hp_prev := -1


func _process(delta: float) -> void:
	if _player != null:
		dial.forma_actual = _player.current_form
		dial.set_cooldown(float(_player._cooldown_formas.get(_player.forma_seleccionada, 0.0)))
	_auto_ocultar(delta)
	if _vineta_activa:
		var onda := 0.0
		if _amb == null:
			_amb = get_node_or_null("/root/Ambiente")
		var amb := _amb
		if amb != null and float(amb.latido_severidad) > 0.02:
			# Late con el mismo pulso "lub-dub" que el cuerpo del jugador y el orbe de vida.
			onda = clampf(float(amb.latido) / maxf(float(amb.latido_severidad), 0.01), 0.0, 1.0)
		else:
			var vel := vineta_pulso_velocidad * (1.0 + _vineta_severidad)
			onda = (sin(Time.get_ticks_msec() * 0.001 * vel) + 1.0) * 0.5
		vineta_vida.modulate.a = lerpf(vineta_alpha_min, vineta_alpha_max, onda) * lerpf(0.5, 1.0, _vineta_severidad)

func _ready() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")

	_idle_timer = Timer.new()
	_idle_timer.wait_time = 1.5
	_idle_timer.one_shot = true
	_idle_timer.timeout.connect(_limpiar_idle)
	add_child(_idle_timer)

	_top_timer = Timer.new()
	_top_timer.wait_time = SALIDA_DUR
	_top_timer.one_shot = true
	_top_timer.timeout.connect(_fade_top)
	add_child(_top_timer)

	_crear_filas()
	_combo_base_pos = combo_label.position
	_color_flash_base = flash_dano.color

	var prog: Node = get_node("/root/Progresion")
	prog.fragmentos_cambiado.connect(_on_fragmentos)
	prog.nivel_cambiado.connect(_on_nivel)
	prog.nivel_subio.connect(_on_nivel_subio)
	prog.combo_desbloqueado.connect(_on_combo)
	prog.forma_desbloqueada_evento.connect(_on_forma_desbloqueada)

	hp_bar.max_value = 100
	if hp_bar_delayed != null:
		hp_bar_delayed.max_value = 100
		hp_bar_delayed.value = 100
	hp_bar.value = 100
	dial.set_energia(100.0)
	_prog_refresh()
	_connectar_player.call_deferred()
	_conectar_boss.call_deferred()


func _connectar_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	_player.form_changed.connect(_on_form_changed)
	_player.forma_selectada_cambiada.connect(_on_forma_selectada)
	_player.attack_performed.connect(_on_attack_performed)
	_player.health_changed.connect(_on_health_changed)
	_player.dano_recibido.connect(_on_dano_recibido)
	_player.energia_changed.connect(_on_energia_changed)
	_player.transformacion_agotada.connect(_on_agotada)
	_player.racha_changed.connect(_on_racha_changed)
	_player.parry_exitoso.connect(_on_parry)
	_player.transformacion_denegada.connect(func() -> void:
		if dial != null and dial.has_method("rechazo"):
			dial.rechazo()
	)
	_actualizar_dial()


# --- Barra del jefe (Arzobispo). Nodo propio arriba-centro, FUERA del bloque
# --- "Bars" (lección de layout del 13/09): las columnas del HUD son verticales.

func _conectar_boss() -> void:
	var boss := get_tree().get_first_node_in_group("boss")
	if boss == null or not ("salud_cambio" in boss):
		return
	_boss = boss
	boss.salud_cambio.connect(_on_boss_salud)
	boss.fase_cambio.connect(_on_boss_fase)
	if boss.has_signal("reiniciado"):
		boss.reiniciado.connect(_on_boss_reiniciado)
	_boss_fill_style = boss_fill.get_theme_stylebox("fill").duplicate()
	boss_fill.add_theme_stylebox_override("fill", _boss_fill_style)
	_pip_on_style = boss_pips[0].get_theme_stylebox("panel")
	_pip_off_style = boss_pips[2].get_theme_stylebox("panel")
	if bool(boss.get("_activo")):
		_boss_bar_mostrar(int(boss.get("health")), int(boss.get("vida_max")))
	else:
		boss_bar.visible = false


func _boss_bar_mostrar(hp: int, max_hp: int) -> void:
	var entra := not boss_bar.visible
	boss_bar.visible = true
	boss_fill.max_value = 1.0
	boss_fill.value = clampf(float(hp) / float(max_hp), 0.0, 1.0)
	boss_valor.text = str(hp)
	var frac := boss_fill.value
	if boss_eco != null:
		boss_eco.max_value = 1.0
		if entra or frac >= boss_eco.value:
			if _eco_tween != null and _eco_tween.is_valid():
				_eco_tween.kill()
			boss_eco.value = frac
		elif DisplayServer.get_name() != "headless":
			if _eco_tween != null and _eco_tween.is_valid():
				_eco_tween.kill()
			_eco_tween = create_tween()
			_eco_tween.tween_interval(0.4)
			_eco_tween.tween_property(boss_eco, "value", frac, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			boss_eco.value = frac
	if DisplayServer.get_name() == "headless":
		return
	if entra:
		# Entrada: se desliza desde arriba y se prende.
		if _boss_tween != null and _boss_tween.is_valid():
			_boss_tween.kill()
		boss_bar.pivot_offset = Vector2(boss_bar.size.x * 0.5, 0.0)
		boss_bar.modulate.a = 0.0
		boss_bar.scale = Vector2(1.0, 0.6)
		_boss_tween = create_tween().set_parallel(true)
		_boss_tween.tween_property(boss_bar, "modulate:a", 1.0, 0.4)
		_boss_tween.tween_property(boss_bar, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif _boss_hp_prev > hp:
		# Golpe recibido: el relleno destella y la barra "tiembla" un poco.
		boss_fill.self_modulate = Color(2.2, 2.2, 2.2)
		var tw := create_tween()
		tw.tween_property(boss_fill, "self_modulate", Color.WHITE, 0.15)
	_boss_hp_prev = hp


## La arena se reinició (moriste en la pelea): la barra del jefe se apaga y vuelve a entrar animada en la próxima.
func _on_boss_reiniciado() -> void:
	if _boss_tween != null and _boss_tween.is_valid():
		_boss_tween.kill()
	boss_bar.visible = false
	boss_bar.modulate.a = 1.0
	_boss_hp_prev = -1


func _on_boss_salud(hp: int, max_hp: int) -> void:
	_boss_bar_mostrar(hp, max_hp)
	if hp <= 0:
		if DisplayServer.get_name() == "headless":
			boss_bar.visible = false
			return
		# Salida: se apaga en 0.6 s en vez de desaparecer en seco.
		if _boss_tween != null and _boss_tween.is_valid():
			_boss_tween.kill()
		_boss_tween = create_tween()
		_boss_tween.tween_property(boss_bar, "modulate:a", 0.0, 0.6)
		_boss_tween.tween_callback(func() -> void:
			boss_bar.visible = false
			boss_bar.modulate.a = 1.0)


func _on_boss_fase(fase: int) -> void:
	# Los valores llegan del enum Fase del jefe (UNO=0, DOS=1, TRES=2).
	if _boss_fill_style != null:
		match fase:
			0:
				_boss_fill_style.bg_color = Color(0.35, 0.6, 0.42)
			1:
				_boss_fill_style.bg_color = Color(0.56, 0.34, 0.86)
			2:
				_boss_fill_style.bg_color = Color(0.8, 0.25, 0.2)
	for i in boss_pips.size():
		var style := _pip_on_style if i <= fase else _pip_off_style
		if style != null:
			boss_pips[i].add_theme_stylebox_override("panel", style)


func _on_fragmentos(_total: int) -> void:
	_prog_refresh()
	_pop_fragmentos()
	_t_reposo = 0.0


## "Pop" del contador al sumar un fragmento: crece, destella en azul y vuelve.
func _pop_fragmentos() -> void:
	if _prog_tween != null and _prog_tween.is_valid():
		_prog_tween.kill()
	prog_label.pivot_offset = Vector2(prog_label.size.x, prog_label.size.y * 0.5)
	prog_label.scale = Vector2.ONE * pop_fragmentos_escala
	prog_label.self_modulate = pop_fragmentos_color
	_prog_tween = create_tween().set_parallel(true)
	_prog_tween.tween_property(prog_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_prog_tween.tween_property(prog_label, "self_modulate", Color.WHITE, 0.5)


## Aviso arriba al centro para otros sistemas (checkpoint, arenas...).
func mostrar_aviso(texto: String) -> void:
	_aviso(texto)


func _on_nivel(_nuevo: int) -> void:
	_prog_refresh()
	_actualizar_dial()


func _on_combo(_form_index: int, combo_nombre: String) -> void:
	_aviso("¡%s desbloqueado!" % combo_nombre)


func _on_nivel_subio(nuevo_nivel: int) -> void:
	_aviso("¡NIVEL %d ALCANZADO!" % nuevo_nivel)
	var form_nombre := _forma_nueva(nuevo_nivel)
	if form_nombre != "":
		_aviso("¡%s DESBLOQUEADO!" % form_nombre)


func _forma_nueva(nuevo_nivel: int) -> String:
	var form_idx := nuevo_nivel - 1
	if form_idx <= 0:
		return ""
	var prog: Node = get_node("/root/Progresion")
	if prog != null and not prog.forma_desbloqueada(form_idx):
		return ""
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.forms.size() > form_idx:
		return str(player.forms[form_idx].form_name)
	return ""


func _on_forma_desbloqueada(form_index: int) -> void:
	_aviso("¡%s DESBLOQUEADO!" % _nombre_forma(form_index))
	_actualizar_dial()


func _nombre_forma(form_index: int) -> String:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.forms.size() > form_index:
		return str(player.forms[form_index].form_name)
	return ""


func _on_form_changed(form_name: String) -> void:
	_aviso("Forma: %s" % form_name)
	dial.forma_actual = _player.current_form
	dial.pulso_transformacion()
	_t_reposo = 0.0


## Sincroniza el dial con el estado actual del jugador (colores de forma, selección, energía).
func _actualizar_dial() -> void:
	if _player == null:
		return
	var cols: Array = []
	for f in _player.forms:
		cols.append(f.color)
	dial.set_formas(cols)
	dial.forma_actual = _player.current_form
	dial.fijar_seleccion(_player.forma_seleccionada, false)
	dial.set_energia(_player.energia, _player.ENERGIA_MAX)


## Reposo: con todo lleno y sin actividad, el HUD baja de opacidad.
func _en_reposo() -> bool:
	return _hp_lleno and _energia_llena and not racha_box.visible \
		and _player.forma_seleccionada == _player.current_form \
		and _player._cooldown_formas.is_empty()


func _auto_ocultar(delta: float) -> void:
	if not auto_ocultar or _player == null or not _en_reposo():
		_t_reposo = 0.0
	else:
		_t_reposo += delta
	var objetivo := alpha_reposo if _t_reposo >= ocultar_tras else 1.0
	var vel := 2.0 if objetivo < 1.0 else 8.0
	var a := lerpf(izquierda.modulate.a, objetivo, minf(vel * delta, 1.0))
	izquierda.modulate.a = a
	derecha.modulate.a = a


func _on_racha_changed(cantidad: int) -> void:
	_t_reposo = 0.0
	if cantidad >= 2:
		racha_valor.text = str(cantidad)
		racha_box.visible = true
		if cantidad != _racha_prev:
			_pop_racha(cantidad)
	else:
		if _racha_prev >= 2:
			_romper_racha(_racha_prev)
		racha_box.visible = false
	_racha_prev = cantidad


## Al perder la racha el número no desaparece en seco: se agranda, cae y se desvanece (copia fantasma).
func _romper_racha(cantidad: int) -> void:
	if DisplayServer.get_name() == "headless" or racha_valor == null:
		return
	var g := Label.new()
	g.text = str(cantidad)
	g.label_settings = racha_valor.label_settings
	g.add_theme_font_size_override("font_size", racha_valor.get_theme_font_size("font_size"))
	g.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	g.top_level = true
	g.z_index = 20
	add_child(g)
	g.global_position = racha_valor.global_position
	g.pivot_offset = g.get_minimum_size() * 0.5   # el Label aún no tiene tamaño: se usa el mínimo para escalar desde el centro
	var tw := g.create_tween().set_parallel(true)
	tw.tween_property(g, "scale", Vector2.ONE * 1.5, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(g, "global_position:y", g.global_position.y + 34.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(g, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(g.queue_free)


## Pop de escala del indicador de racha al alcanzar hitos de combo (3 y 5).
func _pop_racha(cantidad: int) -> void:
	if racha_box == null:
		return
	if _racha_tween != null and _racha_tween.is_valid():
		_racha_tween.kill()
	var base := Vector2.ONE * (1.2 if cantidad == 5 or cantidad >= 8 else 1.0)
	racha_box.pivot_offset = Vector2(racha_box.size.x, 0.0)
	racha_box.scale = base * 0.7
	_racha_tween = create_tween()
	_racha_tween.tween_property(racha_box, "scale", base * 1.15, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_racha_tween.tween_property(racha_box, "scale", base, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_forma_selectada(index: int) -> void:
	dial.fijar_seleccion(index)
	_t_reposo = 0.0


func _crear_filas() -> void:
	_filas = [combo_label]
	_fila_tweens = [null]
	combo_label.visible = false
	for i in range(1, GOLPES_MAX):
		var f := RichTextLabel.new()
		f.bbcode_enabled = true
		f.scroll_active = false
		f.add_theme_font_size_override("normal_font_size", 34)
		f.vertical_alignment = 1
		f.horizontal_alignment = 2
		f.anchor_left = 1.0
		f.anchor_right = 1.0
		f.anchor_top = 1.0
		f.anchor_bottom = 1.0
		f.offset_left = -560.0
		f.offset_right = -160.0
		f.offset_top = -80.0 - i * FILA_PASO
		f.offset_bottom = -32.0 - i * FILA_PASO
		f.modulate.a = 0.0
		f.visible = false
		add_child(f)
		_filas.append(f)
		_fila_tweens.append(null)


func _on_attack_performed(_attack_type: String, _step: Variant) -> void:
	if _tween_idle != null and _tween_idle.is_valid():
		# Un golpe nuevo cancela el fade de salida: si no, terminaba y borraba el golpe recién hecho.
		_tween_idle.kill()
		_filas[0].position = _combo_base_pos
	_idle_timer.start()
	_t_reposo = 0.0
	var txt := _texto_ataque(_attack_type, _step)
	_historial.push_front(txt)
	if _historial.size() > GOLPES_MAX:
		_historial.pop_back()
	_pintar_golpes()


func _pintar_golpes() -> void:
	for i in range(GOLPES_MAX):
		var fila: RichTextLabel = _filas[i]
		if i >= _historial.size():
			fila.text = ""
			fila.visible = false
			continue
		fila.text = _historial[i]
		fila.visible = true
		if _fila_tweens[i] != null:
			_fila_tweens[i].kill()
			_fila_tweens[i] = null
		if i == 0:
			_fila_tweens[i] = create_tween()
			_fila_tweens[i].tween_property(fila, "modulate:a", 1.0, 0.25)
		else:
			fila.modulate.a = 1.0
			_fila_tweens[i] = create_tween()
			_fila_tweens[i].tween_interval(0.25)
			_fila_tweens[i].tween_property(fila, "modulate:a", 0.0, 0.25)


func _texto_ataque(_attack_type: String, _step: Variant) -> String:
	if _attack_type == "combo":
		return "[color=#ffd76a]%s[/color]" % str(_step)
	var nombre := "LIGERO" if _attack_type == "light" else ("FUERTE" if _attack_type == "heavy" else "ESPECIAL")
	return "[color=#ffd76a]%s[/color]" % nombre


func _on_health_changed(hp: int, max_hp: int) -> void:
	if hp > _hp_prev and _hp_prev > 0 and DisplayServer.get_name() != "headless":
		_pulso_curacion()
	_hp_prev = hp
	_actualizar_vineta(hp, max_hp)
	_hp_lleno = hp >= max_hp
	_t_reposo = 0.0
	hp_label.text = "%d/%d" % [hp, max_hp]
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	if hp_bar_delayed != null:
		hp_bar_delayed.max_value = max_hp
		if hp < hp_bar_delayed.value:
			if _hp_delayed_tween != null and _hp_delayed_tween.is_valid():
				_hp_delayed_tween.kill()
			_hp_delayed_tween = create_tween()
			_hp_delayed_tween.tween_interval(0.35)
			_hp_delayed_tween.tween_property(hp_bar_delayed, "value", hp, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			if _hp_delayed_tween != null and _hp_delayed_tween.is_valid():
				_hp_delayed_tween.kill()
			hp_bar_delayed.value = hp


func _actualizar_vineta(hp: int, max_hp: int) -> void:
	if vineta_vida == null or max_hp <= 0 or vineta_umbral <= 0.0:
		return
	var frac: float = float(hp) / float(max_hp)
	var activa := hp > 0 and frac <= vineta_umbral
	_vineta_severidad = clampf(1.0 - frac / vineta_umbral, 0.0, 1.0)
	if activa == _vineta_activa:
		return
	_vineta_activa = activa
	if _vineta_fade_tween != null and _vineta_fade_tween.is_valid():
		_vineta_fade_tween.kill()   # también al reactivarse: si no, el fade viejo pelea con el latido
	if not activa:
		_vineta_fade_tween = create_tween()
		_vineta_fade_tween.tween_property(vineta_vida, "modulate:a", 0.0, vineta_fade_dur)


func _on_dano_recibido(_cantidad: int) -> void:
	_flash_pantalla(_color_flash_base, 0.3, 0.35)


## Destello de pantalla completa (rojo al daño, celeste en el parry, verde al curar).
func _flash_pantalla(color: Color, alpha: float, dur: float) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	flash_dano.color = Color(color.r, color.g, color.b, alpha)
	_flash_tween = create_tween()
	_flash_tween.tween_property(flash_dano, "color:a", 0.0, dur)


## Parry exitoso: destello celeste y el dial "responde" (recupera energía con el parry).
func _on_parry() -> void:
	_flash_pantalla(Color(0.75, 0.9, 1.0), 0.2, 0.28)
	if dial.has_method("pulso_transformacion"):
		dial.pulso_transformacion()
	_t_reposo = 0.0


## Curación: destello verde suave y la barra de vida "respira" hacia arriba.
func _pulso_curacion() -> void:
	_flash_pantalla(Color(0.45, 1.0, 0.6), 0.16, 0.4)
	if _hp_tween != null and _hp_tween.is_valid():
		_hp_tween.kill()
	hp_bar.self_modulate = Color(1.6, 2.0, 1.6)
	hp_label.pivot_offset = hp_label.size * 0.5
	hp_label.scale = Vector2.ONE * 1.25
	_hp_tween = create_tween().set_parallel(true)
	_hp_tween.tween_property(hp_bar, "self_modulate", Color.WHITE, 0.5)
	_hp_tween.tween_property(hp_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_energia_changed(energia: float) -> void:
	# Ganancia de golpe (matar, parry, tag, alma): el dial pulsa. La regen lenta no dispara nada.
	if energia - _energia_prev >= 3.0 and dial.has_method("pulso_energia"):
		dial.pulso_energia()
	_energia_prev = energia
	dial.set_energia(energia)
	_energia_llena = energia >= 99.9
	if not _energia_llena:
		_t_reposo = 0.0
	if energia < 25.0 and _player != null and _player.current_form != Jugador.Form.HUMAN:
		if not _energia_aviso_dado:
			_aviso("¡Energía baja!")
			var audio := get_node_or_null("/root/AudioManager")
			if audio != null:
				audio.play_ui("energia_baja", -12.0)
			_energia_aviso_dado = true
	else:
		_energia_aviso_dado = false


func _on_agotada() -> void:
	_aviso("Transformación agotada")


func _prog_refresh() -> void:
	var prog: Node = get_node("/root/Progresion")
	var base: int = prog.fragmentos_para_nivel(prog.nivel)
	var siguiente: int = prog.fragmentos_para_nivel(prog.nivel + 1)
	var tramo: int = prog.fragmentos - base
	var requeridos: int = siguiente - base
	nivel_label.text = "NIVEL %d" % prog.nivel
	prog_bar.max_value = maxi(requeridos, 1)
	prog_bar.value = tramo
	prog_label.text = "%d/%d fragmentos" % [tramo, requeridos]


func _limpiar_idle() -> void:
	var activa: RichTextLabel = _filas[0]
	if activa.text == "":
		_limpiar_todo()
		return
	_tween_idle = create_tween()
	_tween_idle.set_parallel(true)
	_tween_idle.tween_property(activa, "position:x", activa.position.x - 220.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween_idle.tween_property(activa, "modulate:a", 0.0, 0.6)
	_tween_idle.finished.connect(_limpiar_todo)


func _limpiar_todo() -> void:
	_historial.clear()
	for i in range(_filas.size()):
		if _fila_tweens[i] != null:
			_fila_tweens[i].kill()
			_fila_tweens[i] = null
		_filas[i].text = ""
		_filas[i].visible = false
		_filas[i].modulate.a = 0.0
	_filas[0].position = _combo_base_pos


func _aviso(texto: String) -> void:
	if aviso.visible:
		_cola_avisos.append(texto)
		return
	_mostrar_aviso(texto)


func _mostrar_aviso(texto: String) -> void:
	aviso.text = texto
	aviso.visible = true
	aviso.modulate.a = 1.0
	_top_timer.start()


func _fade_top() -> void:
	if aviso.visible:
		var t := create_tween()
		t.tween_property(aviso, "modulate:a", 0.0, 0.6)
		t.tween_callback(func() -> void:
			aviso.visible = false
			_siguiente_aviso()
		)
	else:
		_siguiente_aviso()


func _siguiente_aviso() -> void:
	if _cola_avisos.is_empty():
		return
	_mostrar_aviso(_cola_avisos.pop_front())
