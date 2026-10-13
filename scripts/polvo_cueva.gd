extends CPUParticles2D

## Polvo y partículas de roca flotando en el aire de la cueva. Acompaña a la cámara y solo se ve cuando
## el jugador está por debajo de `y_cueva` (el tramo subterráneo); arriba, en el bosque, se apaga solo.
## Las partículas viven en el mundo (local_coords = false), así que se quedan atrás al avanzar.

@export var y_cueva := 2000.0
@export var desvanecer := 300.0           ## px bajo y_cueva en los que aparece gradualmente
@export var opacidad_max := 0.5
@export var margen := 200.0               ## px extra alrededor de la vista donde nacen
@export var suavizado := 2.0


func _ready() -> void:
	if texture == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 32
		t.height = 32
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		texture = t
	modulate.a = 0.0
	emitting = false


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var c := cam.get_screen_center_position()
	global_position = c
	emission_rect_extents = get_viewport_rect().size / cam.zoom * 0.5 + Vector2(margen, margen)
	var k := clampf((c.y - y_cueva) / maxf(desvanecer, 1.0), 0.0, 1.0)
	modulate.a = lerpf(modulate.a, opacidad_max * k, 1.0 - exp(-suavizado * delta))
	emitting = modulate.a > 0.01
