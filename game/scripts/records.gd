class_name Records
## Récords y leaderboard local (guardados en el teléfono).
## Récords: distancia, altura y balas máximas de todos los tiempos.
## Leaderboard: los mejores intentos ordenados por distancia, con sus otros datos.

static var save_path := "user://save.cfg" # los tests usan otro archivo
const MAX_ATTEMPTS := 20

static var best := {"dist": 0, "height": 0, "ammo": 0}
static var attempts: Array = [] # [{dist, height, ammo, kills, headshots, time}], ordenado por dist
static var stats := {} # contadores de toda la vida (ej. chests_killed)
static var _loaded := false


static func load_saved(force := false) -> void:
	if _loaded and not force:
		return
	_loaded = true
	best = {"dist": 0, "height": 0, "ammo": 0}
	attempts = []
	stats = {}
	var cf := ConfigFile.new()
	if cf.load(save_path) != OK:
		return
	best.dist = int(cf.get_value("score", "best", 0)) # clave vieja: solo distancia
	best.height = int(cf.get_value("score", "best_height", 0))
	best.ammo = int(cf.get_value("score", "best_ammo", 0))
	attempts = cf.get_value("score", "attempts", [])
	stats = cf.get_value("progress", "stats", {})


static func stat(key: String) -> int:
	load_saved()
	return int(stats.get(key, 0))


## Pone un contador de toda la vida (mejoras del mercado, etc.) y lo guarda.
static func set_stat(key: String, value: int) -> void:
	load_saved()
	stats[key] = value
	_save()


## Suma 1 a un contador de toda la vida y lo guarda en el teléfono.
static func bump(key: String) -> int:
	load_saved()
	stats[key] = stat(key) + 1
	_save()
	return stats[key]


## Guarda un intento. Devuelve {rank (1-based, 0 si no entró), new: {dist, height, ammo}}.
static func add(attempt: Dictionary) -> Dictionary:
	load_saved()
	var new := {}
	for k in ["dist", "height", "ammo"]:
		new[k] = attempt[k] > best[k]
		best[k] = maxi(best[k], attempt[k])
	attempt.time = int(Time.get_unix_time_from_system())
	var rank := attempts.size() + 1
	for i in attempts.size():
		if attempt.dist > attempts[i].dist:
			rank = i + 1
			break
	attempts.insert(rank - 1, attempt)
	if attempts.size() > MAX_ATTEMPTS:
		attempts.resize(MAX_ATTEMPTS)
	if rank > MAX_ATTEMPTS:
		rank = 0
	_save()
	return {"rank": rank, "new": new}


static func reset() -> void:
	best = {"dist": 0, "height": 0, "ammo": 0}
	attempts = []
	stats = {}
	_loaded = true
	_save()


static func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("score", "best", best.dist)
	cf.set_value("score", "best_height", best.height)
	cf.set_value("score", "best_ammo", best.ammo)
	cf.set_value("score", "attempts", attempts)
	cf.set_value("progress", "stats", stats)
	cf.save(save_path)
