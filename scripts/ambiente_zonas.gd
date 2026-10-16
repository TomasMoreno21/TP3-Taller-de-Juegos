extends Node

## Sonido por tramo: las capas de ambiente (ambiente_sonoro.gd) pasan por un bus propio con reverb y paso bajo,
## y según la zona (hijos zona_sonido.gd) cambian el eco, lo "sordo" del sonido y el volumen, y suena una capa propia
## (viento hueco en el abismo, zumbido en el santuario). Fuera de toda zona rige el ambiente por defecto.
## Todo se mezcla suave al cruzar el límite. Cada valor se edita en la zona o aquí.

@export var bus_nombre := &"AmbienteCueva"
@export var velocidad_cambio := 1.2                        ## qué tan rápido se mezcla con la zona nueva (1/s)
@export_group("Ambiente por defecto")
@export_range(0.0, 1.0, 0.01) var reverb_mezcla := 0.12
@export_range(0.0, 1.0, 0.01) var reverb_sala := 0.35
@export_range(200.0, 20500.0, 10.0) var filtro_hz := 20500.0
@export var volumen_db := 0.0

var _bus := -1
var _reverb: AudioEffectReverb
var _filtro: AudioEffectLowPassFilter
var _zonas: Array = []
var _caps := {}                    # zona -> AudioStreamPlayer
var _mezcla := 0.12
var _sala := 0.35
var _hz := 20500.0
var _vol := 0.0
var _jugador: Node2D


func _enter_tree() -> void:
	_bus = AudioServer.get_bus_index(bus_nombre)
	if _bus < 0:
		AudioServer.add_bus()
		_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_bus, bus_nombre)
		AudioServer.set_bus_send(_bus, &"Musica" if AudioServer.get_bus_index(&"Musica") >= 0 else &"Master")
		_reverb = AudioEffectReverb.new()
		_filtro = AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(_bus, _filtro)
		AudioServer.add_bus_effect(_bus, _reverb)
	else:
		_filtro = AudioServer.get_bus_effect(_bus, 0) as AudioEffectLowPassFilter
		_reverb = AudioServer.get_bus_effect(_bus, 1) as AudioEffectReverb
	_mezcla = reverb_mezcla
	_sala = reverb_sala
	_hz = filtro_hz
	_vol = volumen_db
	_aplicar()


func _ready() -> void:
	for z in get_children():
		if not z.has_method("contiene"):
			continue
		_zonas.append(z)
		var stream: AudioStream = z.get("capa")
		if stream == null:
			continue
		if stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.bus = bus_nombre
		p.volume_db = -80.0
		p.stream_paused = true
		add_child(p)
		p.play()
		_caps[z] = p


func _process(delta: float) -> void:
	if not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("player") as Node2D
		if _jugador == null:
			return
	var activa: Node = null
	for z in _zonas:
		if z.contiene(_jugador.global_position):
			activa = z
			break
	var k := 1.0 - exp(-velocidad_cambio * delta)
	_mezcla = lerpf(_mezcla, activa.get("reverb_mezcla") if activa != null else reverb_mezcla, k)
	_sala = lerpf(_sala, activa.get("reverb_sala") if activa != null else reverb_sala, k)
	_hz = exp(lerpf(log(_hz), log(activa.get("filtro_hz") if activa != null else filtro_hz), k))
	_vol = lerpf(_vol, activa.get("volumen_db") if activa != null else volumen_db, k)
	_aplicar()
	for z in _caps.keys():
		var p: AudioStreamPlayer = _caps[z]
		var meta := float(z.get("capa_db")) if z == activa else -80.0
		p.volume_db = lerpf(maxf(p.volume_db, -80.0), meta, 1.0 - exp(-0.9 * delta))
		p.stream_paused = z != activa and p.volume_db < -60.0


func _aplicar() -> void:
	if _bus < 0:
		return
	_reverb.room_size = _sala
	_reverb.wet = _mezcla
	_reverb.dry = 1.0 - _mezcla * 0.35
	_reverb.damping = 0.55
	_filtro.cutoff_hz = _hz
	AudioServer.set_bus_volume_db(_bus, _vol)
