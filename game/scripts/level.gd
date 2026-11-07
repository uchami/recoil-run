class_name Level
extends RefCounted
## Generador infinito del piso: bloques de altura random con huecos entre algunos.
## El arranque es fijo (piso plano con los 3 personajes); de ahí en adelante, random.
## Cada tanto arranca un nivel especial (escalera abajo, escalera arriba, aéreo).
##
## Cada bloque trae sus ítems: [{type, x, y}] con type en ITEM_TYPES.

const START := Vector2(0.0, 2.4)
const ENEMY_XS := [4.0, 6.5, 9.0] # los 3 fijos del arranque
const START_X := -8.0
const START_LEN := 22.0
const BLOCK_DEPTH := 40.0 # cuánto baja cada bloque por debajo de su techo
const DEPTH := 3.2

# Piso normal: alturas relativas a _base (que se mueve después de una escalera)
const MIN_TOP := -6.0
const MAX_TOP := 10.0
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
const FLYER_FIRST := 45.0
const FLYER_SPACING := Vector2(22.0, 40.0)
const FLYER_HEIGHT := Vector2(3.0, 8.0) # sobre el piso
const HAWK_CHANCE := 0.4

# Niveles especiales
const SPECIALS := ["stairs_down", "stairs_up", "air"]
const SPECIAL_FIRST := 300.0 # (para probar; la idea final es cada 3000 m con backoff)
const SPECIAL_EVERY := 500.0
const STAIRS_LEN := 300.0
const STAIRS_STEP_LEN := Vector2(3.0, 6.0)
const STAIRS_DOWN_DROP := Vector2(0.8, 2.2)
const STAIRS_UP_RISE := Vector2(0.6, 1.6)
const STAIRS_GAP_CHANCE := 0.25
const STAIRS_GAP_LEN := Vector2(2.0, 6.0)
const AIR_LEN := 200.0
const AIR_AMMO_SPACING := Vector2(6.0, 10.0)
const AIR_HEIGHT := Vector2(1.5, 7.0)
const AIR_BAT_SPACING := Vector2(16.0, 26.0)

## Solo para probar: el próximo nivel arranca con este especial apenas termina el arranque.
static var debug_special := ""

var rng := RandomNumberGenerator.new()
var special := "" # nivel especial en curso ("" = piso normal)
var _x := START_X
var _top := 0.0
var _base := 0.0
var _count := 0
var _next_item_x := 0.0
var _next_flyer_x := FLYER_FIRST
var _next_special_x := SPECIAL_FIRST
var _special_end := 0.0
var _special_bag: Array = []


func _init(seed_value: int = -1, force_special := "") -> void:
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	if force_special != "":
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
	match special:
		"air":
			return _air_block()
		"stairs_down", "stairs_up":
			return _stairs_block()
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
	_special_end = _x + (AIR_LEN if special == "air" else STAIRS_LEN)
	_next_special_x = _special_end + SPECIAL_EVERY


func _end_special() -> void:
	special = ""
	_base = _top # el piso normal sigue variando alrededor de donde terminó la escalera


func _normal_block() -> Dictionary:
	if _count >= 2 and rng.randf() < GAP_CHANCE:
		var ramp := clampf(_x / GAP_RAMP_DIST, 0.0, 1.0) * GAP_RAMP_MAX
		_x += rng.randf_range(GAP_LEN.x, GAP_LEN.y + ramp)

	var lo := _base + MIN_TOP
	var hi := _base + MAX_TOP
	var up := rng.randf() < UP_CHANCE
	if _top + MIN_STEP > hi:
		up = false
	elif _top - MIN_STEP < lo:
		up = true
	if up:
		_top = minf(_top + rng.randf_range(MIN_STEP, MAX_STEP_UP), maxf(hi, _top + MIN_STEP))
	else:
		_top = maxf(_top - rng.randf_range(MIN_STEP, MAX_STEP_DOWN), minf(lo, _top - MIN_STEP))
	return _finish_block(rng.randf_range(BLOCK_LEN.x, BLOCK_LEN.y), "")


func _stairs_block() -> Dictionary:
	if rng.randf() < STAIRS_GAP_CHANCE:
		_x += rng.randf_range(STAIRS_GAP_LEN.x, STAIRS_GAP_LEN.y)
	if special == "stairs_down":
		_top -= rng.randf_range(STAIRS_DOWN_DROP.x, STAIRS_DOWN_DROP.y)
	else:
		_top += rng.randf_range(STAIRS_UP_RISE.x, STAIRS_UP_RISE.y)
	var kind := special
	var b := _finish_block(rng.randf_range(STAIRS_STEP_LEN.x, STAIRS_STEP_LEN.y), kind)
	if _x >= _special_end:
		_end_special()
	return b


## Nivel aéreo: un hueco enorme sin piso, con balas flotando y murciélagos. Se
## devuelve el bloque de salida (a la misma altura que la entrada) con todo lo del aire.
func _air_block() -> Dictionary:
	var x0 := _x
	var x1 := _special_end
	var items := []
	var x := x0 + rng.randf_range(4.0, 7.0)
	while x < x1 - 4.0:
		items.append({"type": "ammo", "x": x, "y": _top + rng.randf_range(AIR_HEIGHT.x, AIR_HEIGHT.y)})
		x += rng.randf_range(AIR_AMMO_SPACING.x, AIR_AMMO_SPACING.y)
	x = x0 + rng.randf_range(12.0, 20.0)
	while x < x1 - 8.0:
		items.append({"type": "bat", "x": x, "y": _top + rng.randf_range(AIR_HEIGHT.x + 1.0, AIR_HEIGHT.y + 1.0)})
		x += rng.randf_range(AIR_BAT_SPACING.x, AIR_BAT_SPACING.y)
	_x = x1
	_end_special()
	_next_item_x = _x + 3.0
	_next_flyer_x = maxf(_next_flyer_x, _x + 20.0)
	var b := _finish_block(10.0, "air")
	b.items = items + b.items
	return b


func _finish_block(length: float, kind: String) -> Dictionary:
	var b := {"x0": _x, "x1": _x + length, "top": _top, "items": [], "special": kind}
	_x = b.x1
	_count += 1

	# Ítems de piso: uno cada ITEM_SPACING metros; si el lugar cae en un hueco o
	# muy al borde, se corre al principio del bloque siguiente.
	if _next_item_x < b.x0 + ITEM_EDGE:
		_next_item_x = b.x0 + ITEM_EDGE + rng.randf_range(0.0, 1.5)
	while _next_item_x <= b.x1 - ITEM_EDGE:
		b.items.append({"type": _pick_ground_type(), "x": _next_item_x, "y": b.top})
		_next_item_x += rng.randf_range(ITEM_SPACING.x, ITEM_SPACING.y)

	# Bichos voladores
	while _next_flyer_x <= b.x1:
		var t := "hawk" if rng.randf() < HAWK_CHANCE else "bat"
		b.items.append({"type": t, "x": _next_flyer_x, "y": b.top + rng.randf_range(FLYER_HEIGHT.x, FLYER_HEIGHT.y)})
		_next_flyer_x += rng.randf_range(FLYER_SPACING.x, FLYER_SPACING.y)
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
