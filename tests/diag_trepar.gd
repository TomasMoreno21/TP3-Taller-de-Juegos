extends SceneTree
## Trepar la liana: el sprite se corre hacia atrás (manos sobre la liana), se puede girar de un lado a
## otro sin soltarla y al soltarse el sprite vuelve a su sitio.

var fallos := 0

func _chk(ok: bool, msg: String) -> void:
	if ok:
		print("ok   ", msg)
	else:
		fallos += 1
		print("FAIL ", msg)


func _initialize() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	var suelo := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(3000, 200)
	cs.shape = r
	suelo.add_child(cs)
	suelo.position = Vector2(640, 700)
	raiz.add_child(suelo)
	var v: Area2D = load("res://scenes/enredadera.tscn").instantiate()
	v.position = Vector2(640, 400)
	raiz.add_child(v)
	var p: CharacterBody2D = load("res://scenes/player.tscn").instantiate()
	p.position = Vector2(640, 560)
	raiz.add_child(p)
	for i in 50:
		await physics_frame
	var vis: AnimatedSprite2D = p.get("visual")
	var base_x: float = p.get("_visual_base_x")
	var desp: float = p.get("trepar_desplazamiento_x")
	_chk(absf(vis.position.x - base_x) < 0.01, "sin trepar el sprite está en su sitio (x=%.1f)" % vis.position.x)
	Input.action_press("move_up")
	for i in 20:
		await physics_frame
	var f1: int = p.get("facing")
	_chk(bool(p.get("_trepando")), "trepa la liana")
	_chk(absf(vis.position.x - (base_x - f1 * desp)) < 0.5, "mirando %d: sprite corrido %.1f px hacia atrás (x=%.1f)" % [f1, desp, vis.position.x])
	var x_cuerpo := p.global_position.x
	Input.action_press("move_left" if f1 > 0 else "move_right")
	for i in 20:
		await physics_frame
	var f2: int = p.get("facing")
	_chk(f2 == -f1, "girar trepando cambia hacia dónde mira (%d → %d)" % [f1, f2])
	_chk(bool(p.get("_trepando")), "sigue agarrado a la liana tras girar")
	_chk(absf(p.global_position.x - x_cuerpo) < 1.0, "el cuerpo no se despega de la liana al girar")
	_chk(absf(vis.position.x - (base_x - f2 * desp)) < 0.5, "tras girar el sprite pasa al otro lado (x=%.1f)" % vis.position.x)
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	p.call("_salir_enredadera")
	for i in 30:
		await physics_frame
	_chk(absf(vis.position.x - base_x) < 0.5, "al soltarse el sprite vuelve a su sitio (x=%.1f)" % vis.position.x)
	print("DIAG TREPAR FALLOS = ", fallos)
	quit()
