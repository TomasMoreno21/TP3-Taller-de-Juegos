extends Node2D
## Enjambre de luciérnagas de ambiente que ronda alrededor de la cámara: cada una vaga
## con rumbo aleatorio y parpadea; si queda lejos de la vista reaparece en otro punto
## de la pantalla. Así cubren todo el nivel (bosque y cuevas) sin colocarlas a mano.
## Unas pocas llevan PointLight2D real para iluminar suave lo que tienen cerca.

@export var cantidad := 22
@export var con_luz := 3                          ## cuántas llevan luz real (el resto solo brilla)
@export var color := Color(0.82, 1.0, 0.35)       ## amarillo-verdoso de luciérnaga
@export var color_nucleo := Color(1.0, 1.0, 0.75)
@export var tamano_halo := 0.22                   ## escala del halo sobre la textura de 256 px
@export var tamano_nucleo := 0.035
@export var velocidad := Vector2(25.0, 60.0)      ## rango px/s
@export var giro := 2.2                           ## qué tan errático es el rumbo (rad/s)
@export var parpadeo := Vector2(0.35, 0.9)        ## rango de pulsos por segundo
@export var brillo_min := 0.15                    ## brillo entre pulsos (0 = se apaga del todo)
@export var margen := 260.0                       ## px fuera de pantalla antes de reaparecer
@export var fundido := 1.2                        ## s que tarda en "prenderse" una que reaparece
@export_range(0.0, 1.0) var franja_alta := 0.15   ## no aparecen en el 15% superior de la vista
@export var luz_energia := 0.3
@export var luz_escala := 0.5
@export_range(0.0, 1.0) var opacidad := 0.7      ## tope de intensidad visual del halo
@export_group("Reacción al jugador")
@export var radio_huida := 220.0                  ## px: las que están más cerca se apartan si corrés
@export var fuerza_huida := 420.0                 ## impulso máximo de la huida
@export var radio_curiosidad := 460.0             ## px: si estás quieto, las de este radio se acercan despacio
@export var vel_curiosidad := 24.0
@export_range(0.0, 1.0) var tension_apagado := 0.6  ## cuánto se apagan con tensión máxima (peleas, poca vida)
@export_range(0.0, 2.0) var tension_agitacion := 0.8  ## cuánto más rápido vuelan con tensión máxima
@export_group("")

const TEX := preload("res://resources/luz_radial.tres")

var _bichos: Array[Dictionary] = []
var _t := 0.0
var _amb: Node          # autoload Ambiente (cacheado: no se busca cada frame)
var _jugador: Node2D


func _ready() -> void:
	add_to_group("reactivo")
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
			"imp": Vector2.ZERO,
		})
	_ubicar_todas.call_deferred()


func _ubicar_todas() -> void:
	var vista := _vista()
	for b in _bichos:
		(b.nodo as Node2D).global_position = _punto_en(vista)
		b.aparicion = randf()


## Golpe fuerte en `pos`: las luciérnagas cercanas salen disparadas (lo llama Ambiente).
func empujar(pos: Vector2, fuerza: float) -> void:
	for b in _bichos:
		var d: Vector2 = (b.nodo as Node2D).global_position - pos
		var dist := d.length()
		if dist < 600.0:
			b.imp += d.normalized() * fuerza * fuerza_huida * 1.6 * (1.0 - dist / 600.0)


func _process(delta: float) -> void:
	_t += delta
	var vista := _vista()
	var limite := vista.grow(margen)
	if _amb == null:
		_amb = get_node_or_null("/root/Ambiente")
	var tension: float = _amb.tension if _amb != null else 0.0
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("player") as Node2D
	var jugador := _jugador
	var vel_j := 0.0
	if jugador != null and "velocity" in jugador:
		vel_j = clampf(absf(float(jugador.velocity.x)) / 320.0, 0.0, 1.0)
	var agitacion := 1.0 + tension * tension_agitacion
	var apagado := 1.0 - tension * tension_apagado
	for b in _bichos:
		var nodo: Node2D = b.nodo
		b.rumbo += randf_range(-giro, giro) * delta * agitacion
		var dir := Vector2.from_angle(b.rumbo)
		nodo.global_position += dir * b.vel * agitacion * delta + Vector2(0.0, sin(_t * 1.7 + b.fase) * 8.0 * delta)
		if jugador != null:
			var d := nodo.global_position - (jugador.global_position + Vector2(0, -60))
			var dist := d.length()
			if dist < radio_huida and vel_j > 0.15:
				b.imp += d.normalized() * fuerza_huida * vel_j * (1.0 - dist / radio_huida) * delta * 8.0
			elif vel_j < 0.1 and dist > 90.0 and dist < radio_curiosidad and tension < 0.3:
				nodo.global_position -= d.normalized() * vel_curiosidad * delta
		if b.imp != Vector2.ZERO:
			nodo.global_position += b.imp * delta
			b.imp = b.imp.move_toward(Vector2.ZERO, 320.0 * delta)
		# Fuera de la vista (se alejó o la cámara saltó): reaparece en otro punto
		# visible y se "prende" de a poco, como una luciérnaga que empieza a brillar.
		if not limite.has_point(nodo.global_position):
			nodo.global_position = _punto_en(vista)
			b.aparicion = 0.0
		b.aparicion = minf(b.aparicion + delta / maxf(fundido, 0.01), 1.0)
		# Pulso: sube rápido, se apaga lento, como una luciérnaga real.
		var s := 0.5 + 0.5 * sin(_t * TAU * b.freq + b.fase)
		var pulso := brillo_min + (1.0 - brillo_min) * pow(s, 2.0)
		var a: float = pulso * b.brillo * b.aparicion * opacidad * apagado
		(b.halo as Sprite2D).modulate.a = a
		(b.nucleo as Sprite2D).modulate.a = minf(a * 1.4, 1.0)
		if b.luz != null:
			(b.luz as PointLight2D).energy = luz_energia * pulso * b.aparicion * apagado


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
