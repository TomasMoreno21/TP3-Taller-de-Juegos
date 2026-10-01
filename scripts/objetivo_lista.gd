extends Node

## Objetivo de nivel en la lista de tareas: se tacha cuando otro nodo emite una señal
## (p. ej. un muro de piedra emite `roto`). Se coloca en el nivel y se conecta desde el Inspector.
## `veces` > 1 muestra un contador "(0/3)".

@export var texto: String = ""
@export var origen: NodePath
@export var senal: StringName = &""
@export var veces := 1
@export var retraso := 1.5   ## s tras empezar el nivel para que aparezca en la lista

var _id := ""
var _cuenta := 0


func _ready() -> void:
	_id = "obj_%s_%s" % [str(get_tree().current_scene.name) if get_tree().current_scene != null else "n", name]
	var fuente := get_node_or_null(origen)
	if fuente == null or senal == &"" or texto.is_empty() or not fuente.has_signal(senal):
		return
	var args := 0
	for s in fuente.get_signal_list():
		if s["name"] == senal:
			args = (s["args"] as Array).size()
	var cb := _on_senal if args == 0 else _on_senal.unbind(args)
	fuente.connect(senal, cb)
	if retraso > 0.0 and DisplayServer.get_name() != "headless":
		await get_tree().create_timer(retraso, false).timeout
	_agregar()


func _agregar() -> void:
	var dlg := get_node_or_null("/root/Dialogo")
	var prog := get_node_or_null("/root/Progresion")
	if dlg == null or (prog != null and prog.dialogo_visto(_id)):
		return
	dlg.lista_agregar(_id, texto, veces)


func _on_senal() -> void:
	_cuenta += 1
	var dlg := get_node_or_null("/root/Dialogo")
	if dlg == null:
		return
	if not dlg.lista_existe(_id):
		_agregar()
	dlg.lista_progreso(_id, mini(_cuenta, veces))
	if _cuenta >= veces:
		var prog := get_node_or_null("/root/Progresion")
		if prog != null:
			prog.marcar_dialogo_visto(_id)
		dlg.lista_completar(_id)
