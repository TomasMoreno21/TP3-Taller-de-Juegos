extends Node
## Antesala de un combate (la crea Encounter; se ajusta con los `antesala_*` del Encounter):
## al acercarse a la arena el ambiente se calla y una viñeta fría cierra la pantalla, de a poco.
## Es un aviso subliminal: nada de iconos ni textos. Al empezar la pelea todo vuelve a la normalidad.

const CAPA_OVERLAY := 6   # sobre la viñeta de noche (5), bajo el HUD (10)

var distancia := 1500.0
var silencio := 1.0   # factor 0..1 del silencio máximo del ambiente (el volumen lo fija ambiente_sonoro)
var vineta := 0.25
var suavizado := 2.0
var k := 0.0   # intensidad actual 0..1

var _enc: Area2D
var _overlay: TextureRect


func configurar(enc: Area2D, dist: float, sil: float, vin: float, suav: float) -> void:
	_enc = enc
	distancia = maxf(dist, 1.0)
	silencio = sil
	vineta = vin
	suavizado = suav


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return   # sin pantalla no hace falta el overlay; el audio sí se calcula
	var capa := CanvasLayer.new()
	capa.layer = CAPA_OVERLAY
	add_child(capa)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.45, 1.0])
	grad.colors = PackedColorArray([Color(0.05, 0.1, 0.2, 0.0), Color(0.03, 0.07, 0.16, 1.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	_overlay = TextureRect.new()
	_overlay.texture = tex
	_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.modulate.a = 0.0
	capa.add_child(_overlay)


## Intensidad objetivo: 1 junto a la arena, 0 a `distancia` px o más de su borde (o si la pelea ya empezó).
func objetivo() -> float:
	if _enc == null or _enc.estado != 0:   # 0 = Estado.INACTIVE
		return 0.0
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	if jugador == null:
		return 0.0
	var fuera := maxf(absf(jugador.global_position.x - _enc.arena_center.x) - _enc.arena_medio_ancho, 0.0)
	return smoothstep(0.0, 1.0, 1.0 - clampf(fuera / distancia, 0.0, 1.0))


func _process(delta: float) -> void:
	k = lerpf(k, objetivo(), clampf(suavizado * delta, 0.0, 1.0))
	if k < 0.002:
		k = 0.0
	var amb := get_tree().get_first_node_in_group("ambiente_sonoro")
	if amb != null:
		amb.pedir_silencio(self, k * silencio)
	if _overlay != null:
		_overlay.modulate.a = k * vineta
