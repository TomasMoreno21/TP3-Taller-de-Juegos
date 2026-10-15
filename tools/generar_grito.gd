extends SceneTree
## Sintetiza un "¡pa-pá!" de niño PROVISORIO (formantes de /a/) en assets/audio/sfx/gen/grito_papa.wav.
## Reemplazar el .wav por una voz real cuando exista (el nodo EcoHijo lo exporta como `sonido_grito`).
## Uso: godot --headless --path . --script res://tools/generar_grito.gd

const SR := 22050
const SALIDA := "res://assets/audio/sfx/gen/grito_papa.wav"


func _init() -> void:
	var dur := 1.3
	var n := int(dur * SR)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var datos := PackedFloat32Array()
	datos.resize(n)
	var formantes := [[1000.0, 140.0, 1.0], [1750.0, 180.0, 0.7], [3100.0, 250.0, 0.4]]
	var y1 := [0.0, 0.0, 0.0]
	var y2 := [0.0, 0.0, 0.0]
	var fase := 0.0
	for i in n:
		var t := float(i) / SR
		var silaba := 0
		var u := 0.0
		if t < 0.36:
			silaba = 1
			u = t / 0.36
		elif t > 0.46 and t < 1.2:
			silaba = 2
			u = (t - 0.46) / 0.74
		var env := 0.0
		var f0 := 400.0
		if silaba == 1:
			env = minf(u * 12.0, 1.0) * (1.0 - u * 0.5)
			f0 = lerpf(420.0, 470.0, u)
		elif silaba == 2:
			env = minf(u * 10.0, 1.0) * (1.0 - pow(u, 3.0))
			f0 = lerpf(470.0, 600.0, u) + sin(t * TAU * 6.5) * 10.0 * u
		fase = fmod(fase + f0 / SR, 1.0)
		var fuente := (fase * 2.0 - 1.0) * 0.8 + rng.randf_range(-1.0, 1.0) * 0.25
		if silaba == 1 and t < 0.02:
			fuente += rng.randf_range(-1.0, 1.0) * 2.0   # soplo de la "p"
		if silaba == 2 and u < 0.04:
			fuente += rng.randf_range(-1.0, 1.0) * 2.0
		var salida := 0.0
		for k in 3:
			var f: float = formantes[k][0]
			var bw: float = formantes[k][1]
			var r := exp(-PI * bw / SR)
			var a1 := -2.0 * r * cos(TAU * f / SR)
			var y: float = (1.0 - r) * fuente - a1 * y1[k] - r * r * y2[k]
			y2[k] = y1[k]
			y1[k] = y
			salida += y * float(formantes[k][2])
		datos[i] = salida * env
	var pico := 0.001
	for v in datos:
		pico = maxf(pico, absf(v))
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(datos[i] / pico * 0.9, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SR
	wav.stereo = false
	wav.data = bytes
	var err := wav.save_to_wav(SALIDA)
	print("grito_papa.wav: ", "OK" if err == OK else "ERROR %d" % err)
	quit()
