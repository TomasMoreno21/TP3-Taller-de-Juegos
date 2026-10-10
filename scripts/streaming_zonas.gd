extends Node
## Carga por cercanía: los objetos del nivel que están lejos de la cámara y del jugador se "duermen"
## (process_mode = DISABLED: sin _process/_physics_process ni colisión) y se despiertan al acercarse.
## Todo sigue en la escena (editable en Godot) y conserva su estado: no se libera nada.
## Se agrega como hijo del nivel; gestiona los nodos cuyo script está en `scripts_gestionados`.
## También apaga (`enabled = false`) las luces 2D fijas lejanas del nivel y las vuelve a encender al acercarse:
## nunca toca la luz del jugador ni las que se mueven solas (luciérnagas).

## Distancia (px) a la cámara o al jugador dentro de la cual los objetos están despiertos.
@export var radio_activo := Vector2(3200, 2200)
## Para dormir un objeto hay que superar radio_activo × este factor (evita parpadeos en el borde).
@export_range(1.0, 2.0, 0.05) var histeresis := 1.25
@export_range(0.05, 1.0, 0.05) var intervalo := 0.2
## Apagar las PointLight2D lejanas (cada luz encendida recorre los objetos de su zona al dibujar).
@export var dormir_luces := true
## Scripts cuyas luces NO se gestionan (se mueven solas y siempre están cerca de la cámara).
@export var scripts_luces_excluidos := PackedStringArray(["luciernagas_ambiente.gd"])
@export var scripts_gestionados := PackedStringArray([
	"decorativo.gd", "pinchos.gd", "pickup.gd", "pickup_vida.gd",
	"enredadera.gd", "plataforma_fragil.gd", "rompible.gd",
])

var _nodos: Array[Node2D] = []
var _dormidos := {}   ## Node2D -> process_mode original
var _luces: Array[Light2D] = []
var _luces_dormidas := {}   ## Light2D -> true (las que apagó este nodo; vuelven a enabled = true)
var _t := 0.0
var _jugador: Node2D


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	await get_tree().process_frame   # que todo el nivel termine su _ready
	_recolectar(get_parent())
	_actualizar()


func _process(delta: float) -> void:
	_t += delta
	if _t >= intervalo:
		_t = 0.0
		_actualizar()


func _recolectar(n: Node) -> void:
	for c in n.get_children():
		if dormir_luces and c is Light2D and (c as Light2D).enabled and _luz_gestionable(c):
			_luces.append(c)
		var s := c.get_script() as Script
		if c is Node2D and s != null and scripts_gestionados.has(s.resource_path.get_file()) \
				and c.process_mode == Node.PROCESS_MODE_INHERIT:
			_nodos.append(c)
		_recolectar(c)


## Una luz es gestionable si no es del jugador ni cuelga de un nodo que la mueve solo.
func _luz_gestionable(luz: Node) -> bool:
	var a := luz
	while a != null:
		if a.is_in_group("player"):
			return false
		var s := a.get_script() as Script
		if s != null and scripts_luces_excluidos.has(s.resource_path.get_file()):
			return false
		a = a.get_parent()
	return true


func _actualizar_luces(centros: Array[Vector2], rd: Vector2) -> void:
	var i := _luces.size() - 1
	while i >= 0:
		var l := _luces[i]
		if not is_instance_valid(l):
			_luces_dormidas.erase(l)
			_luces.remove_at(i)
			i -= 1
			continue
		var cerca := false
		var lejos := true
		var p := l.global_position
		for c in centros:
			var d := (p - c).abs()
			if d.x <= radio_activo.x and d.y <= radio_activo.y:
				cerca = true
			if d.x <= rd.x and d.y <= rd.y:
				lejos = false
		if cerca and _luces_dormidas.has(l):
			l.enabled = true
			_luces_dormidas.erase(l)
		elif lejos and not _luces_dormidas.has(l) and l.enabled:
			l.enabled = false
			_luces_dormidas[l] = true
		i -= 1


func _actualizar() -> void:
	var centros: Array[Vector2] = []
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		centros.append(cam.get_screen_center_position())
	if not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("player") as Node2D
	if _jugador != null:
		centros.append(_jugador.global_position)
	if centros.is_empty():
		return
	var rd := radio_activo * histeresis
	_actualizar_luces(centros, rd)
	var i := _nodos.size() - 1
	while i >= 0:
		var n := _nodos[i]
		if not is_instance_valid(n):
			_dormidos.erase(n)
			_nodos.remove_at(i)
			i -= 1
			continue
		var cerca := false
		var lejos := true
		var p := n.global_position
		for c in centros:
			var d := (p - c).abs()
			if d.x <= radio_activo.x and d.y <= radio_activo.y:
				cerca = true
			if d.x <= rd.x and d.y <= rd.y:
				lejos = false
		if cerca and _dormidos.has(n):
			n.process_mode = _dormidos[n]
			_dormidos.erase(n)
		elif lejos and not _dormidos.has(n) and n.process_mode == Node.PROCESS_MODE_INHERIT:
			_dormidos[n] = n.process_mode
			n.process_mode = Node.PROCESS_MODE_DISABLED
		i -= 1
