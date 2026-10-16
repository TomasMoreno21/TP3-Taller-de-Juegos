extends Node2D
## Rampas suaves sobre el terreno en escalera. Las pendientes del TileMap están hechas de peldaños de 16 px:
## el cuerpo tenía que "subir escalones" y daba saltitos. Este nodo recorre el TileMap al cargar y rellena el
## hueco triangular de cada peldaño con un colisionador (invisible), de modo que el piso se vuelve una rampa
## continua que une las esquinas salientes. El dibujo del terreno no cambia: el jugador camina sobre la
## rampa y a lo sumo se ve apoyado unos px por encima del rincón del peldaño.
## Solo rellena escalones chicos (hasta `escalon_max_celdas` celdas de alto) y limita la inclinación
## (`angulo_max`): los muros y repisas altas quedan igual. Se activa/desactiva con `activo`.

@export var tilemap: NodePath = ^"../TileMap"
@export var activo := true
@export_range(1, 3) var escalon_max_celdas := 2          ## alto máximo (en celdas de 16 px) de un peldaño que se rellena
@export_range(2, 16) var largo_max_celdas := 8            ## largo máximo (celdas) de la rampa sobre cada peldaño
@export_range(15.0, 55.0) var angulo_max := 40.0         ## grados: peldaños más empinados que esto se dejan como escalera
## Qué parte del alto de cada peldaño rellena la rampa (1 = hasta la esquina: pisada continua, sin saltitos; menos de 1
## deja un escalón chico que el personaje sube solo, con saltitos). Para que no se vea flotando sobre los bloques el
## sprite se hunde un poco al pisar la rampa: ver `rampa_hundimiento` en el jugador.
@export_range(0.25, 1.0) var relleno := 1.0
@export_flags_2d_physics var capa_colision := 1           ## capa del terreno (la misma que usa el TileMap)

var cantidad_rampas := 0   ## informativo (tests): triángulos creados

var _celdas := {}
var _tam := 16.0


func _ready() -> void:
	if not activo or Engine.is_editor_hint():
		return
	var capa := get_node_or_null(tilemap) as TileMapLayer
	if capa == null:
		return
	_tam = float(capa.tile_set.tile_size.x)
	for c in capa.get_used_cells():
		_celdas[c] = true
	# La roca profunda agrupada en bloques de 4x4 (capa Profundo) también es sólida: sin esto aparecían "pisos" falsos dentro de la roca.
	var prof := capa.get_node_or_null("Profundo") as TileMapLayer
	if prof != null:
		for b in prof.get_used_cells():
			for dy in 4:
				for dx in 4:
					_celdas[b * 4 + Vector2i(dx, dy)] = true
	var cuerpo := StaticBody2D.new()
	cuerpo.name = "Rampas"
	cuerpo.add_to_group("rampa_suave")
	cuerpo.collision_layer = capa_colision
	cuerpo.collision_mask = 0
	cuerpo.global_transform = Transform2D.IDENTITY
	add_child(cuerpo)
	var dueno := cuerpo.create_shape_owner(cuerpo)
	var tg := tan(deg_to_rad(angulo_max))
	for c in _celdas:
		var cell: Vector2i = c
		if not _superficie(cell):
			continue
		# Peldaño a la derecha de esta celda: el vecino (x+1) tiene su piso a otra altura.
		for dy in range(-escalon_max_celdas, escalon_max_celdas + 1):
			if dy == 0:
				continue
			var vecino := Vector2i(cell.x + 1, cell.y + dy)
			if not _superficie(vecino):
				continue
			# Contacto sólido entre los dos pisos (la pared del peldaño).
			if not _pared_solida(cell, vecino):
				continue
			var tri := _triangulo(cell, vecino, tg)
			if tri.is_empty():
				continue
			var forma := ConvexPolygonShape2D.new()
			forma.points = tri
			cuerpo.shape_owner_add_shape(dueno, forma)
			cantidad_rampas += 1


## Celda sólida con aire encima (piso).
func _superficie(c: Vector2i) -> bool:
	return _celdas.has(c) and not _celdas.has(Vector2i(c.x, c.y - 1)) and not _celdas.has(Vector2i(c.x, c.y - 2))


func _pared_solida(izq: Vector2i, der: Vector2i) -> bool:
	# Sube hacia la derecha (der más alto): las celdas de la columna derecha entre ambos pisos son sólidas.
	if der.y < izq.y:
		for y in range(der.y, izq.y):
			if not _celdas.has(Vector2i(der.x, y)):
				return false
	else:
		for y in range(izq.y, der.y):
			if not _celdas.has(Vector2i(izq.x, y)):
				return false
	return true


## Triángulo que rellena el rincón sobre el piso BAJO del peldaño (apoyado en la esquina saliente del alto).
func _triangulo(izq: Vector2i, der: Vector2i, tg: float) -> PackedVector2Array:
	var sube_derecha := der.y < izq.y   # el piso derecho está más arriba
	var bajo := izq if sube_derecha else der
	var alto_celdas := absi(der.y - izq.y)
	var paso := -1 if sube_derecha else 1   # dirección en x desde el peldaño hacia el piso bajo
	# Largo disponible del piso bajo: celdas contiguas a la misma altura con aire encima.
	var largo := 0
	var x := bajo.x
	while largo < largo_max_celdas:
		var c := Vector2i(x, bajo.y)
		if not _superficie(c):
			break
		# aire libre sobre ese tramo hasta la altura del peldaño
		for k in range(1, alto_celdas + 1):
			if _celdas.has(Vector2i(x, bajo.y - k)):
				return PackedVector2Array()
		largo += 1
		x += paso
	if largo == 0:
		return PackedVector2Array()
	if relleno * float(alto_celdas) / float(largo) > tg:
		return PackedVector2Array()
	var y_bajo := float(bajo.y) * _tam
	var y_alto := y_bajo - float(alto_celdas) * _tam * relleno   # la rampa sube hasta `relleno` del alto del peldaño
	var x_pared := float(der.x) * _tam   # la pared del peldaño está en el borde izquierdo de la columna derecha
	var x_ini := x_pared + float(paso) * float(largo) * _tam
	if sube_derecha:
		# piso bajo a la izquierda: de (x_ini, y_bajo) sube hasta (x_pared, y_alto)
		return PackedVector2Array([Vector2(x_ini, y_bajo), Vector2(x_pared, y_bajo), Vector2(x_pared, y_alto)])
	# piso bajo a la derecha: de (x_pared, y_alto) baja hasta (x_ini, y_bajo)
	return PackedVector2Array([Vector2(x_pared, y_alto), Vector2(x_pared, y_bajo), Vector2(x_ini, y_bajo)])
