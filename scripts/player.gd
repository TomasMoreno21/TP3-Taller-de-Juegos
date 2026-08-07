extends CharacterBody2D

signal form_changed(form_name: String)
signal attack_performed(attack_type: String, step: int)

enum Form { HUMAN, OSO, LOBO, BUHO }

const GRAVITY := 980.0
const MAX_FALL_SPEED := 950.0
const GLIDE_FALL_MULTIPLIER := 0.35
const TINT_ALPHA := 0.45
const COMBO_WINDOW := 0.35

var SLASH_LIGHT := PackedVector2Array([-26, -5, 8, -12, 28, 0, 8, 12, -26, 5])
var SLASH_HEAVY := PackedVector2Array([-36, -9, 10, -17, 40, 0, 10, 17, -36, 9])
var BURST_SPECIAL := PackedVector2Array([0, -26, 9, -9, 26, 0, 9, 9, 0, 26, -9, 9, -26, 0, -9, -9])

var forms: Array[Forma] = []
var current_form: int = Form.HUMAN
var health: int = 100
var god_mode := false
var facing := 1
var blocking := false

var _attacking := false
var _attack_timer := 0.0
var _hit_applied := false
var _current_attack_damage := 0
var _current_attack_knockback := 0.0
var _gravity_override: float = -1.0
var _light_step := 0
var _heavy_step := 0
var _combo_timer := 0.0
var _was_blocking := false
var _sprite_tween: Tween
var _base_sprite_scale := Vector2.ONE
var _area_visual_timer := 0.0

@onready var visual: Sprite2D = $Sprite2D
@onready var tint: Sprite2D = $Sprite2D/Tint
@onready var collision_shape: CollisionShape2D = $Collision
@onready var attack_area: Area2D = $AttackArea
@onready var attack_hitbox: CollisionShape2D = $AttackArea/AttackHitbox
@onready var attack_effect: Polygon2D = $AttackEffect
@onready var attack_area_visual: Polygon2D = $AttackAreaVisual


func _ready() -> void:
	add_to_group("player")
	forms = [Humano.new(), Oso.new(), Lobo.new(), Buho.new()]
	health = forms[current_form].max_health
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
	_handle_area_visual(delta)
	_handle_transform()


func _handle_attack(delta: float) -> void:
	var data: Forma = forms[current_form]
	var airborne := not is_on_floor()

	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_light_step = 0
			_heavy_step = 0

	if Input.is_action_just_pressed("attack"):
		_heavy_step = 0
		if airborne:
			data.perform_jump_attack(self, false)
			_play_attack_fx("light", 1)
			_punch_sprite(0.15)
		else:
			_light_step = mini(_light_step + 1, data.light_combo_steps)
			_combo_timer = COMBO_WINDOW
			data.perform_light(self, _light_step)
			_play_attack_fx("light", _light_step)
			_punch_sprite(0.15)
		attack_performed.emit("light", _light_step)

	if Input.is_action_just_pressed("heavy"):
		_light_step = 0
		if airborne:
			data.perform_jump_attack(self, true)
			_play_attack_fx("heavy", 1)
			_punch_sprite(0.3)
		else:
			_heavy_step = mini(_heavy_step + 1, data.heavy_combo_steps)
			_combo_timer = COMBO_WINDOW
			data.perform_heavy(self, _heavy_step)
			_play_attack_fx("heavy", _heavy_step)
			_punch_sprite(0.3)
		attack_performed.emit("heavy", _heavy_step)

	if Input.is_action_just_pressed("special"):
		if not _try_interact():
			_light_step = 0
			_heavy_step = 0
			_combo_timer = 0.0
			data.perform_special(self)
			_play_attack_fx("special", 1)
			_punch_sprite(0.4)
			attack_performed.emit("special", 1)

	if _attacking and _attack_timer > 0.0:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			end_attack()


func enable_melee(size: Vector2, range: float, damage: int = -1, knockback: float = 0.0) -> void:
	_attacking = true
	_attack_timer = 0.15
	_hit_applied = false
	_current_attack_damage = forms[current_form].attack_damage if damage < 0 else damage
	_current_attack_knockback = knockback
	var shape: RectangleShape2D = attack_hitbox.shape
	shape.size = size
	attack_hitbox.shape = shape
	attack_hitbox.disabled = false
	attack_area.position = Vector2(facing * range, 0.0)
	attack_area.monitoring = true
	attack_area_visual.position = attack_area.position
	attack_area_visual.polygon = _make_rect_polygon(size)
	_area_visual_timer = 0.15
	attack_area_visual.visible = true


func end_attack() -> void:
	_attacking = false
	_hit_applied = false
	attack_area.monitoring = false
	attack_hitbox.disabled = true
	attack_area_visual.visible = false
	_area_visual_timer = 0.0


func show_aoe_area(radius: float) -> void:
	attack_area_visual.position = Vector2.ZERO
	attack_area_visual.polygon = _make_circle_polygon(radius)
	_area_visual_timer = 0.3
	attack_area_visual.visible = true


func _make_rect_polygon(size: Vector2) -> PackedVector2Array:
	var w := size.x * 0.5
	var h := size.y * 0.5
	return PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h)])


func _make_circle_polygon(radius: float, segments: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var ang := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	return pts


func _check_attack_hits() -> void:
	if not _attacking or _hit_applied:
		return
	for body in attack_area.get_overlapping_bodies():
		if body.is_in_group("enemy"):
			body.take_damage(_current_attack_damage)
			if _current_attack_knockback > 0.0 and body.has_method("apply_knockback"):
				var dir := 1.0 if body.global_position.x >= global_position.x else -1.0
				body.apply_knockback(Vector2(dir * _current_attack_knockback, -60.0))
			_hit_applied = true
			break


func _handle_area_visual(delta: float) -> void:
	if _area_visual_timer > 0.0:
		_area_visual_timer -= delta
		if _area_visual_timer <= 0.0:
			attack_area_visual.visible = false


func fire_projectile() -> void:
	var projectile: Area2D = preload("res://scenes/projectile.tscn").instantiate()
	projectile.position = global_position + Vector2(facing * 26.0, -4.0)
	projectile.setup(facing, forms[current_form].special_damage)
	get_parent().add_child(projectile)


func aoe_knockback(radius: float, damage: int, force: float) -> void:
	for body: Node2D in get_tree().get_nodes_in_group("enemy"):
		if global_position.distance_to(body.global_position) <= radius:
			body.take_damage(damage)
			if body.has_method("apply_knockback"):
				var dir: Vector2 = (body.global_position - global_position).normalized()
				body.apply_knockback(dir * force + Vector2(0, -80))


func _try_interact() -> bool:
	var best: Node2D = null
	var best_dist := INF
	for obj: Node2D in get_tree().get_nodes_in_group("interactable"):
		if obj.has_method("can_interact") and obj.can_interact(self):
			var d: float = global_position.distance_to(obj.global_position)
			if d < best_dist:
				best_dist = d
				best = obj
	if best != null:
		best.break_interact()
		return true
	return false


func _play_attack_fx(attack_type: String, step: int) -> void:
	var size_mult := 0.7 + 0.25 * float(maxi(step, 1) - 1)
	match attack_type:
		"light":
			attack_effect.polygon = SLASH_LIGHT
			attack_effect.color = Color(1.0, 0.95, 0.6)
			attack_area_visual.color = Color(1.0, 0.95, 0.6, 0.22)
		"heavy":
			attack_effect.polygon = SLASH_HEAVY
			attack_effect.color = Color(1.0, 0.55, 0.25)
			attack_area_visual.color = Color(1.0, 0.55, 0.25, 0.28)
		"special":
			attack_effect.polygon = BURST_SPECIAL
			attack_effect.color = forms[current_form].color
			var c: Color = forms[current_form].color
			c.a = 0.25
			attack_area_visual.color = c
	attack_effect.position = attack_area.position + Vector2(0, -10)
	attack_effect.scale = Vector2(facing * size_mult, size_mult)
	attack_effect.rotation = randf_range(-0.25, 0.25)
	attack_effect.modulate.a = 1.0
	attack_effect.visible = true
	var tw := create_tween()
	tw.parallel().tween_property(attack_effect, "modulate:a", 0.0, 0.22)
	tw.parallel().tween_property(attack_effect, "scale", attack_effect.scale * 1.6, 0.22)
	tw.tween_callback(func() -> void: attack_effect.visible = false)


func _punch_sprite(strength: float) -> void:
	if _sprite_tween != null and _sprite_tween.is_valid():
		_sprite_tween.kill()
	visual.scale = _base_sprite_scale
	_sprite_tween = create_tween()
	_sprite_tween.tween_property(visual, "scale", Vector2(_base_sprite_scale.x + facing * strength * 0.4, maxf(_base_sprite_scale.y - strength * 0.4, 0.05)), 0.05)
	_sprite_tween.tween_property(visual, "scale", _base_sprite_scale, 0.14)


func _handle_transform() -> void:
	if Input.is_action_just_pressed("transform"):
		current_form = (current_form + 1) % Form.size()
		_apply_form()
		form_changed.emit(forms[current_form].form_name)


func _apply_form() -> void:
	var data: Forma = forms[current_form]
	var shape: RectangleShape2D = collision_shape.shape
	shape.size = data.collider_size
	collision_shape.shape = shape
	_light_step = 0
	_heavy_step = 0
	_combo_timer = 0.0
	attack_effect.visible = false
	_update_tint()
	data.reset_state()
	end_attack()


func _update_tint() -> void:
	var c: Color
	if blocking:
		c = Color(0.65, 0.65, 0.75)
		c.a = 0.6
	else:
		c = forms[current_form].color
		c.a = TINT_ALPHA
	tint.self_modulate = c


func get_form_name() -> String:
	return forms[current_form].form_name


func set_form(form_id: int) -> void:
	if form_id >= 0 and form_id < Form.size():
		current_form = form_id
		health = forms[current_form].max_health
		_apply_form()
		form_changed.emit(forms[current_form].form_name)


func take_damage(amount: int) -> void:
	if god_mode:
		return
	if blocking:
		amount = max(int(ceil(amount * 0.25)), 1)
	health = max(health - amount, 0)


func heal_full() -> void:
	health = forms[current_form].max_health


func set_health(value: int) -> void:
	health = max(value, 0)


func set_gravity_override(value: float) -> void:
	_gravity_override = value


func clear_gravity_override() -> void:
	_gravity_override = -1.0
