extends Area2D
## Desbloquea una forma de transformación cuando el jugador entra al área.
## Colocable en el editor: elegir `forma` (0=Humano, 1=Lobo, 2=Oso, 3=Murciélago).
## Se da una sola vez por partida (Progresion es autoload, persiste al morir/reintentar).
## Visible en el mundo: un tótem de piedra con la cabeza del animal de la forma (nodo `Totem`,
## ver totem_forma.gd) y un sello de espíritu que flota sobre él; al tocarlo estalla con cámara
## lenta y un destello del color de la forma. El tótem se apoya solo en el suelo bajo el nodo.

signal desbloqueada

@export_enum("Humano:0", "Lobo:1", "Oso:2", "Murcielago:3") var forma: int = 1
@export var una_vez := true
@export var orbe_offset := Vector2(0, 40)     ## posición del sello respecto del centro del área
@export var color_sello := Color(0, 0, 0, 0)   ## transparente = color propio de la forma (Lobo celeste, Oso ámbar, Murciélago violeta)
@export var altura_sello := 330.0               ## px sobre el suelo a los que flota el sello
@export var flote_amplitud := 10.0
@export var slowmo_duracion := 0.5
@export_range(0.05, 1.0) var slowmo_escala := 0.3
@export var sonido_desbloqueo: AudioStream = preload("res://assets/audio/sfx/gen/nivel_subido.wav")
@export var volumen_db := -4.0
@export_group("Cinemática")
@export var cinematica := false                 ## al tocar el tótem: control congelado, cámara cerca, el sello viaja al pecho del jugador y recién ahí se desbloquea
@export var cine_zoom := 1.3                    ## acercamiento de cámara (multiplica el zoom actual)
@export var cine_acercar := 0.8                 ## s que tarda la cámara en acercarse
@export var cine_pausa_tras_acercar := 0.35     ## s de calma antes de que el tótem despierte
@export var cine_viaje := 1.0                   ## s que tarda el sello en llegar al jugador
@export var cine_pausa_final := 0.9             ## s de pausa tras desbloquear, antes de devolver el control
@export var cine_barras := 90.0                 ## alto (px) de las barras negras de cine (0 = sin barras)

var _dado := false
var _t := 0.0
var _color := Color(0.66, 0.8, 1.0)

@onready var orbe: Node2D = get_node_or_null("Orbe")
@onready var totem: Node2D = get_node_or_null("Totem")


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	monitoring = true
	body_entered.connect(_on_body_entered)
	_color = color_sello if color_sello.a > 0.0 else _color_de_forma()
	if orbe != null:
		orbe.position = orbe_offset
		for n in orbe.get_children():
			if n is Polygon2D:
				(n as Polygon2D).color = Color(_color, (n as Polygon2D).color.a)
			elif n is Sprite2D:
				(n as Sprite2D).modulate = Color(_color, (n as Sprite2D).modulate.a)
			elif n is PointLight2D:
				(n as PointLight2D).color = _color
		# Ya desbloqueada (reintento tras morir): el sello no vuelve a aparecer.
		var prog := get_node_or_null("/root/Progresion")
		if una_vez and prog != null and "_extra_formas" in prog and prog._extra_formas.has(forma):
			orbe.visible = false
			_dado = true
	if totem != null:
		totem.configurar(forma, _color, orbe, _dado)
		_apoyar_en_suelo()


func _color_de_forma() -> Color:
	return preload("res://scripts/totem_forma.gd").ACENTOS.get(forma, _color)


## Baja un rayo hasta el piso y apoya ahí el tótem; el sello flota `altura_sello` sobre él.
func _apoyar_en_suelo() -> void:
	var suelo := 120.0
	# La colisión del terreno (TileMapLayer) se registra en la física unos frames después de entrar al árbol:
	# si el rayo sale demasiado pronto no encuentra el piso y el tótem queda flotando. Se reintenta.
	for i in 30:
		await get_tree().physics_frame
		if not is_inside_tree():
			return
		var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -150), global_position + Vector2(0, 800), 1)
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			suelo = (hit["position"] as Vector2).y - global_position.y
			break
	totem.position = Vector2(0, suelo)
	orbe_offset = Vector2(0, suelo - altura_sello)


func _process(delta: float) -> void:
	if orbe == null or not orbe.visible or _dado:
		return
	_t += delta
	orbe.position = orbe_offset + Vector2(0, sin(_t * 2.0) * flote_amplitud)
	orbe.rotation = sin(_t * 1.3) * 0.08
	var halo := orbe.get_node_or_null("Halo") as Sprite2D
	if halo != null:
		halo.scale = Vector2.ONE * (0.75 + 0.08 * sin(_t * 3.0))


func _on_body_entered(body: Node2D) -> void:
	if _dado:
		return
	if not body.is_in_group("player"):
		return
	var prog := get_node_or_null("/root/Progresion")
	if prog == null:
		return
	_dado = true
	if una_vez:
		set_deferred("monitoring", false)
	if cinematica and orbe != null and DisplayServer.get_name() != "headless":
		_cinematica(body, prog as Node)
		return
	_efecto_desbloqueo()
	if totem != null:
		totem.despertar()
	(prog as Node).desbloquear_forma(forma)
	desbloqueada.emit()


func _efecto_desbloqueo() -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_sfx(sonido_desbloqueo, volumen_db)
	var hs := get_node_or_null("/root/Hitstop")
	if hs != null and slowmo_duracion > 0.0:
		hs.slowmo(slowmo_duracion, slowmo_escala)
	if DisplayServer.get_name() == "headless" or orbe == null:
		return
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("punch"):
		cam.punch(1.08)
	Burst.emitir(self, orbe.global_position, _color, 32, 1.8)
	# El sello se infla y se disuelve.
	var tw := orbe.create_tween().set_parallel(true)
	tw.tween_property(orbe, "scale", orbe.scale * 2.2, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(orbe, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(func() -> void: orbe.visible = false)
	# Destello de pantalla del color de la forma.
	var capa := CanvasLayer.new()
	capa.layer = 99
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(_color, 0.55)
	capa.add_child(flash)
	get_tree().root.add_child(capa)
	var tf := flash.create_tween().set_ignore_time_scale(true)
	tf.tween_property(flash, "color:a", 0.0, 0.6)
	tf.tween_callback(capa.queue_free)


## Secuencia: congela al jugador, acerca la cámara al tótem, el tótem despierta, el sello viaja al pecho
## del jugador, estalla y recién ahí se desbloquea la forma. Devuelve el control al final.
func _cinematica(jugador: Node2D, prog: Node) -> void:
	var cam := get_viewport().get_camera_2d()
	var tree := get_tree()
	jugador.set("cinematica_activa", true)
	jugador.set("cinematica_dir", 0.0)
	jugador.velocity = Vector2.ZERO
	var capa := CanvasLayer.new()
	capa.layer = 95
	var barras: Array[ColorRect] = []
	if cine_barras > 0.0:
		for arriba in [true, false]:
			var b := ColorRect.new()
			b.color = Color.BLACK
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.set_anchors_preset(Control.PRESET_TOP_WIDE if arriba else Control.PRESET_BOTTOM_WIDE)
			b.custom_minimum_size.y = 0.0
			if not arriba:
				b.grow_vertical = Control.GROW_DIRECTION_BEGIN   # crece hacia arriba desde el borde inferior
			capa.add_child(b)
			barras.append(b)
			var tb := b.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tb.tween_property(b, "custom_minimum_size:y", cine_barras, cine_acercar)
	tree.root.add_child(capa)
	var con_cam := cam != null and cam.has_method("modo_cine")
	if con_cam:
		cam.call("modo_cine")
		var medio := (global_position + orbe.global_position) * 0.5 + Vector2(0, 40)
		var tc := cam.create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tc.tween_property(cam, "global_position", medio, cine_acercar)
		tc.tween_property(cam, "zoom", cam.zoom * cine_zoom, cine_acercar)
	await tree.create_timer(cine_acercar + cine_pausa_tras_acercar).timeout
	if not is_inside_tree():
		return
	# El tótem despierta y el sello se carga antes de partir.
	if totem != null:
		totem.despertar()
	if cam != null and cam.has_method("shake"):
		cam.call("shake", 8.0, 0.3)
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_sfx(sonido_desbloqueo, volumen_db)
	var carga := orbe.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	carga.tween_property(orbe, "scale", orbe.scale * 1.35, 0.4)
	await carga.finished
	if not is_inside_tree():
		return
	# Viaje al pecho del jugador, dejando chispas.
	var destino := jugador.global_position + Vector2(0, 70)
	var origen := orbe.global_position
	var viaje := orbe.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	viaje.tween_method(func(k: float) -> void:
		var pos := origen.lerp(destino, k) + Vector2(0, -sin(k * PI) * 90.0)
		orbe.global_position = pos
		if randf() < 0.5:
			Burst.emitir(self, pos, _color, 3, 0.6), 0.0, 1.0, cine_viaje)
	await viaje.finished
	if not is_inside_tree():
		return
	# Llegada: estallido, onda y desbloqueo.
	_efecto_desbloqueo()
	OndaTransformacion.lanzar(JuiceCapa.obtener(tree), destino, _color.lightened(0.25), 260.0, 24, 0.45)
	if jugador.has_method("squash_y"):
		jugador.squash_y(-0.18)
	prog.desbloquear_forma(forma)
	desbloqueada.emit()
	await tree.create_timer(cine_pausa_final).timeout
	if is_instance_valid(jugador):
		jugador.set("cinematica_activa", false)
	if con_cam and is_instance_valid(cam):
		cam.call("modo_normal")
	for b in barras:
		if is_instance_valid(b):
			var tq := b.create_tween()
			tq.tween_property(b, "custom_minimum_size:y", 0.0, 0.5)
	await tree.create_timer(0.6).timeout
	capa.queue_free()


func _exit_tree() -> void:
	# Si el nivel se descarga a mitad de la cinemática no deja al jugador congelado.
	var j := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if j != null and j.get("cinematica_activa") == true and _dado:
		j.set("cinematica_activa", false)
