extends Sprite2D
## Aura de luz alrededor del personaje (aditiva, con latido). Toma el color de la forma actual.

@export_group("Color")
@export var seguir_forma := true                 ## tiñe el aura con el color de la forma actual del jugador
@export var color_fijo := Color(0.7, 0.9, 1.0)   ## color si seguir_forma = false

@export_group("Latido")
@export var opacidad := 0.5                       ## opacidad base (0 = aura invisible)
@export var velocidad := 1.6                      ## velocidad del latido
@export var pulso_escala := 0.05                  ## cuánto late el tamaño (fracción; 0 = fijo)
@export var pulso_alpha := 0.18                   ## cuánto late la opacidad (fracción)

var _t := 0.0
var _jugador: Node = null
var _escala_base := Vector2.ONE


func _ready() -> void:
	_jugador = get_parent()
	_escala_base = scale
	if material == null:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat


func _process(delta: float) -> void:
	_t += delta
	var late := sin(_t * velocidad)
	scale = _escala_base * (1.0 + late * pulso_escala)
	var col := color_fijo
	if seguir_forma and _jugador != null:
		var formas = _jugador.get("forms")
		var f = _jugador.get("current_form")
		if formas != null and f != null and int(f) >= 0 and int(f) < formas.size():
			col = formas[int(f)].color
	self_modulate = Color(col.r, col.g, col.b, 1.0)
	modulate.a = clampf(opacidad * (1.0 + late * pulso_alpha), 0.0, 1.0)
