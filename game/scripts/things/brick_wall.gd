class_name BrickWall
extends AnimatableBody3D
## Jefe muralla: una pared que avanza hacia vos y te quiere tirar al pozo que
## hay al principio de la arena. Abajo es de ladrillos (cada tiro rompe uno);
## arriba es de acero hasta el cielo (no se pasa por arriba). Abrile un agujero
## y pasá del otro lado: ganaste. Ojo: cada tiro para adelante te empuja para atrás.
## Origen: abajo, en el piso, en el medio del espesor de la pared.

const BRICK := Vector2(0.9, 0.8) # espesor (x) y alto de cada ladrillo
const ROWS := 7 # ladrillos hasta ROWS * BRICK.y; arriba, acero
const STEEL_H := 80.0

var game: Node
var alive := true
var total := 1
var cam_height := 3.0
var cam_right := 1.5
var stop_x := -INF # hasta dónde avanza (el borde del pozo)
var bricks := {} # CollisionShape3D -> MeshInstance3D (los que quedan)
var broken := 0
var _t := 0.0
var _x := 0.0


func _ready() -> void:
	collision_layer = Config.L_TERRAIN | Config.L_ENEMY
	collision_mask = 0
	sync_to_physics = true
	_x = position.x
	var brick_mat := StandardMaterial3D.new()
	brick_mat.albedo_color = Color("b4553a")
	brick_mat.roughness = 0.85
	var brick_mat2 := StandardMaterial3D.new()
	brick_mat2.albedo_color = Color("9c4630")
	brick_mat2.roughness = 0.85
	for r in ROWS:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(BRICK.x, BRICK.y, 3.0)
		cs.shape = bs
		cs.position = Vector3(0, BRICK.y * (r + 0.5), 0)
		add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(BRICK.x, BRICK.y - 0.06, 1.6)
		bm.material = brick_mat if r % 2 == 0 else brick_mat2
		mi.mesh = bm
		mi.position = cs.position
		add_child(mi)
		bricks[cs] = mi
	var steel_cs := CollisionShape3D.new()
	var ss := BoxShape3D.new()
	var base := ROWS * BRICK.y
	ss.size = Vector3(BRICK.x, STEEL_H, 3.0)
	steel_cs.shape = ss
	steel_cs.position.y = base + STEEL_H / 2.0
	add_child(steel_cs)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("5c6470")
	steel.metallic = 0.8
	steel.roughness = 0.3
	var sm := MeshInstance3D.new()
	var sbm := BoxMesh.new()
	sbm.size = Vector3(BRICK.x + 0.1, STEEL_H, 1.7)
	sbm.material = steel
	sm.mesh = sbm
	sm.position.y = base + STEEL_H / 2.0
	add_child(sm)
	var stripe := StandardMaterial3D.new() # franja de peligro en el borde del acero
	stripe.albedo_color = Color("ffb21a")
	var st := MeshInstance3D.new()
	var stm := BoxMesh.new()
	stm.size = Vector3(BRICK.x + 0.14, 0.25, 1.75)
	stm.material = stripe
	st.mesh = stm
	st.position.y = base + 0.12
	add_child(st)


func brick_position(row: int) -> Vector3:
	return to_global(Vector3(0, BRICK.y * (row + 0.5), 0))


func has_brick(row: int) -> bool:
	for cs in bricks:
		if absf((cs as Node3D).position.y - BRICK.y * (row + 0.5)) < 0.01:
			return true
	return false


func shot(hit: Dictionary, _dir: Vector2) -> Dictionary:
	if not alive:
		return {"result": "none", "reward": 0}
	var part: Object = shape_owner_get_owner(shape_find_owner(hit.get("shape", 0)))
	if not bricks.has(part):
		return {"result": "blocked", "reward": 0}
	var mi: MeshInstance3D = bricks[part]
	bricks.erase(part)
	(part as CollisionShape3D).set_deferred("disabled", true)
	broken += 1
	if game:
		game._fx_puff(mi.global_position, Color("b4553a"), 14, 0.6, false)
		game.sfx.play("clank", -2.0, 0.7)
	var tw := create_tween() # el ladrillo sale volando
	tw.tween_property(mi, "position", mi.position + Vector3(1.2, -0.4, 0.8), 0.35)
	tw.parallel().tween_property(mi, "scale", Vector3.ONE * 0.2, 0.35)
	tw.tween_callback(mi.queue_free)
	return {"result": "brick", "reward": 0}


func _physics_process(delta: float) -> void:
	_t += delta
	if not alive or game == null:
		return
	if game.state != game.State.PLAYING:
		return
	var gx: float = game.gun.global_position.x
	if gx > global_position.x + BRICK.x: # pasaste del otro lado: ganaste
		_win()
		return
	if global_position.x - gx > Config.BOSS_WAKE:
		return
	if global_position.x > stop_x:
		global_position.x = maxf(global_position.x - Config.WALL_SPEED * delta, stop_x)


## Info para el contador: a cuántos metros del pozo estás.
func info_text() -> String:
	var gx: float = game.gun.global_position.x
	return "¡PASALA! EL POZO A %d m" % maxi(0, floori(gx - stop_x + 1.0))


func _win() -> void:
	alive = false
	set_deferred("collision_layer", 0)
	game.boss_defeated(global_position + Vector3(0, 2.0, 0), Config.BOSS_REWARD)
	# se derrumba
	var tw := create_tween()
	for c in get_children():
		if c is MeshInstance3D:
			tw.parallel().tween_property(c, "position:y", (c as Node3D).position.y - 8.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
