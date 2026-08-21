extends CharacterBody2D

signal form_changed(form_name: String)
signal forma_selectada_cambiada(forma_index: int)
signal attack_performed(attack_type: String, step: Variant)
signal health_changed(health: int, max_health: int)
signal dano_recibido(cantidad: int)
signal energia_changed(energia: float)
signal transformacion_agotada
signal racha_changed(cantidad: int)

enum Form { HUMAN, LOBO, OSO, MURCIELAGO }

const GRAVITY := 980.0
const MAX_FALL_SPEED := 950.0
const GLIDE_FALL_MULTIPLIER := 0.35
const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.15
const JUMP_CUT_MULTIPLIER := 0.5
const TURN_BOOST := 2.2
const APEX_THRESHOLD := 70.0
const APEX_GRAVITY_MULT := 0.7
const APEX_CORE_THRESHOLD := 35.0
const APEX_CORE_MULT := 0.45
const TINT_ALPHA := 0.45
const COMBO_WINDOW := 1.1
const LINEA_ESPESOR := 40.0
const ENERGIA_MAX := 100.0
const ENERGIA_DRAIN := 8.0
const ENERGIA_REGEN := 5.0
const ENERGIA_KILL := 20.0
const ENERGIA_PICKUP := 30.0
const ENERGIA_RESPAWN := 50.0
const RECOVERY_LIGHT := 0.22
const RECOVERY_HEAVY := 0.4
const RECOVERY_SPECIAL := 0.6
const RECOVERY_COMBO := 0.7
const VIDA_MAX := 100

var forms: Array[Forma] = []
var current_form: int = Form.HUMAN
var forma_seleccionada: int = Form.HUMAN
var health: int = 100
var energia: float = ENERGIA_MAX
var god_mode := false
var facing := 1
var blocking := false

var _attacking := false
var _attack_timer := 0.0
var _hit_applied := false
var _current_attack_damage := 0
var _current_attack_knockback := 0.0
var _current_attack_type := "light"
var _gravity_override: float = -1.0
var _coyote_time := 0.0
var _jump_buffer := 0.0
var _light_step := 0
var _heavy_step := 0
var _seq: Array[String] = []
var _combo_timer := 0.0
var _racha := 0
var _racha_timer := 0.0
var _buffered_attack := ""
var _was_blocking := false
var _was_on_floor := false
var _fall_impact := 0.0
var _sprite_tween: Tween
var _turn_prev_facing := 0
var _base_sprite_scale := Vector2.ONE
var _spawn_position := Vector2.ZERO
var _derrota_activa := false
@export var limite_caida := 3000.0

@onready var visual: AnimatedSprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $Collision
@onready var attack_area: Area2D = $AttackArea
@onready var attack_hitbox: CollisionShape2D = $AttackArea/AttackHitbox
@onready var polvo: CPUParticles2D = $Polvo

const PASOS_INTERVALO := 0.18
var _pasos_timer := 0.0

const FORM_SCRIPTS := [
	preload("res://scripts/forms/humano.gd"),
	preload("res://scripts/forms/lobo.gd"),
	preload("res://scripts/forms/oso.gd"),
	preload("res://scripts/forms/murcielago.gd"),
]


func _ready() -> void:
	add_to_group("player")
	for script in FORM_SCRIPTS:
		forms.append(script.new())
	health = VIDA_MAX
	_spawn_position = global_position
	_base_sprite_scale = Vector2(absf(visual.scale.x), visual.scale.y)
	_apply_form()


func _physics_process(delta: float) -> void:
	blocking = Input.is_action_pressed("block")
	if blocking != _was_blocking:
		_was_blocking = blocking
		_update_tint()

	var data: Forma = forms[current_form]
	data.tick(self, delta)

	var dir := Input.get_axis("move_left", "move_right")
	if data.is_dashing():
		velocity.x = facing * data.dash_speed()
	else:
		if dir != 0.0:
			facing = 1 if dir > 0 else -1
			var boost := TURN_BOOST if dir * velocity.x < 0.0 else 1.0
			velocity.x = move_toward(velocity.x, dir * data.speed, data.accel * boost * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, data.friction * delta)

	if Input.is_action_just_pressed("jump"):
		if _coyote_time > 0.0 or data.can_jump():
			data.try_jump(self)
		else:
			_jump_buffer = JUMP_BUFFER_TIME
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT_MULTIPLIER

	var g: float = GRAVITY * data.gravity_scale
	if _gravity_override >= 0.0:
		g = _gravity_override
	if data.is_gliding(self):
		g *= GLIDE_FALL_MULTIPLIER
	# Apex hang escalonado: núcleo del ápice muy flotante, banda cercana suave.
	if absf(velocity.y) < APEX_CORE_THRESHOLD:
		g *= APEX_CORE_MULT
	elif absf(velocity.y) < APEX_THRESHOLD:
		g *= APEX_GRAVITY_MULT

	velocity.y = min(velocity.y + g * delta, MAX_FALL_SPEED)
	move_and_slide()
	_sprint_zoom(data)

	if is_on_floor():
		data.on_floor(self)
		_coyote_time = COYOTE_TIME
		if not _was_on_floor:
			data.on_landing(self, _fall_impact)
			_squash_landing(data, _fall_impact)
			_emitir_polvo(0.5)
		_fall_impact = 0.0
		_was_on_floor = true
	else:
		if _was_on_floor:
			_fall_impact = 0.0
		else:
			_fall_impact = velocity.y
		_was_on_floor = false
		_coyote_time = maxf(_coyote_time - delta, 0.0)

	if _jump_buffer > 0.0:
		_jump_buffer -= delta
		if is_on_floor():
			data.try_jump(self)
			_jump_buffer = 0.0

	_pasos_timer -= delta
	if is_on_floor() and absf(velocity.x) > 0.5 and _pasos_timer <= 0.0:
		_pasos_timer = PASOS_INTERVALO
		_emitir_polvo(0.8)

	_handle_attack(delta)
	_check_attack_hits()
	_handle_racha(delta)
	_handle_energia(delta)
	_handle_seleccion_forma()
	_handle_formas_cruceta()
	_handle_forma_ciclo()
	_handle_transform()
	if global_position.y > limite_caida:
		health = 0
	_handle_death()
	_update_animacion()
	_handle_vertical_tilt()


func _handle_racha(delta: float) -> void:
	if _racha_timer <= 0.0:
		return
	_racha_timer -= delta
	if _racha_timer <= 0.0:
		_racha = 0
		racha_changed.emit(_racha)


func _registrar_golpe_racha() -> void:
	_racha += 1
	_racha_timer = COMBO_WINDOW
	racha_changed.emit(_racha)


func _handle_attack(delta: float) -> void:
	var data: Forma = forms[current_form]
	var airborne := not is_on_floor()

	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_light_step = 0
			_heavy_step = 0
			_seq.clear()

	if _attacking and _attack_timer > 0.0:
		_attack_timer -= delta
		_buffer_durante_recuperacion()
		if _attack_timer <= 0.0:
			end_attack()
			_lanzar_buffered(data, airborne)
		return

	if Input.is_action_just_pressed("attack"):
		_procesar_ataque("light", data, airborne)
	if Input.is_action_just_pressed("heavy"):
		_procesar_ataque("heavy", data, airborne)
	if Input.is_action_just_pressed("special"):
		_procesar_ataque("special", data, airborne)


func _buffer_durante_recuperacion() -> void:
	if _buffered_attack != "":
		return
	if Input.is_action_just_pressed("attack"):
		_buffered_attack = "light"
	elif Input.is_action_just_pressed("heavy"):
		_buffered_attack = "heavy"
	elif Input.is_action_just_pressed("special"):
		_buffered_attack = "special"


func _lanzar_buffered(data: Forma, airborne: bool) -> void:
	if _buffered_attack == "":
		return
	var tipo := _buffered_attack
	_buffered_attack = ""
	_procesar_ataque(tipo, data, airborne)


func _procesar_ataque(tipo: String, data: Forma, airborne: bool) -> void:
	match tipo:
		"light":
			_current_attack_type = "light"
			if airborne:
				_heavy_step = 0
				data.perform_jump_attack(self, false)
				_play_attack_fx("light", 1)
				_punch_sprite(0.15)
				attack_performed.emit("light", _light_step)
			else:
				_heavy_step = 0
				var combo := _detectar_combo("light")
				if not combo.is_empty():
					_ejecutar_finisher(data, combo)
				else:
					var max_step: int = mini(data.light_combo_steps, _progresion().pasos_luz())
					_light_step = mini(_light_step + 1, max_step)
					_combo_timer = COMBO_WINDOW
					data.perform_light(self, _light_step)
					_play_attack_fx("light", _light_step)
					_punch_sprite(0.15)
					attack_performed.emit("light", _light_step)
		"heavy":
			_current_attack_type = "heavy"
			if airborne:
				_light_step = 0
				data.perform_jump_attack(self, true)
				_play_attack_fx("heavy", 1)
				_punch_sprite(0.3)
				attack_performed.emit("heavy", _heavy_step)
			else:
				_light_step = 0
				var combo := _detectar_combo("heavy")
				if not combo.is_empty():
					_ejecutar_finisher(data, combo)
				else:
					_heavy_step = mini(_heavy_step + 1, data.heavy_combo_steps)
					_combo_timer = COMBO_WINDOW
					data.perform_heavy(self, _heavy_step)
					_play_attack_fx("heavy", _heavy_step)
					_punch_sprite(0.3)
					attack_performed.emit("heavy", _heavy_step)
		"special":
			if _try_interact():
				return
			_light_step = 0
			_heavy_step = 0
			var combo := _detectar_combo("special")
			if not combo.is_empty():
				_ejecutar_finisher(data, combo)
			else:
				_current_attack_type = "special"
				_combo_timer = 0.0
				data.perform_special(self)
				_play_attack_fx("special", 1)
				_punch_sprite(0.4)
				attack_performed.emit("special", 1)


func _detectar_combo(tipo: String) -> Dictionary:
	_seq.append(tipo)
	if _seq.size() > 3:
		_seq.pop_front()
	var data: Forma = forms[current_form]
	var desbloqueados: int = _progresion().combos_desbloqueados_forma(current_form)
	var total := mini(desbloqueados, data.combos.size())
	for i in range(total - 1, -1, -1):
		var c: Dictionary = data.combos[i]
		var seq: Array = c.get("secuencia", [])
		if seq.size() > _seq.size():
			continue
		var coincide := true
		for j in range(seq.size()):
			if _seq[_seq.size() - seq.size() + j] != seq[j]:
				coincide = false
				break
		if coincide:
			_seq.clear()
			return c
	return {}


func _ejecutar_finisher(data: Forma, combo: Dictionary) -> void:
	_current_attack_type = "combo"
	_light_step = 0
	_heavy_step = 0
	_combo_timer = 0.0
	data.perform_combo(self, combo)
	_play_attack_fx("combo", 1)
	_punch_sprite(0.45)
	attack_performed.emit("combo", combo.get("nombre", "Combo"))


func enable_melee(size: Vector2, range: float, damage: int = -1, knockback: float = 0.0) -> void:
	_attacking = true
	var data: Forma = forms[current_form]
	_attack_timer = _recovery_for(_current_attack_type) * data.mult_recuperacion
	if _current_attack_type == "light":
		velocity.x += facing * data.lunge_light
	elif _current_attack_type == "heavy" or _current_attack_type == "combo":
		velocity.x += facing * data.lunge_heavy
	_hit_applied = false
	_current_attack_damage = forms[current_form].attack_damage if damage < 0 else damage
	_current_attack_knockback = knockback
	var coll: RectangleShape2D = collision_shape.shape
	var banda := Vector2(LINEA_ESPESOR, coll.size.y)
	var shape: RectangleShape2D = attack_hitbox.shape
	shape.size = banda
	attack_hitbox.shape = shape
	attack_hitbox.disabled = false
	attack_area.position = Vector2(facing * (coll.size.x * 0.5 + LINEA_ESPESOR * 0.5), 0.0)
	attack_area.monitoring = true


func _recovery_for(attack_type: String) -> float:
	match attack_type:
		"light":
			return RECOVERY_LIGHT
		"heavy":
			return RECOVERY_HEAVY
		"special":
			return RECOVERY_SPECIAL
		"combo":
			return RECOVERY_COMBO
		_:
			return RECOVERY_LIGHT


func end_attack() -> void:
	_attacking = false
	_hit_applied = false
	attack_area.monitoring = false
	attack_hitbox.disabled = true


func _make_rect_polygon(size: Vector2) -> PackedVector2Array:
	var w := size.x * 0.5
	var h := size.y * 0.5
	return PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h)])


func _check_attack_hits() -> void:
	if not _attacking or _hit_applied:
		return
	var bodies := attack_area.get_overlapping_bodies()
	for body in bodies:
		if body == self:
			continue
		if body.has_method("registrar_golpe"):
			body.registrar_golpe(_current_attack_damage)
			_hit_applied = true
			_aplicar_knockback(body)
			_registrar_golpe_racha()
			_hitstop_por_tipo()
			_zoom_punch_por_tipo()
			_shake_por_tipo()
			return
		if body.has_method("take_damage"):
			body.take_damage(_current_attack_damage, _current_attack_knockback, facing)
			_hit_applied = true
			_registrar_golpe_racha()
			_hitstop_por_tipo()
			_zoom_punch_por_tipo()
			_shake_por_tipo()
			return


func _hitstop_por_tipo() -> void:
	# Hit-stop (freeze frames) en golpes con "peso": heavy y combo.
	if _current_attack_type != "heavy" and _current_attack_type != "combo":
		return
	Engine.time_scale = 0.0
	await get_tree().create_timer(0.06, true, false, true).timeout
	Engine.time_scale = 1.0


func _zoom_punch_por_tipo() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null or not cam.has_method("punch"):
		return
	var escala := 1.02
	if current_form >= 0 and current_form < forms.size():
		escala = forms[current_form].hit_zoom
	cam.punch(escala)


func _shake_por_tipo() -> void:
	if _current_attack_type != "light" and _current_attack_type != "heavy" and _current_attack_type != "combo":
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null or not cam.has_method("shake"):
		return
	var fuerza := 2.5
	if current_form >= 0 and current_form < forms.size():
		var forma: Forma = forms[current_form]
		match _current_attack_type:
			"light":
				fuerza = forma.shake_golpe_ligero
			"heavy":
				fuerza = forma.shake_golpe_pesado
			"combo":
				fuerza = forma.shake_golpe_combo
	cam.shake(fuerza, 0.08)


func _aplicar_knockback(body: Node2D) -> void:
	if _current_attack_knockback <= 0.0 or not body is RigidBody2D:
		return
	body.apply_impulse(Vector2(facing * _current_attack_knockback, -120.0))


func _play_attack_fx(tipo: String, _step: int) -> void:
	# El feedback visual del golpe (Polygon2D) se quitó en el rebuild; sin nodo, no hay FX.
	pass


func squash_y(amount: float, duration: float) -> void:
	if _sprite_tween != null and _sprite_tween.is_valid():
		_sprite_tween.kill()
	var base := Vector2(absf(_base_sprite_scale.x), _base_sprite_scale.y) * Vector2(facing, 1)
	visual.scale = base
	visual.position.y = 0.0
	_sprite_tween = create_tween()
	_sprite_tween.tween_property(visual, "scale:y", base.y * (1.0 - amount), duration * 0.4)
	_sprite_tween.tween_property(visual, "scale:y", base.y, duration * 0.6)


func _emitir_polvo(_escala: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	polvo.emitting = true


func _squash_landing(data: Forma, impacto: float) -> void:
	var amt := data.landing_squash
	if amt <= 0.0 or impacto <= 0.0:
		return
	var factor := clampf(impacto / 600.0, 0.3, 1.0)
	squash_y(amt * factor, 0.18)


func _sprint_zoom(data: Forma) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var vel := absf(velocity.x)
	var objetivo: Vector2 = data.camera_zoom
	if data.sprint_zoom_out > 0.0 and vel >= data.sprint_min_speed:
		objetivo = data.camera_zoom * (1.0 - data.sprint_zoom_out)
	cam.fijar_zoom(objetivo)


func stretch_y(amount: float, duration: float) -> void:
	if _sprite_tween != null and _sprite_tween.is_valid():
		_sprite_tween.kill()
	var base := Vector2(absf(_base_sprite_scale.x), _base_sprite_scale.y) * Vector2(facing, 1)
	visual.scale = base
	visual.position.y = 0.0
	_sprite_tween = create_tween()
	_sprite_tween.tween_property(visual, "scale:y", base.y * (1.0 + amount), duration * 0.4)
	_sprite_tween.tween_property(visual, "scale:y", base.y, duration * 0.6)


func apply_zip(impulso: float) -> void:
	velocity.x = facing * absf(impulso)


func _snap_turn(tilt: float) -> void:
	if tilt <= 0.0:
		return
	visual.rotation = deg_to_rad(-tilt) * facing
	var tw := create_tween()
	tw.tween_property(visual, "rotation", 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _handle_vertical_tilt() -> void:
	if current_form != Form.MURCIELAGO or is_on_floor():
		return
	# Al planear (caída sostenida) se atenúa: solo una leve inclinación baja.
	if velocity.y > 0.0:
		visual.rotation = lerpf(visual.rotation, deg_to_rad(6.0), 0.1)
		return
	var incl := clampf(velocity.y / 300.0, -1.0, 0.0) * deg_to_rad(20.0)
	visual.rotation = lerpf(visual.rotation, incl, 0.2)


func _punch_sprite(amount: float) -> void:
	if _sprite_tween != null and _sprite_tween.is_valid():
		_sprite_tween.kill()
	var base := Vector2(absf(_base_sprite_scale.x), _base_sprite_scale.y) * Vector2(facing, 1)
	visual.scale = base
	_sprite_tween = create_tween()
	_sprite_tween.tween_property(visual, "scale", base * (1.0 + amount), 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sprite_tween.tween_property(visual, "scale", base, 0.1)


func _handle_energia(delta: float) -> void:
	if current_form == Form.HUMAN:
		energia = minf(energia + ENERGIA_REGEN * delta, ENERGIA_MAX)
	else:
		energia -= ENERGIA_DRAIN * delta
		if energia <= 0.0:
			energia = 0.0
			_transformar(Form.HUMAN)
			transformacion_agotada.emit()
	energia_changed.emit(energia)


func _handle_seleccion_forma() -> void:
	# Solo Q (form_next) cicla la preselección del flujo viejo.
	# W/S/↑↓ ya no tocan la selección: causaban transformaciones accidentales.
	if Input.is_action_just_pressed("form_next"):
		_avanzar_seleccion()


func _retroceder_seleccion() -> bool:
	var candidata := forma_seleccionada - 1
	for _i in range(forms.size()):
		candidata = posmod(candidata, forms.size())
		if _progresion().forma_desbloqueada(candidata):
			if candidata != forma_seleccionada:
				forma_seleccionada = candidata
				forma_selectada_cambiada.emit(candidata)
				return true
			return false
		candidata -= 1
	return false


func _avanzar_seleccion() -> bool:
	var candidata := forma_seleccionada + 1
	for _i in range(forms.size()):
		candidata = posmod(candidata, forms.size())
		if _progresion().forma_desbloqueada(candidata):
			if candidata != forma_seleccionada:
				forma_seleccionada = candidata
				forma_selectada_cambiada.emit(candidata)
				return true
			return false
		candidata += 1
	return false


func _handle_formas_cruceta() -> void:
	# La cruceta transforma directo: ↑ Murciélago, → Lobo, ← Oso, ↓ Humano.
	var objetivo := -1
	if Input.is_action_just_pressed("forma_arriba"):
		objetivo = Form.MURCIELAGO
	elif Input.is_action_just_pressed("forma_derecha"):
		objetivo = Form.LOBO
	elif Input.is_action_just_pressed("forma_izquierda"):
		objetivo = Form.OSO
	elif Input.is_action_just_pressed("forma_abajo"):
		objetivo = Form.HUMAN
	if objetivo < 0:
		return
	if not _progresion().forma_desbloqueada(objetivo):
		return
	_transformar(objetivo)


func _handle_forma_ciclo() -> void:
	# RT/E: cicla la preselección hacia adelante; LT: hacia atrás.
	# RB/T es quien confirma y transforma en la preseleccionada.
	if Input.is_action_just_pressed("forma_swap"):
		_avanzar_seleccion()
	elif Input.is_action_just_pressed("forma_prev"):
		_retroceder_seleccion()


func _handle_transform() -> void:
	if not Input.is_action_just_pressed("transform"):
		return
	# T ya transformado en la forma preseleccionada = revertir a Humano al toque,
	# si no T no hacía nada (se sentía como que no respondía)
	if current_form != Form.HUMAN and forma_seleccionada == current_form:
		_transformar(Form.HUMAN)
		return
	if forma_seleccionada == current_form:
		# nada preseleccionado todavía con Q: T solo avanza a la próxima forma
		# desbloqueada y transforma directo, no se queda sin hacer nada
		_avanzar_seleccion()
	if not _progresion().forma_desbloqueada(forma_seleccionada):
		return
	_transformar(forma_seleccionada)


func _transformar(nueva: int) -> void:
	if nueva == current_form:
		return
	forms[current_form].reset_form_state()
	current_form = nueva
	forma_seleccionada = nueva
	var data: Forma = forms[current_form]
	data.reset_form_state()
	_apply_form()
	_zoom_transform(data)
	if nueva == Form.HUMAN:
		_particulas_regreso()
	form_changed.emit(data.form_name)
	forma_selectada_cambiada.emit(nueva)
	health_changed.emit(health, VIDA_MAX)


func _particulas_regreso() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p: CPUParticles2D = (load("res://scenes/burst.tscn") as PackedScene).instantiate()
	p.global_position = global_position + Vector2(0, 20)
	p.self_modulate = Color(0.4, 0.8, 0.9)
	get_tree().root.add_child(p)
	p.restart()
	p.emitting = true


func _zoom_transform(data: Forma) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		cam.fijar_zoom(data.camera_zoom)
	_flash_transformacion()


func _flash_transformacion() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var overlay := ColorRect.new()
	overlay.color = Color(1, 1, 1, 0.9)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = 100
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	destino.add_child(layer)
	layer.add_child(overlay)
	var tw := overlay.create_tween()
	tw.tween_property(overlay, "color:a", 0.0, 0.12)
	tw.tween_callback(func() -> void:
		layer.queue_free()
	)


func _apply_form() -> void:
	var data: Forma = forms[current_form]
	_aplicar_facing()
	visual.modulate = Color.WHITE
	visual.self_modulate = _tinte_forma(data.color)
	visual.skew = 0.0
	collision_shape.shape.size = data.collider_size
	_gravity_override = -1.0
	blocking = false


func _tinte_forma(color: Color) -> Color:
	# Tinte sutil: mezcla el color de la forma con blanco para no oscurecer el sprite
	return color.lerp(Color.WHITE, 0.55)


func _aplicar_facing() -> void:
	visual.scale.x = -absf(_base_sprite_scale.x) if facing < 0 else absf(_base_sprite_scale.x)
	var data: Forma = forms[current_form]
	if facing != _turn_prev_facing:
		_turn_prev_facing = facing
		_snap_turn(data.turn_tilt)
		if data.turn_tilt_cam > 0.0:
			var cam := get_viewport().get_camera_2d()
			if cam != null and cam.has_method("tilt"):
				cam.tilt(-deg_to_rad(1.5) * facing)


func _update_tint() -> void:
	var data: Forma = forms[current_form]
	visual.modulate.a = 1.0 if blocking else TINT_ALPHA
	visual.self_modulate = _tinte_forma(data.color)


func _update_animacion() -> void:
	_aplicar_facing()
	if visual.animation != "run":
		visual.play("run")
	var data: Forma = forms[current_form]
	# Quieto = animación congelada (evita piernas ciclando lentas en el lugar).
	if absf(velocity.x) < 10.0:
		visual.speed_scale = 0.0
	else:
		visual.speed_scale = clampf(absf(velocity.x) / maxf(data.speed, 1.0), 0.4, 1.6)
	# Lean leve: el cuerpo se inclina hacia adelante según velocidad (skew, no
	# toca rotation para no pisar el snap de giro ni el tilt del Murciélago).
	var lean := clampf(velocity.x / maxf(data.speed, 1.0), -1.0, 1.0) * deg_to_rad(data.lean_angulo)
	visual.skew = lerpf(visual.skew, -lean, minf(8.0 * get_physics_process_delta_time(), 1.0))


func _handle_death() -> void:
	if health > 0 or god_mode or _derrota_activa:
		return
	_derrota_activa = true
	var escena: PackedScene = load("res://scenes/derrota.tscn")
	var derrota: CanvasLayer = escena.instantiate()
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	destino.add_child(derrota)
	get_tree().paused = true


func take_damage(cantidad: int, _knockback: float = 0.0, _dir: int = 1) -> void:
	if god_mode or blocking:
		return
	health -= cantidad
	health_changed.emit(health, VIDA_MAX)
	dano_recibido.emit(cantidad)
	_shake_dano_recibido()
	_handle_death()


func _shake_dano_recibido() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null or not cam.has_method("shake"):
		return
	cam.shake(3.5, 0.12)


func heal_full() -> void:
	health = VIDA_MAX
	health_changed.emit(health, VIDA_MAX)


func actualizar_checkpoint(pos: Vector2) -> void:
	_spawn_position = pos


func recoger_energia() -> void:
	energia = minf(energia + ENERGIA_PICKUP, ENERGIA_MAX)
	energia_changed.emit(energia)


func on_enemy_killed() -> void:
	energia = minf(energia + ENERGIA_KILL, ENERGIA_MAX)
	energia_changed.emit(energia)


func fire_projectile(pos_referencia: Vector2 = Vector2.ZERO, alcance: float = 700.0) -> void:
	var proj: Area2D = preload("res://scenes/projectile.tscn").instantiate()
	proj.global_position = global_position + Vector2(facing * 90.0, -60.0) + pos_referencia
	proj.set("direction", Vector2(facing, 0.0))
	proj.set("speed", alcance)
	proj.set("damage", forms[current_form].special_damage)
	var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	destino.add_child(proj)
	if current_form == Form.MURCIELAGO:
		velocity.x -= facing * 120.0
		squash_y(0.18, 0.25)


func _try_interact() -> bool:
	for nodo in get_tree().get_nodes_in_group("interactable"):
		if nodo.has_method("try_interact") and nodo.try_interact(self):
			return true
	return false


func _progresion() -> Node:
	return get_node("/root/Progresion")
