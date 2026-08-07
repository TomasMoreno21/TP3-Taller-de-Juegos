extends SceneTree


func _init() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var hud = scene.get_node("UI/Hud")
	var player = scene.get_node("Player")
	print("HUD inicial: " + hud.info.text.replace("\n", " | "))
	player.set_form(1)
	await process_frame
	print("HUD tras oso: contiene 'Espíritu del Oso': " + str(hud.info.text.contains("Espíritu del Oso")))
	print("HUD controles: contiene 'Espacio': " + str(hud.info.text.contains("Espacio")))
	quit(0)
