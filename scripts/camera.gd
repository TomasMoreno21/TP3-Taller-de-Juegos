extends Camera2D

var _shake_timer := 0.0
var _shake_strength := 0.0


func shake(strength: float = 8.0, duration: float = 0.15) -> void:
	_shake_timer = duration
	_shake_strength = strength


func _process(delta: float) -> void:
	if _shake_timer > 0.0:
		_shake_timer -= delta
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
		if _shake_timer <= 0.0:
			offset = Vector2.ZERO
