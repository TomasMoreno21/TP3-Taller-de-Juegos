extends Node

## "El corazón late" (nivel 3): la cueva pulsa como un latido que se acelera hacia el sello.
## Hijos = zonas (zona_latido.gd). Según en cuál esté el jugador, el CanvasModulate `oscuridad` se tiñe de
## su color y pulsa con su frecuencia e intensidad (transición suave). Todo editable desde cada zona.
## "Miedo": el corazón se alimenta del miedo de quien baja (daño recibido, vida baja, enemigos cerca): sube la
## frecuencia y la intensidad, y cada "pum" sacude la cámara. Se calma solo al limpiar la zona.

@export var oscuridad: NodePath
@export var velocidad_cambio := 1.4   ## qué tan rápido se mezcla con la zona nueva (1/s)
@export_group("Miedo")
@export var peso_dano := 0.02                 ## miedo que suma cada punto de daño recibido
@export var decaimiento := 0.2                ## miedo que se calma por segundo
@export var umbral_vida := 0.4                ## con menos de esta fracción de vida el miedo no baja de `piso_vida`
@export var piso_vida := 0.45
@export var radio_enemigos := 900.0           ## enemigos dentro de este radio mantienen un piso de miedo
@export var peso_enemigo := 0.1               ## piso de miedo por enemigo cercano
@export var tope_enemigos := 0.4              ## tope del piso por enemigos
@export var mult_frecuencia := 0.8            ## frecuencia × (1 + esto × miedo)
@export var mult_intensidad := 2.0            ## intensidad × (1 + esto × miedo)
@export_group("Sacudida")
@export var sacudida_miedo := 4.0             ## fuerza del shake de cámara en cada pum con miedo = 1
@export var miedo_min_sacudida := 0.15        ## por debajo de este miedo (y sin sacudida de zona) no tiembla
@export_group("Sello")
@export var muro_sello: NodePath              ## al romperse: silencio y luego el corazón se desboca
@export var silencio_sello := 2.2             ## s sin latido tras romper el sello

var _osc: CanvasModulate
var _zonas: Array = []
var _zona_actual: Node
var _color := Color.WHITE
var _frec := 0.4
var _int := 0.02
var _t := 0.0
var _inicial := true
var _jugador_cache: Node2D
var _pulso := 0.0
var _pulso_prev := 0.0
var _miedo := 0.0
var _piso := 0.0
var _piso_t := 0.0
var _silencio := 0.0
var _conectado := false


## Intensidad del latido actual (la usan efectos que acompañan la tensión, como las motas violetas).
func intensidad_actual() -> float:
	return 0.0 if _silencio > 0.0 else _int * (1.0 + mult_intensidad * _miedo)


## Forma del latido ahora mismo (0 en reposo, ~1 en el pico del "pum"). Las venas de la pared (vena_latido.gd) la usan.
func pulso_actual() -> float:
	return _pulso


## Miedo actual (0..1). Lo lee el borde de pantalla (borde_miedo.gd).
func miedo_actual() -> float:
	return _miedo


## Suma miedo de golpe y hace sonar un "pum" inmediato.
func sobresaltar(cantidad: float) -> void:
	_miedo = clampf(_miedo + cantidad, 0.0, 1.0)
	_t = 0.0


## Corta el latido `seg` segundos; al volver, el corazón arranca desbocado (miedo = 1).
func silenciar(seg: float) -> void:
	_silencio = seg


func _ready() -> void:
	add_to_group("latido_cueva")
	_osc = get_node_or_null(oscuridad) as CanvasModulate
	for z in get_children():
		if z.has_method("contiene"):
			_zonas.append(z)
	if _osc != null:
		_color = _osc.color
	var muro := get_node_or_null(muro_sello)
	if muro != null and muro.has_signal("roto"):
		muro.connect("roto", func() -> void: silenciar(silencio_sello))


func _on_dano(cantidad: int) -> void:
	sobresaltar(float(cantidad) * peso_dano)


func _actualizar_piso(jugador: Node2D) -> void:
	var piso := 0.0
	var vida = jugador.get("health")
	if vida != null and float(vida) / 100.0 < umbral_vida:
		piso = piso_vida
	var cerca := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Node2D and (e as Node2D).global_position.distance_squared_to(jugador.global_position) < radio_enemigos * radio_enemigos:
			cerca += 1
	_piso = maxf(piso, minf(float(cerca) * peso_enemigo, tope_enemigos))


func _sacudir(fuerza: float, dur: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(fuerza, dur)


func _process(delta: float) -> void:
	if _osc == null:
		return
	if not is_instance_valid(_jugador_cache):
		_jugador_cache = get_tree().get_first_node_in_group("player") as Node2D
		_conectado = false
	var jugador := _jugador_cache
	if jugador != null:
		if not _conectado and jugador.has_signal("dano_recibido"):
			jugador.connect("dano_recibido", _on_dano)
			_conectado = true
		for z in _zonas:
			if z.contiene(jugador.global_position):
				var k := 1.0 if _inicial else clampf(velocidad_cambio * delta, 0.0, 1.0)
				_color = _color.lerp(z.color_ambiente, k)
				_frec = lerpf(_frec, z.frecuencia, k)
				_int = lerpf(_int, z.intensidad, k)
				if z != _zona_actual:
					if not _inicial and z.sacudida_entrada > 0.0:
						_t = 0.0
						_sacudir(z.sacudida_entrada, 0.7)
					_zona_actual = z
				_inicial = false
				break
		_piso_t -= delta
		if _piso_t <= 0.0:
			_piso_t = 0.3
			_actualizar_piso(jugador)
	# el miedo se calma hasta su piso
	if _miedo > _piso:
		_miedo = maxf(_miedo - decaimiento * delta, _piso)
	else:
		_miedo = _piso

	if _silencio > 0.0:
		_silencio -= delta
		_pulso = 0.0
		_pulso_prev = 0.0
		_osc.color = _color
		if _silencio <= 0.0:
			sobresaltar(1.0)
			_sacudir(9.0, 0.6)
		return

	_t += delta * _frec * (1.0 + mult_frecuencia * _miedo)
	var f := fposmod(_t, 1.0)
	# doble latido: "pum-pum"
	var p := exp(-pow(f * 9.0, 2.0)) + exp(-pow((f - 1.0) * 9.0, 2.0)) + 0.6 * exp(-pow((f - 0.22) * 9.0, 2.0))
	_pulso = p
	if p > 0.6 and _pulso_prev <= 0.6:
		var fuerza: float = sacudida_miedo * _miedo if _miedo >= miedo_min_sacudida else 0.0
		if _zona_actual != null:
			fuerza += float(_zona_actual.sacudida)
		if fuerza > 0.3:
			_sacudir(fuerza, 0.14)
	_pulso_prev = p
	_osc.color = _color * (1.0 + intensidad_actual() * p)
