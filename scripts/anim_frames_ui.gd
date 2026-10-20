extends TextureRect

@export var frames: Array[Texture2D] = []
@export var fps := 8.0
@export var loop := true
@export var reproduciendo := true

var _t := 0.0
var _i := 0


func _ready() -> void:
	if not frames.is_empty():
		texture = frames[0]


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not reproduciendo or frames.size() <= 1 or fps <= 0.0:
		return
	_t += delta * fps
	while _t >= 1.0:
		_t -= 1.0
		_i += 1
		if _i >= frames.size():
			if loop:
				_i = 0
			else:
				_i = frames.size() - 1
				reproduciendo = false
		texture = frames[_i]
