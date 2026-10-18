class_name EscalaGrises
extends Node
## Pasa a escala de grises las plataformas e interactuables del nivel, sin tocar sus escenas.
## Volver al look anterior: poner `cantidad` en 0 o borrar este nodo del nivel.
## No toca orbes (pickups), enemigos, jugador ni nada que ya tenga material propio (brillos aditivos, etc.).
## Se aplica en runtime: los nodos siguen editables como siempre en el editor.

@export_range(0.0, 1.0) var cantidad := 0.4        ## 0 = colores originales, 1 = gris puro
@export_range(0.5, 2.0) var brillo := 1.9
@export_range(0.5, 2.0) var contraste := 1.0
## StaticBody2D hijos directos del nivel que no son instancias de escena (las plataformas hechas a mano).
@export var incluir_plataformas := true
## Nombres de nodo excluidos de las plataformas (el suelo grande se queda con su color).
@export var excluir: PackedStringArray = ["Piso"]
## Escenas interactuables que se pasan a grises (se comparan con la ruta de la escena instanciada).
@export var escenas: PackedStringArray = [
	"res://scenes/pinchos.tscn",
	"res://scenes/plataforma_fragil.tscn", "res://scenes/plataforma_fragil_grande.tscn",
	"res://scenes/losa_peso.tscn", "res://scenes/muro_lobo.tscn", "res://scenes/muro_piedra.tscn",
	"res://scenes/grieta_lobo.tscn", "res://scenes/cristal.tscn",
	"res://scenes/tronco.tscn", "res://scenes/santuario.tscn",
]

var _mat: ShaderMaterial


func _ready() -> void:
	if Engine.is_editor_hint() or cantidad <= 0.0:
		return
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://resources/escala_grises.gdshader")
	_mat.set_shader_parameter("gris", cantidad)
	_mat.set_shader_parameter("brillo", brillo)
	_mat.set_shader_parameter("contraste", contraste)
	_aplicar.call_deferred()


func _aplicar() -> void:
	_buscar(get_parent(), true)


## Recorre el árbol: pinta las escenas interactuables (a cualquier profundidad, p. ej. dentro de "Pinchos")
## y las plataformas a mano (StaticBody2D hijos directos del nivel).
func _buscar(raiz: Node, es_nivel: bool) -> void:
	for n in raiz.get_children():
		if n == self or excluir.has(str(n.name)):
			continue
		var es_plat := es_nivel and incluir_plataformas and n is StaticBody2D and n.scene_file_path == ""
		if es_plat or escenas.has(n.scene_file_path):
			_pintar(n)
		else:
			_buscar(n, false)

func _pintar(n: Node) -> void:
	var ci := n as CanvasItem
	if ci != null and ci.material == null and not ci.use_parent_material and not (n is PointLight2D):
		ci.material = _mat
	for c in n.get_children():
		_pintar(c)
