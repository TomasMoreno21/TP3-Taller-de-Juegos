class_name JuiceCapa
## Capa de efectos en coordenadas del mundo pero SIN el tinte del nivel (CanvasModulate): así el
## blanco de los tajos, estallidos y onomatopeyas se ve blanco de verdad. Queda sobre el
## blanco y negro del parry (capa 6) y bajo el HUD (capa 10).

const NOMBRE := "JuiceCapa"


static func obtener(arbol: SceneTree) -> Node:
	var existente := arbol.root.get_node_or_null(NOMBRE)
	if existente != null:
		return existente
	var capa := CanvasLayer.new()
	capa.name = NOMBRE
	capa.layer = 7
	capa.follow_viewport_enabled = true
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	arbol.root.add_child(capa)
	return capa
