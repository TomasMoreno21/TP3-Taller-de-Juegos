extends Control

@export_group("Ciclo")
@export var mantener := 3.5
@export var duracion_lobo := 0.0
@export var duracion_oso := 0.0
@export var duracion_murci := 0.0
@export var fundido := 2.0
@export var pausa := 1.0

var _espiritus: Array[TextureRect] = []
var _indice := 0
var _tw: Tween


func _ready() -> void:
	for hijo in get_children():
		if hijo is TextureRect:
			_espiritus.append(hijo)
	for e in _espiritus:
		e.modulate.a = 0.0
	if _espiritus.is_empty():
		return
	_entrar(0)


func _entrar(i: int) -> void:
	_indice = i
	_tw = create_tween()
	_tw.tween_property(_espiritus[i], "modulate:a", 1.0, fundido)
	_tw.tween_interval(_duracion(_espiritus[i].name))
	_tw.tween_callback(_salir)


func _salir() -> void:
	var actual := _espiritus[_indice]
	_tw = create_tween()
	_tw.tween_property(actual, "modulate:a", 0.0, fundido)
	_tw.tween_interval(pausa)
	_tw.tween_callback(_entrar.bind((_indice + 1) % _espiritus.size()))


func _duracion(nombre: StringName) -> float:
	var segun := 0.0
	match nombre:
		&"Lobo":
			segun = duracion_lobo
		&"Oso":
			segun = duracion_oso
		&"Murcielago":
			segun = duracion_murci
	return segun if segun > 0.0 else mantener
