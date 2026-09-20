extends SceneTree

## Verificación de nivel3.tscn (v3, "Cantera del Silencio"): 5 capas de cueva (TileMap como
## nivel2) que se recorren de A (abajo-izq, continúa nivel2) a B (arriba-der, salida a nivel4).
## Se valida: largo, Oso desbloqueable antes de los troncos, ruta alcanzable, quebradizas sobre
## riesgo real, checkpoints, y que ningún enemigo/pickup/checkpoint quede incrustado o flotando.

const GAP_MAX := 200.0
const ANCHO_FRAGIL := 160.0
const HEADROOM_MIN := 400.0
const LARGO_MIN := 28000.0   # nivel2 mide ~20000 de ancho de nodos

const L1 := 4000
const L2 := 3200
const L3 := 2400
const L4 := 1600
const L5 := 800

# [nombre, x muestra, y piso]
const PISOS := [
	["L1", 600, L1], ["L1 este", 6000, L1], ["L2", 5000, L2], ["L2 oeste", 1000, L2],
	["L3", 1000, L3], ["L3 este", 5000, L3], ["L4", 5000, L4], ["L4 oeste", 800, L4],
	["L5", 4000, L5], ["Tunel A", 7300, L1], ["Alcove B", 600, L4],
]
# [enredadera, piso inferior, piso superior]
const TRAMOS_VINE := [["Enredadera1", L1, L2], ["Enredadera2", L2, L3], ["Enredadera3", L3, L4]]

var _fallos := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] " + msg)
	else:
		_fallos += 1
		print("[FAIL] " + msg)


func _solido(x: float, y: float) -> bool:
	var params := PhysicsPointQueryParameters2D.new()
	params.position = Vector2(x, y)
	params.collision_mask = 1
	return not root.world_2d.direct_space_state.intersect_point(params).is_empty()


func _piso_bajo(x: float, y: float) -> float:
	var q := PhysicsRayQueryParameters2D.create(Vector2(x, y - 150.0), Vector2(x, y + 250.0), 1)
	var hit := root.world_2d.direct_space_state.intersect_ray(q)
	return float(hit.position.y) if not hit.is_empty() else INF


func _cadena_ok(plats: Array, borde_izq: float, borde_der: float) -> bool:
	plats.sort_custom(func(a, b): return a.position.x < b.position.x)
	if plats.is_empty():
		return false
	if float(plats[0].position.x) - ANCHO_FRAGIL * 0.5 - borde_izq > GAP_MAX:
		return false
	for i in range(plats.size() - 1):
		if float(plats[i + 1].position.x) - float(plats[i].position.x) - ANCHO_FRAGIL > GAP_MAX:
			return false
	return borde_der - (float(plats[-1].position.x) + ANCHO_FRAGIL * 0.5) <= GAP_MAX


func _init() -> void:
	var nivel: Node = load("res://scenes/nivel3.tscn").instantiate()
	root.add_child(nivel)
	for i in 4:
		await physics_frame

	var player: Node2D = nivel.get_node_or_null("Player")
	_check(player != null, "Nivel3: player presente")
	var camara: Camera2D = nivel.get_node_or_null("Camara")
	_check(camara != null and camara.has_method("punch"), "Nivel3: cámara con script")
	_check(camara != null and camara.limit_bottom < 100000000 and camara.limit_top > -100000, "Nivel3: cámara con límites seteados")
	var tilemap: Node = nivel.get_node_or_null("TileMap")
	_check(tilemap != null and tilemap.get_used_cells(0).size() > 50000, "Nivel3: TileMap con terreno pintado (como nivel2)")

	# Oso desbloqueable en el nivel (no forzado desde el inicio).
	var setup: Node = nivel.get_node_or_null("SetupProgresion")
	var forzadas: Array = Array(setup.formas_forzadas) if setup != null else []
	_check(forzadas == [0, 1], "Nivel3: arranca con Humano+Lobo (Oso sin desbloquear)")
	var unlock: Node2D = nivel.get_node_or_null("UnlockOso")
	_check(unlock != null and int(unlock.forma) == 2, "Nivel3: altar desbloquea el Oso (forma=2)")

	var malos := 0
	for p in PISOS:
		var x: float = p[1]
		var y: float = p[2]
		if not (_solido(x, y + 8.0) and not _solido(x, y - 8.0) and not _solido(x, y - HEADROOM_MIN)):
			malos += 1
			print("  [AVISO] sala sin piso/aire suficiente: ", p[0])
	_check(malos == 0, "Nivel3: %d zonas de sala con piso sólido y >=%dpx de aire (%d malas)" % [PISOS.size(), int(HEADROOM_MIN), malos])

	var vine_mal := 0
	for t in TRAMOS_VINE:
		var v: Node2D = nivel.get_node_or_null(t[0])
		if v == null:
			vine_mal += 1
			continue
		var top_v: float = v.position.y - float(v.alto) * 0.5
		var bot_v: float = v.position.y + float(v.alto) * 0.5
		if not (bot_v >= float(t[1]) - 10.0 and top_v <= float(t[2]) - 30.0 and float(v.alto) <= 900.0):
			vine_mal += 1
			print("  [AVISO] enredadera no cubre el tramo: ", t[0])
	_check(vine_mal == 0, "Nivel3: las 3 enredaderas (<=900px) unen capa inferior con superior (%d malas)" % vine_mal)

	# Quebradizas: puente I (hueco L2), puente II (pozo L3), escalera ascendente L4->L5.
	var g_hueco: Array = []
	var g_pozo: Array = []
	var g_escalera: Array = []
	for hijo in nivel.get_children():
		if String(hijo.name).begins_with("PlataformaFragil"):
			var y: float = hijo.position.y
			if absf(y - (L2 + 12.0)) < 1.0:
				g_hueco.append(hijo)
			elif absf(y - (L3 + 12.0)) < 1.0:
				g_pozo.append(hijo)
			else:
				g_escalera.append(hijo)
			_check(float(hijo.tiempo_temblor) <= 1.0, "Nivel3: %s se rompe rápido (%.1fs)" % [hijo.name, hijo.tiempo_temblor])
	_check(_cadena_ok(g_hueco, 2984.0, 3928.0), "Nivel3: puente I cruza el hueco de L2 (%d plataformas, saltos <=%dpx)" % [g_hueco.size(), int(GAP_MAX)])
	_check(_cadena_ok(g_pozo, 1488.0, 2368.0), "Nivel3: puente II cruza el pozo de pinchos de L3 (%d plataformas)" % g_pozo.size())
	g_escalera.sort_custom(func(a, b): return a.position.y > b.position.y)
	var esc_ok := g_escalera.size() == 8
	for i in range(g_escalera.size() - 1):
		var dy: float = float(g_escalera[i].position.y) - float(g_escalera[i + 1].position.y)
		var dx: float = absf(float(g_escalera[i].position.x) - float(g_escalera[i + 1].position.x)) - ANCHO_FRAGIL
		if dy > 120.0 or dx > GAP_MAX:
			esc_ok = false
	_check(esc_ok, "Nivel3: escalera de 8 quebradizas sube L4->L5 con saltos <=120px de subida")
	_check(not _solido(3400.0, L2 + 100.0) and not _solido(1928.0, L3 + 100.0) and not _solido(2000.0, 1100.0), "Nivel3: bajo las quebradizas hay vacío real")
	var pinchos: Node2D = nivel.get_node_or_null("PinchosPozo")
	_check(pinchos != null and int(pinchos.cantidad) * float(pinchos.ancho_pincho) >= 860.0, "Nivel3: el pozo tiene pinchos en todo su fondo")

	var checkpoints := 0
	var encounters := 0
	var enemigos := 0
	var pickups := 0
	var troncos := 0
	var x_altar: float = unlock.position.x if unlock != null else 0.0
	var mal_puestos := 0
	for hijo in nivel.get_children():
		var n := String(hijo.name)
		if n.begins_with("Checkpoint"):
			checkpoints += 1
			if _solido(hijo.position.x, hijo.position.y):
				mal_puestos += 1
				print("  [AVISO] checkpoint dentro de terreno: ", n)
		if n.begins_with("Pickup"):
			pickups += 1
			if _solido(hijo.position.x, hijo.position.y):
				mal_puestos += 1
				print("  [AVISO] pickup dentro de terreno: ", n)
		if n.begins_with("Tronco"):
			troncos += 1
			_check(int(hijo.required_form) == 2, "Nivel3: %s exige Oso" % n)
			if n == "Tronco1":
				_check(hijo.position.x > x_altar, "Nivel3: Tronco1 está después del altar del Oso")
		if n.begins_with("Encounter"):
			encounters += 1
			for sub in hijo.get_children():
				if "tipo" in sub and "ola_asignada" in sub:
					enemigos += 1
					var pos: Vector2 = hijo.position + sub.position
					var cshape: CollisionShape2D = sub.get_node("Collision")
					var pies: float = 29.0 if sub.tipo != "chaman" else 65.4
					var piso: float = _piso_bajo(pos.x, pos.y)
					if absf((pos.y + pies) - piso) > 3.0:
						mal_puestos += 1
						print("  [AVISO] enemigo mal apoyado: ", hijo.name, "/", sub.name, " pies=", pos.y + pies, " piso=", piso)
	_check(mal_puestos == 0, "Nivel3: checkpoints, pickups y enemigos apoyados sobre el piso, sin incrustar (%d mal puestos)" % mal_puestos)
	_check(checkpoints >= 18, "Nivel3: checkpoints frecuentes (hay %d, nivel2 tiene 0)" % checkpoints)
	_check(encounters == 6, "Nivel3: 6 encuentros (nivel2 tiene 4) (hay %d)" % encounters)
	_check(enemigos == 23, "Nivel3: 23 enemigos (nivel2 tiene 12) (hay %d)" % enemigos)
	_check(pickups == 14, "Nivel3: 14 pickups guía (hay %d)" % pickups)
	_check(troncos == 5, "Nivel3: 5 troncos de Oso (3 de camino + 2 cuartos secretos) (hay %d)" % troncos)

	# Largo del recorrido principal (suma de tramos entre puntos clave).
	var pts := [Vector2(150, L1), Vector2(6600, L1), Vector2(6600, L2), Vector2(350, L2), Vector2(350, L3),
		Vector2(6600, L3), Vector2(6600, L4), Vector2(2600, L4), Vector2(2600, L5), Vector2(6500, L5)]
	var largo := 0.0
	for i in range(pts.size() - 1):
		largo += absf(pts[i + 1].x - pts[i].x) + absf(pts[i + 1].y - pts[i].y)
	_check(largo >= LARGO_MIN, "Nivel3: recorrido principal de %d px (mínimo %d, más largo que nivel2)" % [int(largo), int(LARGO_MIN)])

	var santuario: Node2D = nivel.get_node_or_null("Santuario")
	var salida: Node = nivel.get_node_or_null("SalidaNivel")
	_check(santuario != null and player != null and santuario.position.y < player.position.y - 3000.0, "Nivel3: B (Santuario) está >3000px arriba de A")
	_check(salida != null and String(salida.siguiente_escena) == "res://scenes/nivel4.tscn", "Nivel3: salida apunta a nivel4.tscn")

	for i in 90:
		await physics_frame
	_check(player != null and player.is_on_floor(), "Nivel3: el jugador aterriza en el piso de A al spawnear")

	print("[TMP] NIVEL3 DIAG FIN fallos=", _fallos)
	quit(_fallos)
