class_name Level
extends RefCounted
## Generador infinito del piso: bloques de altura random con huecos entre algunos.
## El arranque es fijo (piso plano con los 3 personajes); de ahí en adelante, random.
## Cada tanto arranca un nivel especial (persecución, galería de tiro, apagón, jefe):
## el primero a los 250 m; después, uno cada 500 m (sin repetir hasta usar los cuatro).
##
## Cada bloque trae sus ítems de piso: [{type, x, y}]. Los bichos voladores no salen
## de acá: main.gd los hace aparecer alrededor de la altura del arma.

const START := Vector2(0.0, 2.4)
const ENEMY_XS := [4.0, 6.5, 9.0] # los 3 fijos del arranque
const START_X := -8.0
const START_LEN := 22.0
const BLOCK_DEPTH := 40.0 # cuánto baja cada bloque por debajo de su techo
const DEPTH := 3.2

# Piso normal: sin límite de altura (paseo al azar), solo el tamaño de cada escalón.
const MAX_STEP_UP := 3.0 # pared máxima a trepar (un tiro desde el piso sube ~2.8 m)
const MAX_STEP_DOWN := 5.0 # caída máxima entre bloques vecinos
const MIN_STEP := 0.4 # para que los escalones se noten
const UP_CHANCE := 0.6 # compensa que las bajadas son más grandes que las subidas
const BLOCK_LEN := Vector2(4.0, 11.0)
const GAP_CHANCE := 0.3
const GAP_LEN := Vector2(3.0, 14.0) # largo random del hueco al principio...
const GAP_RAMP_MAX := 6.0 # ...y cuánto crece como máximo con la distancia
const GAP_RAMP_DIST := 300.0 # metros hasta llegar al hueco más largo

# Ítems en el piso (personajes, cofres, resortes) y en el aire (bichos)
const ITEM_SPACING := Vector2(7.0, 14.0)
const ITEM_EDGE := 0.8 # distancia mínima al borde del bloque
const GROUND_WEIGHTS := {"plain": 3.0, "sword": 2.0, "shield": 2.0, "helmet": 2.0, "chest": 1.6, "spring": 1.2}

# Niveles especiales
const SPECIALS := ["chase", "gallery", "blackout", "boss"]
const SPECIAL_FIRST := 250.0
const SPECIAL_EVERY := 500.0 # desde el final de uno hasta el principio del siguiente
const SPECIAL_LEN := {"chase": 110.0, "gallery": 110.0, "blackout": 120.0, "boss": 50.0}
const SPECIAL_STEP := {"chase": 1.6, "gallery": 0.4, "blackout": 2.0} # escalones máximos
const GALLERY_SPACING := Vector2(6.5, 9.5)
const BLACKOUT_SPACING := Vector2(5.0, 8.5)
const CHASE_SPACING := Vector2(10.0, 16.0)
const CHASE_AMMO_GAP := 0.9 # m entre las balas de un grupito
const BOSS_ARENA := 34.0 # cada jefe va a BOSS_AT[jefe] del principio de la arena
const BOSSES := ["robot", "mole", "zeppelin", "wall", "duel"]
const BOSS_AT := {"robot": 24.0, "mole": 19.0, "zeppelin": 20.0, "wall": 31.0, "duel": 20.0}
const WALL_PIT := 4.5 # muralla: pozo antes de la arena (adonde te quiere tirar)

## Solo para probar: el próximo nivel arranca con este especial apenas termina el arranque.
static var debug_special := ""

var rng := RandomNumberGenerator.new()
var special := "" # nivel especial en curso ("" = piso normal)
var _x := START_X
var _top := 0.0
var _count := 0
var _next_item_x := 0.0
var _next_ammo_x := 0.0 # persecución: dónde va el próximo grupito de balas
var _next_special_x: float = SPECIAL_FIRST
var _special_end := 0.0
var _special_bag: Array = []
var _boss_done := false
var boss_kind := "" # el jefe de este nivel especial
var _boss_bag: Array = []
var _force_boss := "" # solo para probar: este jefe
var _force_lift := "" # solo para probar: "fan", "booster" o "market" apenas termina el arranque
var _force_item := "" # solo para probar: "chest" o "trap" como primer ítem después del arranque
var _last_market_x := -INF


func _init(seed_value: int = -1, force_special := "") -> void:
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	if force_special in ["fan", "booster", "market"]:
		_force_lift = force_special
	elif force_special in ["chest", "trap"]:
		_force_item = force_special
	elif force_special.begins_with("boss:"):
		_next_special_x = START_X + START_LEN
		_special_bag = ["boss"]
		_force_boss = force_special.trim_prefix("boss:")
	elif force_special != "":
		_next_special_x = START_X + START_LEN
		_special_bag = [force_special]


## Próximo bloque sólido: {x0, x1, top, items: [{type, x, y}], special}.
func next_block() -> Dictionary:
	if _count == 0:
		_count = 1
		_x = START_X + START_LEN
		_next_item_x = _x + rng.randf_range(3.0, 6.0)
		var items := []
		for ex in ENEMY_XS:
			items.append({"type": "plain", "x": ex, "y": 0.0})
		return {"x0": START_X, "x1": _x, "top": 0.0, "items": items, "special": ""}

	if special == "" and _x >= _next_special_x:
		_start_special()
	if special == "boss":
		return _boss_block()
	if special != "":
		return _special_block()
	return _normal_block()


func _start_special() -> void:
	if _special_bag.is_empty():
		_special_bag = SPECIALS.duplicate()
		for i in range(_special_bag.size() - 1, 0, -1): # shuffle con nuestro rng (reproducible)
			var j := rng.randi_range(0, i)
			var tmp = _special_bag[i]
			_special_bag[i] = _special_bag[j]
			_special_bag[j] = tmp
	special = _special_bag.pop_back()
	_special_end = _x + SPECIAL_LEN[special]
	_next_special_x = _special_end + SPECIAL_EVERY
	_boss_done = false
	if special == "boss":
		boss_kind = _pick_boss()
	_next_item_x = _x + 4.0
	_next_ammo_x = _x + 3.0


func _end_special() -> void:
	special = ""


func _normal_block() -> Dictionary:
	# El nivel especial arranca justo en su marca: cerca de ella, sin hueco y el
	# último bloque termina ahí.
	var ramp := clampf(_x / GAP_RAMP_DIST, 0.0, 1.0) * GAP_RAMP_MAX
	var to_special := _next_special_x - _x
	var gap_ok := to_special > BLOCK_LEN.y + GAP_LEN.y + ramp
	if _count >= 2 and rng.randf() < GAP_CHANCE and gap_ok:
		_x += rng.randf_range(GAP_LEN.x, GAP_LEN.y + ramp)

	if rng.randf() < UP_CHANCE:
		_top += rng.randf_range(MIN_STEP, MAX_STEP_UP)
	else:
		_top -= rng.randf_range(MIN_STEP, MAX_STEP_DOWN)
	var length := rng.randf_range(BLOCK_LEN.x, BLOCK_LEN.y)
	if not gap_ok and length > to_special - BLOCK_LEN.x:
		length = maxf(to_special, 2.0) # el último antes del especial (o uno corto de relleno)
	return _finish_block(length, "")


## Tramo de un nivel especial (persecución, galería, apagón): sin huecos (en el
## apagón, alguno chico), escalones según el nivel y sus propios ítems.
func _special_block() -> Dictionary:
	var kind := special
	if kind == "blackout" and rng.randf() < 0.2:
		_x += rng.randf_range(2.0, 4.5)
	var step: float = SPECIAL_STEP[kind]
	_top += rng.randf_range(-step, step)
	var length := rng.randf_range(6.0, 12.0)
	if _x + length > _special_end:
		length = maxf(_special_end - _x, 3.0)
	var b := _finish_block(length, kind)
	if _x >= _special_end - 0.01:
		_end_special()
	return b


## Qué jefe toca: no se repite hasta que salen todos.
func _pick_boss() -> String:
	if _force_boss != "":
		var k := _force_boss
		_force_boss = ""
		return k
	if _boss_bag.is_empty():
		_boss_bag = BOSSES.duplicate()
		for i in range(_boss_bag.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = _boss_bag[i]
			_boss_bag[i] = _boss_bag[j]
			_boss_bag[j] = tmp
	return _boss_bag.pop_back()


## Jefe: una arena plana con el jefe; después, la salida a la misma altura.
## (La muralla tiene un pozo antes de la arena: te quiere empujar ahí.)
func _boss_block() -> Dictionary:
	if not _boss_done:
		_boss_done = true
		if boss_kind == "wall":
			_x += WALL_PIT
		var b := _finish_block(BOSS_ARENA, "boss")
		b.items = [{"type": "boss", "boss": boss_kind, "x": b.x0 + BOSS_AT[boss_kind], "y": b.top, "x0": b.x0}]
		b["boss"] = boss_kind
		return b
	var b2 := _finish_block(_special_end - _x if _special_end - _x > 6.0 else 12.0, "boss")
	b2.items = []
	_end_special()
	_next_item_x = _x + 3.0
	return b2


## Ítems de un tramo especial (en vez de los del piso normal).
func _special_items(b: Dictionary) -> void:
	var kind: String = b.special
	if kind == "boss":
		return
	var spacing: Vector2 = {"gallery": GALLERY_SPACING, "blackout": BLACKOUT_SPACING, "chase": CHASE_SPACING}[kind]
	if _next_item_x < b.x0 + ITEM_EDGE:
		_next_item_x = b.x0 + ITEM_EDGE + rng.randf_range(0.0, 1.5)
	while _next_item_x <= b.x1 - ITEM_EDGE:
		var x := _next_item_x
		match kind:
			"gallery":
				var mode: String = ["ground", "ground", "hang", "fly"][rng.randi_range(0, 3)]
				var y: float = b.top + {"ground": 1.4, "hang": rng.randf_range(3.2, 5.0), "fly": rng.randf_range(2.5, 4.5)}[mode]
				b.items.append({"type": "target", "x": x, "y": y, "mode": mode})
			"blackout": # enemigos (solo se les ven los ojos) y lucecitas que dan balas
				b.items.append({"type": ["plain", "sword", "shield", "plain", "sword"][rng.randi_range(0, 4)], "x": x, "y": b.top})
				for i in rng.randi_range(1, 2):
					var fx := x + rng.randf_range(1.5, spacing.x - 1.0)
					if fx < b.x1:
						b.items.append({"type": "firefly", "x": fx, "y": b.top + rng.randf_range(1.6, 5.0)})
			"chase": # pocos: obstáculos y balas
				b.items.append({"type": ["plain", "plain", "sword"][rng.randi_range(0, 2)], "x": x, "y": b.top})
		_next_item_x += rng.randf_range(spacing.x, spacing.y)
	if kind == "chase": # balas durante la persecución: grupitos flotando en el camino
		var width := (Config.CHASE_AMMO_GROUP - 1) * CHASE_AMMO_GAP
		while _next_ammo_x + width <= b.x1 - ITEM_EDGE:
			var y: float = b.top + rng.randf_range(Config.CHASE_AMMO_HEIGHT.x, Config.CHASE_AMMO_HEIGHT.y)
			for i in Config.CHASE_AMMO_GROUP: # en un arquito
				var k := i / maxf(Config.CHASE_AMMO_GROUP - 1.0, 1.0)
				b.items.append({"type": "ammo", "x": _next_ammo_x + i * CHASE_AMMO_GAP, "y": y + sin(k * PI) * 0.35})
			_next_ammo_x += rng.randf_range(Config.CHASE_AMMO_EVERY.x, Config.CHASE_AMMO_EVERY.y)


func _finish_block(length: float, kind: String) -> Dictionary:
	var b := {"x0": _x, "x1": _x + length, "top": _top, "items": [], "special": kind}
	_x = b.x1
	_count += 1
	if kind != "":
		_special_items(b)
		return b

	# Ítems de piso: uno cada ITEM_SPACING metros; si el lugar cae en un hueco o
	# muy al borde, se corre al principio del bloque siguiente.
	# Ventilador (pasados FAN_FROM m) y cohete propulsor (pasados BOOSTER_FROM m):
	# a veces, en el medio del bloque, solos.
	var lift := ""
	if kind == "" and b.x1 - b.x0 > Config.FAN_WIDTH + 1.0:
		if _force_lift != "" and _count >= 3:
			lift = _force_lift
			_force_lift = ""
		elif b.x0 > Config.BOOSTER_FROM and rng.randf() < Config.BOOSTER_CHANCE:
			lift = "booster"
		elif b.x0 > Config.FAN_FROM and rng.randf() < Config.FAN_CHANCE:
			lift = "fan"
		# Mercado: la bañadera con billetes, a veces, pasados los 300 m.
		if lift == "" and b.x1 - b.x0 >= Config.TUB_SIZE.x + 2.0 and b.x0 > Config.MARKET_FROM \
				and b.x0 - _last_market_x > Config.MARKET_MIN_GAP and rng.randf() < Config.MARKET_CHANCE:
			lift = "market"
	if lift == "market" and b.x1 - b.x0 < Config.TUB_SIZE.x + 1.0:
		lift = "" # (solo el de prueba) no entra: espera un bloque más largo
		_force_lift = "market"
	if lift == "market":
		_last_market_x = b.x0
	if lift != "":
		b.items.append({"type": lift, "x": (b.x0 + b.x1) / 2.0, "y": b.top})
		_next_item_x = maxf(_next_item_x, b.x1) # nada más arriba de este bloque

	if _next_item_x < b.x0 + ITEM_EDGE:
		_next_item_x = b.x0 + ITEM_EDGE + rng.randf_range(0.0, 1.5)
	while _next_item_x <= b.x1 - ITEM_EDGE:
		var t := _pick_ground_type()
		if _force_item != "":
			t = _force_item
		var half := Chest.world_size().x / 2.0 + 0.3
		if t in ["chest", "trap"]:
			if b.x1 - b.x0 < half * 2.0: # no entra: va un personaje
				t = "plain"
			else: # centrado dentro del bloque
				_next_item_x = clampf(_next_item_x, b.x0 + half, b.x1 - half)
				if t == _force_item:
					_force_item = ""
		b.items.append({"type": t, "x": _next_item_x, "y": b.top})
		_next_item_x += rng.randf_range(ITEM_SPACING.x, ITEM_SPACING.y) + (half if t in ["chest", "trap"] else 0.0)
	return b


func _pick_ground_type() -> String:
	var total := 0.0
	for w in GROUND_WEIGHTS.values():
		total += w
	var r := rng.randf() * total
	for t in GROUND_WEIGHTS:
		r -= GROUND_WEIGHTS[t]
		if r <= 0.0:
			if t == "chest" and rng.randf() < Config.TRAP_CHANCE:
				return "trap"
			return t
	return "plain"


## Bloque que contiene x, o {} si x cae en un hueco.
static func block_at(blocks_list: Array, x: float) -> Dictionary:
	for b in blocks_list:
		if x >= b.x0 and x < b.x1:
			return b
	return {}


## Altura más baja de los dos bloques que rodean x (en un hueco: sus dos bordes).
static func low_top_around(blocks_list: Array, x: float) -> float:
	var prev := INF
	for b in blocks_list:
		if b.x0 > x:
			return minf(prev, b.top)
		prev = b.top
	return prev if prev != INF else 0.0


## Altura del piso en x; en un hueco, la del último bloque antes de x.
static func top_at(blocks_list: Array, x: float) -> float:
	var top := 0.0
	for b in blocks_list:
		if b.x0 > x:
			break
		top = b.top
	return top
