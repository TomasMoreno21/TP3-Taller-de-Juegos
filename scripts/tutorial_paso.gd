extends Area2D

## Paso de tutorial colocable en el editor: lo agrega a la lista de tareas y espera a que el jugador
## haga la acción pedida (como los tutoriales de Alien Force). Al cumplirlo lo tacha y pasa al
## `paso_siguiente` (otro TutorialPaso). El texto sale de res://data/dialogos.json por
## `paso_id` (mismo formato que los demás: "lineas"[0], "hablante"); `texto` es el respaldo.
## Se marca como visto en Progresion: no se repite tras morir ni al reiniciar el nivel.

enum Accion { MOVER, SALTAR, GOLPE_LIGERO, GOLPE_FUERTE, BLOQUEAR, PARRY, TRANSFORMAR }

@export var paso_id: String = ""
@export_multiline var texto: String = ""
@export var hablante: String = "Amuleto"
@export var accion: Accion = Accion.MOVER
@export var paso_siguiente: NodePath

var _activo := false
var _jugador: Node = null


func _ready() -> void:
	_cargar_texto()
	collision_layer = 0
	collision_mask = 4
	monitoring = true
	body_entered.connect(_on_body_entered)


func _cargar_texto() -> void:
	if paso_id.is_empty():
		return
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogos.json"))
	if datos is Dictionary and datos.get(paso_id) is Dictionary:
		var entrada: Dictionary = datos[paso_id]
		var lineas: Array = entrada.get("lineas", [])
		if not lineas.is_empty():
			texto = str(lineas[0])
		hablante = str(entrada.get("hablante", hablante))


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		activar(body)


func _visto() -> bool:
	var prog := get_node_or_null("/root/Progresion")
	return prog != null and not paso_id.is_empty() and prog.dialogo_visto(paso_id)


## Activa el paso (por entrar a la zona o por encadenado): aparece en la lista junto con los
## que siguen en la cadena. Lo ignora si ya se hizo.
func activar(jugador: Node = null) -> void:
	if _activo or texto.is_empty():
		return
	var dlg := get_node_or_null("/root/Dialogo")
	if dlg == null:
		return
	if dlg.hay_narrativa() and not _visto():
		_activo = true   # reserva el paso mientras espera a que termine la charla
		while dlg.hay_narrativa():
			await dlg.dialogo_terminado
		_activo = false
	if _visto():
		_pasar_al_siguiente(jugador)   # ya aprendido: no se muestra, sigue la cadena
		return
	_jugador = jugador if jugador != null else get_tree().get_first_node_in_group("player")
	if _jugador == null:
		return
	_activo = true
	_conectar()
	_registrar_cadena(dlg)
	dlg.lista_marcar_actual(paso_id)


func _conectar() -> void:
	match accion:
		Accion.GOLPE_LIGERO, Accion.GOLPE_FUERTE:
			_jugador.attack_performed.connect(_on_ataque)
		Accion.PARRY:
			_jugador.parry_exitoso.connect(_completar)
		Accion.TRANSFORMAR:
			_jugador.form_changed.connect(_on_forma)


func _desconectar() -> void:
	if _jugador == null or not is_instance_valid(_jugador):
		return
	if _jugador.attack_performed.is_connected(_on_ataque):
		_jugador.attack_performed.disconnect(_on_ataque)
	if _jugador.parry_exitoso.is_connected(_completar):
		_jugador.parry_exitoso.disconnect(_completar)
	if _jugador.form_changed.is_connected(_on_forma):
		_jugador.form_changed.disconnect(_on_forma)


func _on_ataque(tipo: String, _paso: Variant) -> void:
	if (accion == Accion.GOLPE_LIGERO and tipo == "light") or (accion == Accion.GOLPE_FUERTE and tipo == "heavy"):
		_completar()


func _on_forma(_nombre: String) -> void:
	_completar()


func _process(_delta: float) -> void:
	if _activo and accion == Accion.MOVER and absf(Input.get_axis("move_left", "move_right")) > 0.3:
		_completar()


func _input(event: InputEvent) -> void:
	if not _activo:
		return
	if (accion == Accion.SALTAR and event.is_action_pressed("jump")) \
			or (accion == Accion.BLOQUEAR and event.is_action_pressed("block")):
		_completar()


func _completar() -> void:
	if not _activo:
		return
	_activo = false
	_desconectar()
	var prog := get_node_or_null("/root/Progresion")
	if prog != null and not paso_id.is_empty():
		prog.marcar_dialogo_visto(paso_id)
	var dlg := get_node_or_null("/root/Dialogo")
	if dlg != null:
		dlg.lista_completar(paso_id)
	_pasar_al_siguiente(_jugador)


func _pasar_al_siguiente(jugador: Node) -> void:
	var sig := get_node_or_null(paso_siguiente)
	if sig == null or not sig.has_method("activar"):
		return
	# Deja un respiro para que se vea el "✓" antes de pasar al siguiente.
	await get_tree().create_timer(0.7, false).timeout
	if is_instance_valid(sig):
		sig.activar(jugador)


## Agrega a la lista este paso y los siguientes de la cadena que aún no se hicieron.
func _registrar_cadena(dlg: Node) -> void:
	var paso: Node = self
	for _i in 12:
		if paso == null or not paso.has_method("registrar_en_lista"):
			break
		paso.registrar_en_lista(dlg)
		paso = paso.get_node_or_null(paso.paso_siguiente)


func registrar_en_lista(dlg: Node) -> void:
	if not paso_id.is_empty() and not _visto() and not dlg.lista_existe(paso_id):
		dlg.lista_agregar(paso_id, texto)
