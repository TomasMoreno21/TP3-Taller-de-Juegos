class_name DanoPantalla
extends CanvasLayer
## Recibir daño: un instante sin color y con los bordes rojos. Reloj real (el golpe congela el juego).

const SHADER := preload("res://resources/dano_pantalla.gdshader")
const NOMBRE := "DanoPantalla"

var _mat: ShaderMaterial
var _t0 := 0
var _intensidad := 1.0
var _duracion := 0.4


static func lanzar(arbol: SceneTree, intensidad: float, duracion: float) -> void:
	var viejo := arbol.root.get_node_or_null(NOMBRE)
	if viejo != null:
		viejo.free()
	var l := DanoPantalla.new()
	l.name = NOMBRE
	l._intensidad = clampf(intensidad, 0.2, 1.0)
	l._duracion = duracion
	arbol.root.add_child(l)


func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.material = _mat
	add_child(r)
	_t0 = Time.get_ticks_msec()
	_actualizar()


func _process(_delta: float) -> void:
	_actualizar()


func _actualizar() -> void:
	var t := (Time.get_ticks_msec() - _t0) * 0.001
	var k := 1.0
	if t > 0.08:
		k = 1.0 - clampf((t - 0.08) / maxf(_duracion - 0.08, 0.05), 0.0, 1.0)
		k *= k
	if k <= 0.0:
		queue_free()
		return
	_mat.set_shader_parameter("cantidad", k * _intensidad)
