extends Node2D
## Enjambre de luciérnagas de ambiente que ronda alrededor de la cámara: cada una vaga
## con rumbo aleatorio y parpadea; si queda lejos de la vista reaparece en otro punto
## de la pantalla. Así cubren todo el nivel (bosque y cuevas) sin colocarlas a mano.
## Unas pocas llevan PointLight2D real para iluminar suave lo que tienen cerca.

@export var cantidad := 34
@export var con_luz := 5                          ## cuántas llevan luz real (el resto solo brilla)
@export var color := Color(0.82, 1.0, 0.35)       ## amarillo-verdoso de luciérnaga
@export var color_nucleo := Color(1.0, 1.0, 0.75)
@export var tamano_halo := 0.36                   ## escala del halo sobre la textura de 256 px
@export var tamano_nucleo := 0.055
@export var velocidad := Vector2(25.0, 60.0)      ## rango px/s
@export var giro := 2.2                           ## qué tan errático es el rumbo (rad/s)
@export var parpadeo := Vector2(0.35, 0.9)        ## rango de pulsos por segundo
@export var brillo_min := 0.15                    ## brillo entre pulsos (0 = se apaga del todo)
@export var margen := 260.0                       ## px fuera de pantalla antes de reaparecer
@export var fundido := 1.2                        ## s que tarda en "prenderse" una que reaparece
@export_range(0.0, 1.0) var franja_alta := 0.15   ## no aparecen en el 15% superior de la vista
@export var luz_energia := 0.55
@export var luz_escala := 0.7

const TEX := preload("res://resources/luz_radial.tres")

var _bichos: Array[Dictionary] = []
var _t := 0.0


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for i in cantidad:
		var raiz := Node2D.new()
		# Profundidad: algunas pasan por detrás del jugador (más chicas y tenues).
		var atras := randf() < 0.4
		raiz.z_index = -1 if atras else 3
		var halo := Sprite2D.new()
		halo.texture = TEX
		halo.material = mat
		halo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		halo.scale = Vector2.ONE * tamano_halo * (0.7 if atras else 1.0)
		halo.modulate = color
		raiz.add_child(halo)
		var nucleo := Sprite2D.new()
		nucleo.texture = TEX
		nucleo.material = mat
		nucleo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		nucleo.scale = Vector2.ONE * tamano_nucleo
		nucleo.modulate = color_nucleo
		raiz.add_child(nucleo)
		var luz: PointLight2D = null
		if i < con_luz:
			luz = PointLight2D.new()
			luz.texture = TEX
			luz.texture_scale = luz_escala
			luz.color = color
			luz.energy = luz_energia
			raiz.add_child(luz)
		add_child(raiz)
		_bichos.append({
			"nodo": raiz, "halo": halo, "nucleo": nucleo, "luz": luz,
			"rumbo": randf() * TAU,
			"vel": randf_range(velocidad.x, velocidad.y),
			"freq": randf_range(parpadeo.x, parpadeo.y),
			"fase": randf() * TAU,
			"brillo": 0.6 if atras else 1.0,
			"aparicion": 1.0,
		})
	_ubicar_todas.call_deferred()


func _ubicar_todas() -> void:
	var vista := _vista()
	for b in _bichos:
		(b.nodo as Node2D).global_position = _punto_en(vista)
		b.aparicion = randf()


func _process(delta: float) -> void:
	_t += delta
	var vista := _vista()
	var limite := vista.grow(margen)
	for b in _bichos:
		var nodo: Node2D = b.nodo
		b.rumbo += randf_range(-giro, giro) * delta
		var dir := Vector2.from_angle(b.rumbo)
		nodo.global_position += dir * b.vel * delta + Vector2(0.0, sin(_t * 1.7 + b.fase) * 8.0 * delta)
		# Fuera de la vista (se alejó o la cámara saltó): reaparece en otro punto
		# visible y se "prende" de a poco, como una luciérnaga que empieza a brillar.
		if not limite.has_point(nodo.global_position):
			nodo.global_position = _punto_en(vista)
			b.aparicion = 0.0
		b.aparicion = minf(b.aparicion + delta / maxf(fundido, 0.01), 1.0)
		# Pulso: sube rápido, se apaga lento, como una luciérnaga real.
		var s := 0.5 + 0.5 * sin(_t * TAU * b.freq + b.fase)
		var pulso := brillo_min + (1.0 - brillo_min) * pow(s, 2.0)
		var a: float = pulso * b.brillo * b.aparicion
		(b.halo as Sprite2D).modulate.a = a
		(b.nucleo as Sprite2D).modulate.a = minf(a * 1.4, 1.0)
		if b.luz != null:
			(b.luz as PointLight2D).energy = luz_energia * pulso * b.aparicion


## Rectángulo visible en coordenadas del mundo (sin cámara: el viewport en el origen).
func _vista() -> Rect2:
	var tam := get_viewport_rect().size
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Rect2(Vector2.ZERO, tam)
	var t := tam / cam.zoom
	return Rect2(cam.get_screen_center_position() - t * 0.5, t)


## Punto al azar de la vista que no caiga dentro del terreno (capa 1): así no
## aparecen metidas en la tierra o la roca. Tras varios intentos acepta el último.
func _punto_en(vista: Rect2) -> Vector2:
	var y0 := vista.position.y + vista.size.y * franja_alta
	var espacio := get_world_2d().direct_space_state
	var consulta := PhysicsPointQueryParameters2D.new()
	consulta.collision_mask = 1
	var p := Vector2.ZERO
	for i in 8:
		p = Vector2(randf_range(vista.position.x, vista.end.x), randf_range(y0, vista.end.y))
		consulta.position = p
		if espacio.intersect_point(consulta, 1).is_empty():
			break
	return p
