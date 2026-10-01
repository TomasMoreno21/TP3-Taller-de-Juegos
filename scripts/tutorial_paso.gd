extends Area2D

## Paso de tutorial colocable en el editor: lo agrega a la lista de tareas y espera a que el jugador
## haga la acción pedida (como los tutoriales de Alien Force). Al cumplirlo lo tacha y pasa al
## `paso_siguiente`. El texto sale de res://data/dialogos.json por `paso_id` ("lineas"[0], "hablante",
## y opcionales "pista" y "cierre"); `texto` es el respaldo.
## Se adapta al jugador: si ya hizo la acción (o la hace antes de su turno) se tacha sola; si se
## traba `segundos_pista` segundos, el Amuleto da una pista. Respeta el nivel de ayuda elegido.
## Se marca como visto en Progresion: no se repite tras morir ni al reiniciar el nivel.

enum Accion { MOVER, SALTAR, GOLPE_LIGERO, GOLPE_FUERTE, BLOQUEAR, PARRY, TRANSFORMAR }

const CLAVES := ["mover", "saltar", "golpe_ligero", "golpe_fuerte", "bloquear", "parry", "transformar"]

@export var paso_id: String = ""
@export_multiline var texto: String = ""
@export var hablante: String = "Amuleto"
@export var accion: Accion = Accion.MOVER
@export var paso_siguiente: NodePath
@export var segundos_pista := 20.0

var _activo := false
var _jugador: Node = null
var _pista := ""
var _cierre := ""
var _espera := 0.0
var _pista_dada := false


func _ready() -> void:
	_cargar_texto()
	collision_layer = 0
	collision_mask = 4
	monitoring = true
	body_entered.connect(_on_body_entered)
	var dlg := get_node_or_null("/root/Dialogo")
	if dlg != null:
		dlg.accion_hecha.connect(_on_accion_hecha)


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
		_pista = str(entrada.get("pista", ""))
		_cierre = str(entrada.get("cierre", ""))


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		activar(body)


func _visto() -> bool:
	var prog := get_node_or_null("/root/Progresion")
	return prog != null and not paso_id.is_empty() and prog.dialogo_visto(paso_id)


func _clave() -> String:
	return CLAVES[accion]


func _ya_hecho(dlg: Node) -> bool:
	return dlg.ya_hizo(_clave())


## Activa el paso (por entrar a la zona o por encadenado): aparece en la lista junto con los
## que siguen en la cadena. Lo ignora si ya se hizo.
func activar(jugador: Node = null) -> void:
	if _activo or texto.is_empty():
		return
	var dlg := get_node_or_null("/root/Dialogo")
	if dlg == null or dlg.nivel_ayuda == 0:
		return
	if dlg.hay_narrativa() and not _visto():
		_activo = true   # reserva el paso mientras espera a que termine la charla
		while dlg.hay_narrativa():
			await dlg.dialogo_terminado
		_activo = false
	if _visto() or _ya_hecho(dlg):
		_marcar_visto()
		_pasar_al_siguiente(jugador)   # ya aprendido: no se muestra, sigue la cadena
		return
	_jugador = jugador if jugador != null else get_tree().get_first_node_in_group("player")
	if _jugador == null:
		return
	_activo = true
	_espera = 0.0
	_pista_dada = false
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


## El jugador hizo la acción de este paso (aunque no sea su turno): se tacha sola.
func _on_accion_hecha(clave: String) -> void:
	if clave != _clave() or _visto():
		return
	if _activo and _jugador != null:
		_completar()
		return
	var dlg := get_node_or_null("/root/Dialogo")
	if dlg != null and not _activo and dlg.lista_existe(paso_id):
		_marcar_visto()
		dlg.lista_completar(paso_id)


func _process(delta: float) -> void:
	if not _activo:
		return
	if accion == Accion.MOVER and absf(Input.get_axis("move_left", "move_right")) > 0.3:
		_completar()
		return
	if _pista_dada or _pista.is_empty():
		return
	_espera += delta
	if _espera >= segundos_pista:
		_dar_pista()


## Si el jugador se traba, el Amuleto da una pista en su voz y la tarea late en la lista.
func _dar_pista() -> void:
	_pista_dada = true
	var dlg := get_node_or_null("/root/Dialogo")
	if dlg == null or dlg.nivel_ayuda < 2:
		return
	dlg.lista_pista(paso_id)
	dlg.mostrar_tip([_pista], hablante, false)


func _input(event: InputEvent) -> void:
	if not _activo:
		return
	if (accion == Accion.SALTAR and event.is_action_pressed("jump")) \
			or (accion == Accion.BLOQUEAR and event.is_action_pressed("block")):
		_completar()


func _marcar_visto() -> void:
	var prog := get_node_or_null("/root/Progresion")
	if prog != null and not paso_id.is_empty():
		prog.marcar_dialogo_visto(paso_id)


func _completar() -> void:
	if not _activo:
		return
	_activo = false
	_desconectar()
	_marcar_visto()
	var dlg := get_node_or_null("/root/Dialogo")
	if dlg != null:
		dlg.lista_completar(paso_id)
	if get_node_or_null(paso_siguiente) == null and not _cierre.is_empty():
		_cerrar_bloque(dlg)
	_pasar_al_siguiente(_jugador)


## Último paso de una cadena: el Amuleto lo reconoce con una frase sobria.
func _cerrar_bloque(dlg: Node) -> void:
	await get_tree().create_timer(1.0, false).timeout
	if dlg != null and dlg.nivel_ayuda == 2 and not dlg.hay_narrativa():
		dlg.celebrar()
		dlg.mostrar_tip([_cierre], hablante, false)


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
	if not paso_id.is_empty() and not _visto() and not _ya_hecho(dlg) and not dlg.lista_existe(paso_id):
		dlg.lista_agregar(paso_id, texto)
