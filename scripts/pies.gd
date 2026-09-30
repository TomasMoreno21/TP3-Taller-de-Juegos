class_name Pies
extends RefCounted
## Mide los píxeles vacíos bajo los pies de un frame (una vez por textura) para apoyarlo en el piso.

static var _cache: Dictionary = {}


static func relleno_inferior(tex: Texture2D) -> float:
	if tex == null:
		return 0.0
	if _cache.has(tex):
		return _cache[tex]
	var pad := 0.0
	var img := tex.get_image()
	if img != null and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		var w := img.get_width()
		var y := img.get_height() - 1
		while y > 0:
			var hay := false
			for x in range(0, w, 2):
				if img.get_pixel(x, y).a > 0.1:
					hay = true
					break
			if hay:
				break
			y -= 1
		pad = float(img.get_height() - 1 - y)
	_cache[tex] = pad
	return pad
