extends CanvasLayer

const CONTROLS := "←→ / A D mover · Espacio saltar · J combo ligero · K combo fuerte · L especial/interactuar · Shift bloquear · T transformar · ` consola\nMando: stick/DPAD mover · A saltar · X ligero · Y fuerte · B especial/interactuar · LB bloquear · RB transformar"

@onready var info: RichTextLabel = $Margin/Info
@onready var combo_label: RichTextLabel = $ComboLabel


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		player.form_changed.connect(_on_form_changed)
		player.attack_performed.connect(_on_attack_performed)
		_set_form(player.get_form_name())
	else:
		info.text = "[color=#8ef2a0]FORMA: [b]?[/b][/color]\n[color=#c9c9c9]%s[/color]" % CONTROLS


func _on_form_changed(form_name: String) -> void:
	_set_form(form_name)
	combo_label.text = ""


func _on_attack_performed(attack_type: String, step: int) -> void:
	if step < 2:
		combo_label.text = ""
		return
	var combo_name := "LIGERO" if attack_type == "light" else ("FUERTE" if attack_type == "heavy" else "ESPECIAL")
	combo_label.text = "[color=#ffd76a]COMBO %s x%d[/color]" % [combo_name, step]


func _set_form(form_name: String) -> void:
	info.text = "[color=#8ef2a0]FORMA: [b]%s[/b][/color]\n[color=#c9c9c9]%s[/color]" % [form_name, CONTROLS]
