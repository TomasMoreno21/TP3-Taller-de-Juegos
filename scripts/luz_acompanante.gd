extends PointLight2D
## Luz tenue que acompaña al jugador: un charco de luz fría que "respira" y se abre un poco al correr,
## para que la cueva oscura se lea cerca de él sin perder la penumbra a lo lejos.

@export var objetivo_grupo := &"player"
@export var desplazamiento := Vector2(0, -60)   ## respecto al origen del jugador (hacia el torso)
@export var seguimiento := 8.0                   ## qué tan pegada va (1/s)
@export var respiracion := 0.06                  ## variación de tamaño al "respirar"
@export var velocidad_respiracion := 0.8
@export var extra_al_correr := 0.12              ## cuánto crece el charco a máxima velocidad

var _jugador: Node2D
var _t := 0.0
var _escala_base := 1.0


func _ready() -> void:
	_escala_base = texture_scale


func _process(delta: float) -> void:
	if not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group(objetivo_grupo) as Node2D
		if _jugador == null:
			return
		global_position = _jugador.global_position + desplazamiento
	_t += delta
	global_position = global_position.lerp(_jugador.global_position + desplazamiento, 1.0 - exp(-seguimiento * delta))
	var rapidez := 0.0
	if "velocity" in _jugador:
		rapidez = clampf((_jugador.velocity as Vector2).length() / 600.0, 0.0, 1.0)
	texture_scale = _escala_base * (1.0 + respiracion * sin(_t * velocidad_respiracion * TAU) + extra_al_correr * rapidez)
