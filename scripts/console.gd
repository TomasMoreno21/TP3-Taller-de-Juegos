extends CanvasLayer

const COMMANDS := {
	"help": {"usage": "help", "desc": "Lista los comandos disponibles"},
	"form": {"usage": "form <humano|oso|lobo|buho>", "desc": "Cambia de forma"},
	"god": {"usage": "god", "desc": "Activa/desactiva invencibilidad"},
	"hp": {"usage": "hp <n>", "desc": "Fija la vida del jugador"},
	"heal": {"usage": "heal", "desc": "Restaura la vida al máximo"},
	"spawn_enemy": {"usage": "spawn_enemy", "desc": "Instancia un enemigo cerca del jugador"},
	"kill_enemies": {"usage": "kill_enemies", "desc": "Elimina todos los enemigos"},
	"spawn_wave": {"usage": "spawn_wave", "desc": "Activa el encuentro de enemigos de la zona"},
	"speed": {"usage": "speed <mult>", "desc": "Escala de tiempo (0.5 = slow-mo)"},
	"gravity": {"usage": "gravity <val>", "desc": "Override de gravedad (-1 = normal)"},
	"tp": {"usage": "tp <x> <y>", "desc": "Teletransporta al jugador"},
	"pos": {"usage": "pos", "desc": "Imprime la posición del jugador"},
	"hitbox": {"usage": "hitbox", "desc": "Muestra/oculta las cajas de colisión"},
	"clear": {"usage": "clear", "desc": "Limpia el log de la consola"},
	"quit": {"usage": "quit", "desc": "Cierra el juego"},
}

const FORM_IDS := {
	"humano": 0,
	"oso": 1,
	"lobo": 2,
	"buho": 3,
}

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

var _open := false

@onready var panel: PanelContainer = $Panel
@onready var commands_label: RichTextLabel = $Panel/Margin/VBox/Scroll/Commands
@onready var log_label: RichTextLabel = $Panel/Margin/VBox/Log
@onready var line_edit: LineEdit = $Panel/Margin/VBox/Input


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	line_edit.text_submitted.connect(_on_submitted)
	_build_commands_list()
	_log("Consola lista. Presioná ` para abrir.")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("console_toggle"):
		_toggle()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and _open:
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	_open = not _open
	panel.visible = _open
	get_tree().paused = _open
	if _open:
		line_edit.clear()
		line_edit.grab_focus()
	else:
		line_edit.release_focus()


func _build_commands_list() -> void:
	commands_label.text = ""
	for cmd in COMMANDS:
		var data: Dictionary = COMMANDS[cmd]
		commands_label.append_text("[color=#8ef2a0]%s[/color]  [color=#c9c9c9]%s[/color]\n" % [data["usage"], data["desc"]])


func _on_submitted(text: String) -> void:
	line_edit.clear()
	var parts := text.strip_edges().split(" ", false)
	if parts.is_empty() or parts[0] == "":
		return
	var cmd := parts[0].to_lower()
	var args := parts.slice(1)
	_log("[color=#7cb8ff]> %s[/color]" % text)
	_execute(cmd, args)


func _execute(cmd: String, args: PackedStringArray) -> void:
	match cmd:
		"help":
			_log("Escribí cualquier comando de la lista. La ayuda completa está en el panel superior.")
		"form":
			_cmd_form(args)
		"god":
			_cmd_god()
		"hp":
			_cmd_hp(args)
		"heal":
			_cmd_heal()
		"spawn_enemy":
			_cmd_spawn_enemy()
		"kill_enemies":
			_cmd_kill_enemies()
		"spawn_wave":
			_cmd_spawn_wave()
		"speed":
			_cmd_speed(args)
		"gravity":
			_cmd_gravity(args)
		"tp":
			_cmd_tp(args)
		"pos":
			_cmd_pos()
		"hitbox":
			_cmd_hitbox()
		"clear":
			log_label.clear()
		"quit":
			get_tree().quit()
		_:
			_log("[color=#ff8080]Comando desconocido: '%s'. Escribí 'help'.[/color]" % cmd)


func _cmd_form(args: PackedStringArray) -> void:
	var player := _player()
	if player == null:
		_log("[color=#ff8080]No hay jugador en escena.[/color]")
		return
	if args.is_empty() or not FORM_IDS.has(args[0].to_lower()):
		_log("[color=#ff8080]Forma inválida. Usá: humano, oso, lobo o buho.[/color]")
		return
	player.set_form(FORM_IDS[args[0].to_lower()])
	_log("Forma cambiada a: %s" % player.get_form_name())


func _cmd_god() -> void:
	var player := _player()
	if player == null:
		_log("[color=#ff8080]No hay jugador en escena.[/color]")
		return
	player.god_mode = not player.god_mode
	_log("Invencibilidad: %s" % ("ON" if player.god_mode else "OFF"))


func _cmd_hp(args: PackedStringArray) -> void:
	var player := _player()
	if player == null:
		_log("[color=#ff8080]No hay jugador en escena.[/color]")
		return
	if args.is_empty() or not args[0].is_valid_int():
		_log("[color=#ff8080]Uso: hp <n>[/color]")
		return
	player.set_health(int(args[0]))
	_log("Vida fijada en: %s" % args[0])


func _cmd_heal() -> void:
	var player := _player()
	if player == null:
		_log("[color=#ff8080]No hay jugador en escena.[/color]")
		return
	player.heal_full()
	_log("Vida restaurada al máximo.")


func _cmd_spawn_enemy() -> void:
	var player := _player()
	var enemy: CharacterBody2D = ENEMY_SCENE.instantiate()
	var spawn_pos := Vector2(400, -100)
	if player != null:
		spawn_pos = player.global_position + Vector2(player.facing * 120.0, 0.0)
	if player != null and player.get_parent() != null:
		player.get_parent().add_child(enemy)
	else:
		get_tree().root.add_child(enemy)
	enemy.global_position = spawn_pos
	_log("Enemigo generado.")


func _cmd_kill_enemies() -> void:
	var enemies := get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		e.die()
	_log("Enemigos eliminados: %d" % enemies.size())


func _cmd_spawn_wave() -> void:
	var encounter := get_tree().get_first_node_in_group("encounter")
	if encounter == null:
		_log("[color=#ff8080]No hay encuentro en escena.[/color]")
		return
	encounter.debug_activate()
	_log("Encuentro activado.")


func _cmd_speed(args: PackedStringArray) -> void:
	if args.is_empty() or not args[0].is_valid_float():
		_log("[color=#ff8080]Uso: speed <mult>[/color]")
		return
	Engine.time_scale = clampf(float(args[0]), 0.05, 5.0)
	_log("Escala de tiempo: x%s" % args[0])


func _cmd_gravity(args: PackedStringArray) -> void:
	var player := _player()
	if player == null:
		_log("[color=#ff8080]No hay jugador en escena.[/color]")
		return
	if args.is_empty() or not args[0].is_valid_float():
		_log("[color=#ff8080]Uso: gravity <val> (-1 = normal)[/color]")
		return
	var value := float(args[0])
	if value < 0.0:
		player.clear_gravity_override()
		_log("Gravedad: normal.")
	else:
		player.set_gravity_override(value)
		_log("Gravedad override: %s" % args[0])


func _cmd_tp(args: PackedStringArray) -> void:
	var player := _player()
	if player == null:
		_log("[color=#ff8080]No hay jugador en escena.[/color]")
		return
	if args.size() < 2 or not args[0].is_valid_float() or not args[1].is_valid_float():
		_log("[color=#ff8080]Uso: tp <x> <y>[/color]")
		return
	player.global_position = Vector2(float(args[0]), float(args[1]))
	player.velocity = Vector2.ZERO
	_log("Jugador movido a: %s, %s" % [args[0], args[1]])


func _cmd_pos() -> void:
	var player := _player()
	if player == null:
		_log("[color=#ff8080]No hay jugador en escena.[/color]")
		return
	_log("Posición: %s" % str(player.global_position))


func _cmd_hitbox() -> void:
	var viewport := get_viewport()
	viewport.debug_collisions = not viewport.debug_collisions
	_log("Hitboxes visibles: %s" % ("ON" if viewport.debug_collisions else "OFF"))


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player")


func _log(msg: String) -> void:
	log_label.append_text(msg + "\n")
