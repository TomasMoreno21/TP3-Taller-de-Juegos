extends Node
## Alimenta al shader del terreno (terreno_cueva.gdshader) con la vista de la cámara para que las manchas,
## vetas y estratos queden fijos en el mundo y continuos entre tiles. Se corre después de la cámara.

@export var tilemap: NodePath = ^"../TileMap"


func _ready() -> void:
	process_priority = 1000
	process_physics_priority = 1000


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
