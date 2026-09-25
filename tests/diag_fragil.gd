extends SceneTree

## Verifica la persistencia de rotura de las plataformas frágiles: al romper
## una, queda registrada en Progresion; al recargar el nivel (cambio de escena
## real), la plataforma arranca rota.

const NIVEL := "res://scenes/nivel1.tscn"

var _fallos := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		_fallos += 1
		print("[FAIL] " + msg)


func _primera_fragil(nivel: Node) -> Node2D:
	for hijo in nivel.get_children():
		if hijo.is_in_group("plataforma_fragil"):
			return hijo
	return null


func _init() -> void:
	var prog: Node = load("res://scripts/progresion.gd").new()
	prog.name = "Progresion"
	root.add_child(prog)
	_check(prog != null, "Autoload Progresion presente")
	if prog == null:
		quit(_fallos)
		return

	change_scene_to_file(NIVEL)
	for i in 6:
		await process_frame

	var nivel: Node = current_scene
	var fragil: Node2D = _primera_fragil(nivel)
	_check(fragil != null, "Nivel 1: hay al menos una plataforma frágil")
	if fragil == null:
		quit(_fallos)
		return

	var clave: String = fragil._clave()
	_check(not prog.plataforma_rota(clave), "Al inicio la plataforma no está registrada como rota")
	print("[TMP] clave=", clave)
	print("[TMP] fase1=", fragil._fase)

	fragil._romper()
	_check(prog.plataforma_rota(clave), "Al romperla, queda registrada en Progresion")

	# Recarga real: volver a entrar a la misma escena.
	change_scene_to_file(NIVEL)
	for i in 6:
		await process_frame

	var nivel2: Node = current_scene
	var fragil2: Node2D = _primera_fragil(nivel2)
	_check(fragil2 != null, "Tras recargar: hay plataforma frágil")
	if fragil2 != null:
		_check(fragil2._clave() == clave, "La clave de persistencia se mantiene entre recargas")
		print("[TMP] fase2=", fragil2._fase, " visible2=", fragil2.visible,
			" visual=", fragil2.get_node_or_null("Visual").visible if fragil2.get_node_or_null("Visual") != null else "n/a")
		_check(fragil2._fase == fragil2.Fase.ROTA or not fragil2.visible
			or (fragil2.get_node_or_null("Visual") != null and not fragil2.get_node_or_null("Visual").visible),
			"Tras recargar, la plataforma rota arranca rota (fase ROTA/invisible)")

	print("[TMP] DIAG FRAGIL FIN fallos=", _fallos)
	quit(_fallos)