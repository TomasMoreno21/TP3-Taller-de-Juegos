extends Node

signal descongelado

var _restore_ms: int = 0
var _slow_scale: float = 1.0
var _slow_restore_ms: int = 0


func _process(_delta: float) -> void:
	if _restore_ms > 0 and Time.get_ticks_msec() >= _restore_ms:
		_restore_ms = 0
		if _slow_restore_ms > 0:
			Engine.time_scale = _slow_scale
		else:
			Engine.time_scale = 1.0
		descongelado.emit()
	if _slow_restore_ms > 0 and Time.get_ticks_msec() >= _slow_restore_ms:
		_slow_restore_ms = 0
		_slow_scale = 1.0
		Engine.time_scale = 1.0


func freeze(duracion: float = 0.04) -> void:
	var hasta := Time.get_ticks_msec() + maxi(1, int(duracion * 1000.0))
	if Engine.time_scale == 0.0:
		# ya congelado: el freeze más largo gana (no acortar ni descartar)
		_restore_ms = maxi(_restore_ms, hasta)
		return
	Engine.time_scale = 0.0
	_restore_ms = hasta


func slowmo(duracion: float, escala: float) -> void:
	if duracion <= 0.0 or escala <= 0.0 or escala >= 1.0:
		return
	var hasta := Time.get_ticks_msec() + maxi(1, int(duracion * 1000.0))
	_slow_scale = escala
	_slow_restore_ms = maxi(_slow_restore_ms, hasta)
	if Engine.time_scale == 0.0:
		return
	Engine.time_scale = escala