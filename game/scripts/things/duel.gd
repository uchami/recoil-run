class_name Duel
extends Node3D
## Jefe arma rival (duelo): otra arma, roja y más grande, que se mueve igual
## que vos: con el retroceso de sus tiros. Te apunta (línea finita de aviso) y
## te dispara; cada tiro la empuja para atrás. Si le pegás 3 veces, gana vos.
## Detrás, un campo de fuerza.
## Origen: el piso, en el medio de la arena (el arma rival se mueve por la arena).

const FIELD_X := 12.0
const RANGE := Vector2(-12.0, 6.0) # por dónde se puede mover (x local)
const SCALE := 2.0
const RECOIL := 7.5
const GRAVITY := 14.0

var game: Node
var alive := true
var total := 3
var hits := 0
var cam_height := 3.0
var cam_right := 2.0
var rival: Area3D
var vel := Vector3.ZERO
var _field: ForceField
var _cd := 1.4
var _aim_left := -1.0
var _aim_to := Vector3.ZERO
var _hop_cd := 0.9
var _blink := 0.0
var _beam: MeshInstance3D
var _vis: Node3D
var _t := 0.0


func _ready() -> void:
	_field = ForceField.new()
	_field.position = Vector3(FIELD_X, 0, 0)
	add_child(_field)
	rival = Area3D.new()
	rival.collision_layer = Config.L_FLYER
	rival.collision_mask = 0
	rival.monitoring = false
	rival.set_meta("boss", self)
	rival.position = Vector3(4.0, 3.0, 0)
	add_child(rival)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(Gun.SLIDE_SIZE.x, 0.55, 0.5) * SCALE
	cs.shape = bs
	cs.position.y = -0.05 * SCALE
	rival.add_child(cs)
	_vis = Node3D.new()
	_vis.scale = Vector3(-SCALE, SCALE, SCALE) # mirando a la izquierda (hacia vos)
	rival.add_child(_vis)
	_build_mesh()
	_beam = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.25, 0.3, 0.5)
	bm.material = mat
	_beam.mesh = bm
	_beam.top_level = true
	_beam.visible = false
	add_child(_beam)


func rival_position() -> Vector3:
	return rival.global_position


func shot(_hit: Dictionary, _dir: Vector2) -> Dictionary:
	if not alive:
		return {"result": "none", "reward": 0}
	if _blink > 0.0: # recién golpeada: un ratito invulnerable
		return {"result": "blocked", "reward": 0}
	hits += 1
	_blink = 0.6
	vel += Vector3(4.0, 3.0, 0) # el golpe la empuja
	if hits >= total:
		_die()
		return {"result": "boss_kill", "reward": Config.BOSS_REWARD}
	return {"result": "boss_hit", "reward": 0, "left": total - hits}


func _physics_process(delta: float) -> void:
	_t += delta
	if not alive:
		vel.y -= GRAVITY * delta
		rival.position += vel * delta
		_vis.rotation.z += delta * 8.0
		return
	_blink = maxf(_blink - delta, 0.0)
	cam_right = rival.position.x + 2.5 # la cámara sigue al arma rival
	_vis.visible = _blink <= 0.0 or fmod(_t, 0.12) < 0.06
	if game == null or game.state != game.State.PLAYING:
		_beam.visible = false
		return
	var gp: Vector3 = game.gun.global_position
	if global_position.x - gp.x > Config.BOSS_WAKE:
		return
	# física: gravedad, piso, paredes de la arena
	vel.y -= GRAVITY * delta
	vel.x = lerpf(vel.x, 0.0, 1.0 - exp(-delta * 0.8))
	rival.position += vel * delta
	var floor_y := 0.45 * SCALE
	if rival.position.y < floor_y:
		rival.position.y = floor_y
		vel.y = absf(vel.y) * 0.3
		vel.x *= 0.7
	if rival.position.x < RANGE.x or rival.position.x > RANGE.y:
		rival.position.x = clampf(rival.position.x, RANGE.x, RANGE.y)
		vel.x = -vel.x * 0.5
	# mira hacia vos (cuando no está apuntando)
	var to_gun := gp - rival.global_position
	if _aim_left < 0.0:
		_vis.rotation.z = lerp_angle(_vis.rotation.z, -atan2(to_gun.y, -to_gun.x), 1.0 - exp(-delta * 6.0))
	# saltito: en el piso, tira para abajo y sube (como vos)
	_hop_cd -= delta
	if _hop_cd <= 0.0 and rival.position.y <= floor_y + 0.05:
		_hop_cd = randf_range(0.8, 1.4)
		vel += Vector3(randf_range(-2.5, 2.5), RECOIL * 1.1, 0)
		game._fx_flash(rival.global_position + Vector3(0, -0.6, 0))
		game.sfx.play("shot", -8.0, 0.8)
	# te apunta y dispara
	if _aim_left >= 0.0:
		_aim_left -= delta
		_draw_beam(rival.global_position, _aim_to)
		if _aim_left < 0.0:
			_fire()
		return
	_cd -= delta
	if _cd <= 0.0 and to_gun.length() < 16.0 and game.on_screen(rival.global_position):
		_cd = Config.DUEL_FIRE_EVERY
		_aim_left = Config.DUEL_AIM_TIME
		_aim_to = rival.global_position + to_gun.normalized() * 18.0


func _fire() -> void:
	_beam.visible = false
	var from := rival.global_position
	var dir := (_aim_to - from).normalized()
	game.boss_shoot("bullet", from + dir * 0.9, dir * Config.DUEL_BULLET_SPEED)
	vel -= dir * RECOIL # el retroceso la empuja
	game._fx_flash(from + dir * 0.9)
	game.sfx.play("shot", -2.0, 0.85)


func _draw_beam(a: Vector3, b: Vector3) -> void:
	_beam.visible = true
	var length := a.distance_to(b)
	var ang := atan2(b.y - a.y, b.x - a.x)
	_beam.global_transform = Transform3D(Basis(Vector3.BACK, ang) * Basis.from_scale(Vector3(length, 0.04, 0.04)), (a + b) / 2.0)


func _die() -> void:
	alive = false
	_beam.visible = false
	rival.set_deferred("collision_layer", 0)
	_field.open()
	vel = Vector3(3.0, 8.0, 0)
	if game:
		game.explosion_fx(rival.global_position)
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_callback(queue_free)


func _build_mesh() -> void:
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("d8323f")
	red.metallic = 0.6
	red.roughness = 0.3
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("24272c")
	dark.roughness = 0.55
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("ffcf3a")
	gold.metallic = 0.7
	_box(Gun.SLIDE_SIZE, Gun.SLIDE_POS, 0.0, red)
	_box(Gun.GRIP_SIZE, Gun.GRIP_POS, Gun.GRIP_ANGLE, dark)
	_box(Gun.SIGHT_SIZE, Gun.SIGHT_POS, 0.0, gold)
	_box(Vector3(0.14, 0.02, 0.1), Vector3(-0.08, -0.13, 0.0), 0.0, dark)
	_box(Vector3(Gun.SLIDE_SIZE.x * 0.75, 0.08, 0.15), Vector3(-0.05, -0.02, 0.0), 0.0, gold)


func _box(size: Vector3, pos: Vector3, rot_z: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	mi.rotation.z = rot_z
	_vis.add_child(mi)
