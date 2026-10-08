class_name ParryBN
extends CanvasLayer
## Pantalla en blanco y negro del parry perfecto: todo pierde el color menos un círculo alrededor del
## jugador. Entra de golpe, se sostiene durante el congelado y se apaga durante la cámara lenta.
## Usa el reloj real (el tiempo del juego está frenado).

const SHADER := preload("res://resources/parry_bn.gdshader")

var jugador: Node2D
var sostener := 0.3
var desvanecer := 1.0
var radio_color := 0.2
var _rect: ColorRect
var _mat: ShaderMaterial
var _t0 := 0


static func lanzar(arbol: SceneTree, jugador_: Node2D, sostener_: float, desvanecer_: float, radio: float) -> ParryBN:
	var l := ParryBN.new()
	l.jugador = jugador_
	l.sostener = sostener_
	l.desvanecer = desvanecer_
	l.radio_color = radio
	arbol.root.add_child(l)
	return l


func _ready() -> void:
	layer = 6   # sobre el mundo, bajo el HUD (10)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	add_child(_rect)
	_t0 = Time.get_ticks_msec()
	_actualizar()


func _process(_delta: float) -> void:
	_actualizar()


func _actualizar() -> void:
	var t := (Time.get_ticks_msec() - _t0) * 0.001
	var cantidad := 1.0
	var radio := radio_color
	if t < 0.07:
		# Entrada brusca: el círculo de color arranca amplio y se cierra sobre el jugador.
		cantidad = t / 0.07
		radio = lerpf(radio_color * 3.0, radio_color, t / 0.07)
	elif t > sostener:
		var k := clampf((t - sostener) / maxf(desvanecer, 0.01), 0.0, 1.0)
		cantidad = 1.0 - k * k
		radio = radio_color + k * radio_color * 2.0
		if k >= 1.0:
			queue_free()
			return
	_mat.set_shader_parameter("cantidad", cantidad)
	_mat.set_shader_parameter("radio", radio)
	var vp := get_viewport()
	if vp != null and is_instance_valid(jugador):
		var tam := vp.get_visible_rect().size
		var pos: Vector2 = vp.get_canvas_transform() * (jugador.global_position + Vector2(0, 90))
		_mat.set_shader_parameter("centro", Vector2(pos.x / tam.x, pos.y / tam.y))
		_mat.set_shader_parameter("aspecto", tam.x / tam.y)
