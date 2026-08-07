extends CanvasLayer

const CONTROLS := "←→ / A D mover · Espacio saltar · J atacar · T transformar · ` consola"

@onready var info: RichTextLabel = $Margin/Info


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		player.form_changed.connect(_on_form_changed)
		_set_form(player.get_form_name())
	else:
		info.text = "[color=#8ef2a0]FORMA: [b]?[/b][/color]\n[color=#c9c9c9]%s[/color]" % CONTROLS


func _on_form_changed(form_name: String) -> void:
	_set_form(form_name)


func _set_form(form_name: String) -> void:
	info.text = "[color=#8ef2a0]FORMA: [b]%s[/b][/color]\n[color=#c9c9c9]%s[/color]" % [form_name, CONTROLS]
