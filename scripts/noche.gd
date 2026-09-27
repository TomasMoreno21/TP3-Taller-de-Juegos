@tool
extends Node
## Noche del nivel: el CanvasModulate "Oscuridad" oscurece el mundo y las PointLight2D
## (checkpoint, pickups, salida, santuario) lo abren de verdad. El CanvasModulate no
## cruza CanvasLayers, así que el parallax de fondo recibe su propio tinte al arrancar.
## Para editar el nivel sin oscuridad: ocultar el nodo "Oscuridad" en el editor.

@export var color_noche := Color(0.58, 0.62, 0.78):
	set(v):
		color_noche = v
		if is_node_ready():
			$Oscuridad.color = v
@export var color_fondo := Color(0.58, 0.62, 0.78)
## Color de los huecos sin fondo (lo que se ve donde no hay nada dibujado). Se aplica
## mientras este nivel está activo y se restaura al salir (no afecta a otros niveles).
@export var color_vacio := Color(0.035, 0.045, 0.06)

var _clear_previo: Color


func _ready() -> void:
	$Oscuridad.color = color_noche
	if Engine.is_editor_hint():
		return
	_clear_previo = RenderingServer.get_default_clear_color()
	RenderingServer.set_default_clear_color(color_vacio)
	_tenir_fondos.call_deferred()


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		RenderingServer.set_default_clear_color(_clear_previo)


func _tenir_fondos() -> void:
	var nivel := get_parent()
	if nivel == null:
		return
	for fondo in nivel.find_children("*", "ParallaxBackground", true, false):
		if fondo.get_node_or_null("NocheFondo") != null:
			continue
		var m := CanvasModulate.new()
		m.name = "NocheFondo"
		m.color = color_fondo
		fondo.add_child(m)
