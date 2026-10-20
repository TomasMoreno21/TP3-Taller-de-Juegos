extends AudioStreamPlayer
## Música de la pelea final: entra en fundido cuando el jefe se activa, se corta si la arena
## se reinicia (muerte del jugador) y se apaga en fundido cuando el jefe muere.
## El tema, el volumen y los fundidos se cambian desde el Inspector.
## Tema actual: "(Blood) Stained Glass" de FoxSynergy (CC-BY 3.0) — ver assets/audio/musica/FUENTES.txt.

@export var volumen_db := -8.0          ## volumen de la pelea ya entrada
@export var fundido_entrada := 2.0      ## s hasta llegar a volumen_db
@export var fundido_salida := 3.0       ## s de apagado al morir el jefe
@export var corte_reinicio := 0.6       ## s de apagado al reiniciarse la arena

var _tween: Tween


func _ready() -> void:
	bus = &"Musica" if AudioServer.get_bus_index(&"Musica") >= 0 else &"Master"
	process_mode = Node.PROCESS_MODE_ALWAYS   # sigue sonando (y fundiendo) con el árbol pausado
	var jefe := get_tree().get_first_node_in_group("boss")
	if jefe == null:
		return
	if jefe.has_signal("activado"):
		jefe.activado.connect(_entrar)
	if jefe.has_signal("reiniciado"):
		jefe.reiniciado.connect(_apagar.bind(corte_reinicio))
	if jefe.has_signal("died"):
		jefe.died.connect(_apagar.bind(fundido_salida))


func _entrar() -> void:
	if stream == null:
		return
	_matar_tween()
	volume_db = -60.0
	play()
	_tween = create_tween()
	_tween.tween_property(self, "volume_db", volumen_db, fundido_entrada)


func _apagar(duracion: float) -> void:
	if not playing:
		return
	_matar_tween()
	_tween = create_tween()
	_tween.tween_property(self, "volume_db", -60.0, duracion)
	_tween.tween_callback(stop)


func _matar_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
