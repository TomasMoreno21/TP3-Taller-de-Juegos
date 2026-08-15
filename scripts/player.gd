extends CharacterBody2D

signal form_changed(form_name: String)
signal attack_performed(attack_type: String, step: Variant)
signal health_changed(health: int, max_health: int)
signal energia_changed(energia: float)
signal transformacion_agotada

enum Form { HUMAN, LOBO, OSO, MURCIELAGO }

const GRAVITY := 980.0
const MAX_FALL_SPEED := 950.0
const GLIDE_FALL_MULTIPLIER := 0.35
const TINT_ALPHA := 0.45
const COMBO_WINDOW := 1.1
const ENERGIA_MAX := 100.0
const ENERGIA_DRAIN := 8.0
const ENERGIA_REGEN := 5.0
const ENERGIA_KILL := 20.0
const ENERGIA_PICKUP := 30.0
const ENERGIA_RESPAWN := 50.0
const RECOVERY_LIGHT := 0.3
const RECOVERY_HEAVY := 0.5
const RECOVERY_SPECIAL := 0.8
const RECOVERY_COMBO := 1.0
const VIDA_MAX := 100

var forms: Array[Forma] = []
var current_form: int = Form.HUMAN
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
var _light_step := 0
var _heavy_step := 0
var _seq: Array[String] = []
var _combo_timer := 0.0
var _buffered_attack := ""
var _was_blocking := false
var _sprite_tween: Tween
var _base_sprite_scale := Vector2.ONE
var _spawn_position := Vector2.ZERO

@onready var visual: AnimatedSprite2D = $Sprite2D
@onready var tint: Sprite2D = get_node_or_null("Sprite2D/Tint")
@onready var collision_shape: CollisionShape2D = $Collision
@onready var attack_area: Area2D = $AttackArea
@onready var attack_hitbox: CollisionShape2D = $AttackArea/AttackHitbox
@onready var attack_effect: Polygon2D = get_node_or_null("AttackEffect")
@onready var attack_area_visual: Polygon2D = get_node_or_null("AttackAreaVisual")

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
	_base_sprite_scale = visual.scale
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
		velocity.x = dir * data.speed
		if dir != 0.0:
			facing = 1 if dir > 0 else -1

	if Input.is_action_just_pressed("jump"):
		data.try_jump(self)

	var g: float = GRAVITY * data.gravity_scale
	if _gravity_override >= 0.0:
		g = _gravity_override
	if data.is_gliding(self):
		g *= GLIDE_FALL_MULTIPLIER

	velocity.y = min(velocity.y + g * delta, MAX_FALL_SPEED)
	move_and_slide()

	if is_on_floor():
		data.on_floor(self)

	_handle_attack(delta)
	_check_attack_hits()
	_handle_energia(delta)
	_handle_transform()
	_handle_death()
	_update_animacion()


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
	if not _sigue_apretado(tipo):
		return
	_procesar_ataque(tipo, data, airborne)


func _sigue_apretado(tipo: String) -> bool:
	match tipo:
		"light":
			return Input.is_action_pressed("attack")
		"heavy":
			return Input.is_action_pressed("heavy")
		"special":
			return Input.is_action_pressed("special")
	return false


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
	_attack_timer = _recovery_for(_current_attack_type)
	_hit_applied = false
	_current_attack_damage = forms[current_form].attack_damage if damage < 0 else damage
	_current_attack_knockback = knockback
	var shape: RectangleShape2D = attack_hitbox.shape
	shape.size = size
	attack_hitbox.shape = shape
	attack_hitbox.disabled = false
	attack_area.position = Vector2(facing * range, 0.0)
	attack_area.monitoring = true
	if attack_area_visual != null:
		attack_area_visual.position = attack_area.position
		attack_area_visual.polygon = _make_rect_polygon(size)
		attack_area_visual.visible = true


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
	if attack_area_visual != null:
		attack_area_visual.visible = false


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
			return
		if body.has_method("take_damage"):
			body.take_damage(_current_attack_damage, _current_attack_knockback, facing)
			_hit_applied = true
			return


func _aplicar_knockback(body: Node2D) -> void:
	if _current_attack_knockback <= 0.0 or not body is RigidBody2D:
		return
	body.apply_impulse(Vector2(facing * _current_attack_knockback, -120.0))


func _play_attack_fx(tipo: String, _step: int) -> void:
	if attack_effect == null:
		return
	var slash := _slash_poligono(tipo)
	if slash.size() == 0:
		return
	attack_effect.polygon = slash
	attack_effect.scale.x = facing
	attack_effect.visible = true
	var tween := create_tween()
	tween.tween_property(attack_effect, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func() -> void:
		if is_instance_valid(attack_effect):
			attack_effect.visible = false
			attack_effect.modulate.a = 1.0
	)


func _slash_poligono(tipo: String) -> PackedVector2Array:
	match tipo:
		"light":
			return PackedVector2Array([-78, -15, 24, -36, 84, 0, 24, 36, -78, 15])
		"heavy":
			return PackedVector2Array([-108, -27, 30, -51, 120, 0, 30, 51, -108, 27])
		"combo":
			return PackedVector2Array([-132, -36, 36, -66, 156, 0, 36, 66, -132, 36])
		_:
			return PackedVector2Array()


func _punch_sprite(amount: float) -> void:
	if _sprite_tween != null and _sprite_tween.is_valid():
		_sprite_tween.kill()
	visual.scale = _base_sprite_scale
	_sprite_tween = create_tween()
	_sprite_tween.tween_property(visual, "scale", _base_sprite_scale * (1.0 + amount), 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sprite_tween.tween_property(visual, "scale", _base_sprite_scale, 0.1)


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


func _handle_transform() -> void:
	if not Input.is_action_just_pressed("transform"):
		return
	var siguiente: int = current_form + 1
	if siguiente >= forms.size():
		siguiente = Form.HUMAN
	if not _progresion().forma_desbloqueada(siguiente):
		return
	_transformar(siguiente)


func _transformar(nueva: int) -> void:
	if nueva == current_form:
		return
	forms[current_form].reset_form_state()
	current_form = nueva
	var data: Forma = forms[current_form]
	data.reset_form_state()
	_apply_form()
	form_changed.emit(data.form_name)
	health_changed.emit(health, VIDA_MAX)


func _apply_form() -> void:
	var data: Forma = forms[current_form]
	visual.flip_h = facing < 0
	if tint != null:
		tint.visible = true
		tint.modulate = Color(data.color.r, data.color.g, data.color.b, TINT_ALPHA)
	else:
		visual.modulate = Color.WHITE
		visual.self_modulate = _tinte_forma(data.color)
	collision_shape.shape.size = data.collider_size
	_gravity_override = -1.0
	blocking = false


func _tinte_forma(color: Color) -> Color:
	# Tinte sutil: mezcla el color de la forma con blanco para no oscurecer el sprite
	return color.lerp(Color.WHITE, 0.55)


func _update_tint() -> void:
	if tint != null:
		tint.modulate.a = 1.0 if blocking else TINT_ALPHA
		return
	var data: Forma = forms[current_form]
	visual.self_modulate = _tinte_forma(data.color)


func _update_animacion() -> void:
	visual.flip_h = facing < 0
	var data: Forma = forms[current_form]
	var nombre: String = ""
	if _attacking:
		match _current_attack_type:
			"light":
				nombre = "attack%d" % (_light_step % 3 + 1)
			"heavy":
				nombre = "attack2"
			"combo", "special":
				nombre = "attack3"
			_:
				nombre = "attack1"
	elif not is_on_floor():
		nombre = "fly"
	elif absf(velocity.x) > 10.0:
		nombre = "walk" if data.speed < 200.0 else "run"
	else:
		nombre = "idle"
	if visual.animation != nombre:
		visual.play(nombre)


func _handle_death() -> void:
	if health > 0 or god_mode:
		return
	_transformar(Form.HUMAN)
	global_position = _spawn_position
	velocity = Vector2.ZERO
	energia = ENERGIA_RESPAWN
	health_changed.emit(health, VIDA_MAX)
	energia_changed.emit(energia)


func take_damage(cantidad: int, _knockback: float = 0.0, _dir: int = 1) -> void:
	if god_mode or blocking:
		return
	health -= cantidad
	health_changed.emit(health, VIDA_MAX)
	_handle_death()


func heal_full() -> void:
	health = VIDA_MAX
	health_changed.emit(health, VIDA_MAX)


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


func _try_interact() -> bool:
	for nodo in get_tree().get_nodes_in_group("interactable"):
		if nodo.has_method("try_interact") and nodo.try_interact(self):
			return true
	return false


func _progresion() -> Node:
	return get_node("/root/Progresion")
