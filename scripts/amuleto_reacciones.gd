extends Node

## El Amuleto reacciona a lo que pasa, siempre con su voz de guardián y sin molestar:
## como mucho un comentario cada `pausa_min` segundos, nunca en plena pelea, durante una charla,
## ante el jefe ni con la ayuda en "Ligera"/"Ninguna". Las frases salen de dialogos.json
## (reaccion_puas, reaccion_racha, reaccion_quieto, reaccion_muertes) y no se repiten seguidas.

@export var pausa_min := 45.0
@export var segundos_quieto := 25.0
@export var racha_para_comentar := 6
@export var muertes_para_comentar := 3
@export var radio_pelea := 480.0

var _dialogo: Node
var _jugador: Node2D
var _t := 0.0
var _ultimo_comentario := -99.0
var _pendiente := ""            ## motivo guardado para decirlo cuando se calme la pelea
var _usadas: Dictionary = {}    ## motivo -> índice de la última frase dicha
var _pools: Dictionary = {}
var _hubo_dano_t := -99.0
var _racha_dicha := false


func _ready() -> void:
	_dialogo = get_parent()
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogos.json"))
	if datos is Dictionary:
		for motivo in ["puas", "racha", "quieto", "muertes"]:
			var e: Variant = datos.get("reaccion_" + motivo)
			if e is Dictionary:
				_pools[motivo] = e.get("lineas", [])
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	timer.timeout.connect(_revisar)
	add_child(timer)
	timer.start()


func _revisar() -> void:
	_t += 0.5
	if not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("player") as Node2D
		if _jugador != null:
			_conectar(_jugador)
		return
	if _dialogo.nivel_ayuda < 2 or not _puede_hablar():
		return
	if _pendiente != "" and not _en_pelea():
		var m := _pendiente
		_pendiente = ""
		_decir(m)
		return
	if _pendiente == "" and not _en_pelea() and _dialogo.segundos_inactivo() > segundos_quieto:
		_decir("quieto")


func _conectar(j: Node) -> void:
	if j.has_signal("dano_recibido"):
		j.dano_recibido.connect(_on_dano)
		j.racha_changed.connect(_on_racha)
		j.health_changed.connect(_on_vida)


func _on_dano(_cant: int) -> void:
	_hubo_dano_t = _t
	# Daño sin enemigos cerca = trampa (púas): aviso breve.
	if not _en_pelea() and _dialogo.nivel_ayuda == 2:
		_pedir("puas")


func _on_racha(n: int) -> void:
	if n == 0:
		_racha_dicha = false
	elif n >= racha_para_comentar and not _racha_dicha:
		_racha_dicha = true
		_pedir("racha")


func _on_vida(vida: int, _max: int) -> void:
	if vida > 0:
		return
	var prog := get_node_or_null("/root/Progresion")
	if prog == null:
		return
	prog.muertes += 1
	if prog.muertes % muertes_para_comentar == 0:
		_pedir("muertes")


## Dice el comentario ya (si se puede) o lo deja guardado hasta que haya calma.
func _pedir(motivo: String) -> void:
	if _dialogo.nivel_ayuda < 2:
		return
	if _puede_hablar() and not _en_pelea():
		_decir(motivo)
	elif _pendiente == "":
		_pendiente = motivo


func _puede_hablar() -> bool:
	if get_tree().paused or _dialogo.hay_narrativa():
		return false
	if get_tree().get_first_node_in_group("boss") != null:
		return false   # ante el jefe habla la historia, no los comentarios
	if is_instance_valid(_jugador) and _jugador.has_method("en_calma") and not _jugador.en_calma():
		return false   # no habla mientras peleás, saltás o acabás de recibir daño
	return _t - _ultimo_comentario >= pausa_min


func _en_pelea() -> bool:
	if not is_instance_valid(_jugador):
		return false
	if _t - _hubo_dano_t < 1.5 and _hay_enemigos_cerca():
		return true
	return _hay_enemigos_cerca()


func _hay_enemigos_cerca() -> bool:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Node2D and is_instance_valid(e) and (e as Node2D).global_position.distance_to(_jugador.global_position) < radio_pelea:
			return true
	return false


func _decir(motivo: String) -> void:
	var pool: Array = _pools.get(motivo, [])
	if pool.is_empty():
		return
	var i := randi() % pool.size()
	if pool.size() > 1 and i == int(_usadas.get(motivo, -1)):
		i = (i + 1) % pool.size()
	_usadas[motivo] = i
	_ultimo_comentario = _t
	_dialogo.mostrar_tip([str(pool[i])], "Amuleto", false)
