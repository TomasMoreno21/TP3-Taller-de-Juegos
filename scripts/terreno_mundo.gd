extends Node
## Alimenta al shader del terreno (terreno_cueva.gdshader) con la vista de la cámara para que las manchas,
## vetas y estratos queden fijos en el mundo y continuos entre tiles. Se corre después de la cámara.

@export var tilemap: NodePath = ^"../TileMap"
@export var profundidad := true                      ## genera el campo de distancia al aire para el degradado de profundidad
@export var prof_max_tiles := 40                     ## tiles de distancia que cubre el degradado (más allá = igual de oscuro)

const _TILE := 16.0


func _ready() -> void:
	process_priority = 1000
	process_physics_priority = 1000
	if profundidad:
		_generar_campo()


func _process(_delta: float) -> void:
	var tm := get_node_or_null(tilemap) as CanvasItem
	if tm == null or not (tm.material is ShaderMaterial):
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var m := tm.material as ShaderMaterial
	m.set_shader_parameter("cam_centro", cam.get_screen_center_position())
	m.set_shader_parameter("vista_mundo", get_viewport().get_visible_rect().size / cam.zoom)


## Distancia (en tiles) de cada celda de roca al aire más cercano (transformada de distancia en dos pasadas).
## Se guarda como textura de 1 texel por tile; el shader la lee con filtro lineal, así el degradado es suave.
func _generar_campo() -> void:
	var capa := get_node_or_null(tilemap) as TileMapLayer
	if capa == null or not (capa.material is ShaderMaterial):
		return
	var r := capa.get_used_rect().grow(prof_max_tiles + 2)
	var w := r.size.x
	var h := r.size.y
	var d := PackedFloat32Array()
	d.resize(w * h)
	for c in capa.get_used_cells():
		d[(c.y - r.position.y) * w + (c.x - r.position.x)] = 1000.0
	var diag := 1.4142
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var i := y * w + x
			if d[i] == 0.0:
				continue
			d[i] = minf(d[i], minf(minf(d[i - 1] + 1.0, d[i - w] + 1.0), minf(d[i - w - 1] + diag, d[i - w + 1] + diag)))
	for y in range(h - 2, 0, -1):
		for x in range(w - 2, 0, -1):
			var i := y * w + x
			if d[i] == 0.0:
				continue
			d[i] = minf(d[i], minf(minf(d[i + 1] + 1.0, d[i + w] + 1.0), minf(d[i + w + 1] + diag, d[i + w - 1] + diag)))
	var bytes := PackedByteArray()
	bytes.resize(w * h)
	for i in w * h:
		bytes[i] = int(clampf(d[i] / float(prof_max_tiles), 0.0, 1.0) * 255.0)
	var m := capa.material as ShaderMaterial
	m.set_shader_parameter("campo", ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_R8, bytes)))
	m.set_shader_parameter("campo_origen", Vector2(r.position) * _TILE)
	m.set_shader_parameter("campo_tam", Vector2(r.size) * _TILE)
	m.set_shader_parameter("campo_max", float(prof_max_tiles) * _TILE)
