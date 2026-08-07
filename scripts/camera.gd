extends Camera2D

const SHAKE_DURATION := 0.15
const SHAKE_STRENGTH := 8.0

var _shake_time := 0.0
var _shake_strength := 0.0
var _zoom_tween: Tween
var _base_zoom := Vector2.ONE


func _ready() -> void:
	_base_zoom = zoom


func _process(delta: float) -> void:
	if _shake_time <= 0.0:
		return
	_shake_time -= delta
	if _shake_time <= 0.0:
		offset = Vector2.ZERO
		return
	var strength: float = _shake_strength * (_shake_time / SHAKE_DURATION)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength


func shake(strength := SHAKE_STRENGTH, duration := SHAKE_DURATION) -> void:
	_shake_time = duration
	_shake_strength = strength


func zoom_punch(strength: float, duration := 0.15) -> void:
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(self, "zoom", _base_zoom * strength, 0.05)
	_zoom_tween.tween_property(self, "zoom", _base_zoom, 0.12)
