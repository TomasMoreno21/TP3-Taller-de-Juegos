extends Node

signal descongelado

var _restore_ms: int = 0
var _slow_scale: float = 1.0
var _slow_restore_ms: int = 0


func _ready() -> void:
	# Siempre activo: con el árbol pausado también debe devolver `Engine.time_scale` a 1
	# (si no, el panel de derrota/pausa/levelup quedaba en cámara lenta o congelado).
	process_mode = Node.PROCESS_MODE_ALWAYS


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
		if _restore_ms <= 0:
			Engine.time_scale = 1.0


func esta_congelado() -> bool:
	return _restore_ms > 0


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
	var ahora := Time.get_ticks_msec()
	var hasta := ahora + maxi(1, int(duracion * 1000.0))
	# Con un slowmo en curso gana el más fuerte (un parry durante la cámara lenta de la muerte del jefe no la pisaba hacia arriba).
	# (solo si el nuevo termina antes que el activo: así una curva de tramos, como la del parry, sigue avanzando)
	_slow_scale = minf(_slow_scale, escala) if _slow_restore_ms > ahora and hasta <= _slow_restore_ms else escala
	_slow_restore_ms = maxi(_slow_restore_ms, hasta)
	if Engine.time_scale == 0.0:
		return
	Engine.time_scale = _slow_scale