extends CanvasLayer

var _open := false
var _player: Node2D

@onready var panel: PanelContainer = $Panel
@onready var commands_label: RichTextLabel = $Panel/Margin/VBox/Scroll/Commands
@onready var log_label: RichTextLabel = $Panel/Margin/VBox/Log
@onready var line_edit: LineEdit = $Panel/Margin/VBox/Input

const COMANDOS := {
	"help": "Muestra esta lista.",
	"form <humano|lobo|oso|murcielago>": "Cambia la forma actual.",
	"god": "Activa/desactiva invencibilidad.",
	"mv": "Restablece vida y energía al máximo.",
	"frags <n>": "Agrega n fragmentos (sube de nivel).",
	"nivel <n>": "Fija el nivel del jugador.",
	"formas": "Desbloquea todas las transformaciones.",
	"kill": "Vuelve al humano (recorre las formas).",
	"dummy": "Crea un muñeco de entrenamiento delante del jugador.",
	"zona1": "Viaja a la Zona 1.",
	"zona2": "Viaja a la Zona 2 (nivel largo).",
}


func _ready() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("console")
	panel.visible = false
	line_edit.text_submitted.connect(_on_submitted)
	commands_label.text = _lista_comandos()
	_player = get_tree().get_first_node_in_group("player")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("console_toggle"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_open = not _open
	panel.visible = _open
	if _open:
		line_edit.grab_focus()
	else:
		line_edit.release_focus()
		imprimir("Consola cerrada")


func esta_abierta() -> bool:
	return _open


func _unhandled_input(event: InputEvent) -> void:
	if _open and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		toggle()


func _on_submitted(texto: String) -> void:
	imprimir("> " + texto)
	_ejecutar(texto.strip_edges().split(" "))
	line_edit.clear()


func imprimir(msg: String) -> void:
	log_label.text += msg + "\n"


func _lista_comandos() -> String:
	var out := ""
	for cmd in COMANDOS:
		out += "[color=#4ed67a]%s[/color]  %s\n" % [cmd, COMANDOS[cmd]]
	return out


func _ejecutar(tokens: PackedStringArray) -> void:
	if tokens.is_empty():
		return
	_player = get_tree().get_first_node_in_group("player") if _player == null else _player
	if _player == null:
		imprimir("No hay jugador.")
		return
	match tokens[0]:
		"help":
			commands_label.text = _lista_comandos()
		"form":
			if tokens.size() > 1:
				var nom := tokens[1].to_lower()
				var idx := index_forma(nom)
				if idx >= 0:
					_player.current_form = idx
					imprimir("Forma cambiada a %s" % nom)
				else:
					imprimir("Forma desconocida: %s" % nom)
		"god":
			_player.god_mode = not _player.god_mode
			imprimir("God mode: %s" % ("ON" if _player.god_mode else "OFF"))
		"mv":
			_player.heal_full()
			_player.energia = 100.0
			imprimir("Vida y energía restauradas")
		"frags":
			var cant := parseInt(tokens, 1, 1)
			get_node("/root/Progresion").add_fragmentos(cant)
			imprimir("+%d fragmentos" % cant)
		"nivel":
			var n := parseInt(tokens, 1, 1)
			get_node("/root/Progresion").set_nivel(n)
			imprimir("Nivel fijado en %d" % n)
		"formas":
			get_node("/root/Progresion").set_nivel(4)
			imprimir("Todas las transformaciones desbloqueadas")
		"kill":
			_player.current_form = 0
			imprimir("Vuelto a Humano")
		"dummy":
			var d: Node2D = (load("res://scenes/dummy_entrenamiento.tscn") as PackedScene).instantiate()
			d.global_position = _player.global_position + Vector2(_player.facing * 140, 60)
			var destino: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
			destino.add_child(d)
			imprimir("Muñeco de entrenamiento creado")
		"zona1":
			get_tree().change_scene_to_file("res://scenes/main.tscn")
			imprimir("Viajando a la Zona 1")
		"zona2":
			get_tree().change_scene_to_file("res://scenes/nivel_2.tscn")
			imprimir("Viajando a la Zona 2")
		_:
			imprimir("Comando desconocido. Escribí 'help'.")


func index_forma(nombre: String) -> int:
	match nombre:
		"humano", "base":
			return 0
		"lobo":
			return 1
		"oso":
			return 2
		"murcielago", "murcielago":
			return 3
	return -1


func parseInt(tokens: PackedStringArray, idx: int, fallback: int) -> int:
	if tokens.size() > idx and tokens[idx].is_valid_int():
		return int(tokens[idx])
	return fallback
