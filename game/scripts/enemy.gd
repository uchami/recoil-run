class_name Enemy
extends RigidBody3D
## Personaje: origen en los pies. Vivo = pesado y sin rotar (obstáculo sólido).
## Muerto = más liviano, rota libre y sale volando (ragdoll de un cuerpo).
##
## kind:
##   plain  - sin nada
##   sword  - con espada: si te acercás, te pega (-1 bala) y te empuja
##   shield - escudo adelante (tapa el torso del lado de donde venís): solo cabeza
##   helmet - casco: la cabeza rebota las balas, hay que darle al torso

const HEAD_R := 0.3
const HEAD_Y := 1.68
const BODY_R := 0.25
const BODY_H := 1.4
const SHIELD_SIZE := Vector3(0.1, 1.2, 0.7)
const SHIELD_POS := Vector3(-0.45, 0.82, 0.0)

var kind := "plain"
var game: Node # main.gd (para hurt() y el arma)
var alive := true
var _mat: StandardMaterial3D
var _vis: Node3D
var _arms: Array[MeshInstance3D] = []
var _head: MeshInstance3D
var _phase := randf() * TAU
var _head_cs: CollisionShape3D
var _shield_cs: CollisionShape3D
var _death_y := 0.0
# espada
var _reach: Area3D
var _sword_pivot: Node3D
var _sword_cd := 0.0
var _swinging := false


func _ready() -> void:
	mass = Config.ENEMY_MASS
	axis_lock_linear_z = true
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	lock_rotation = true
	collision_layer = Config.L_ENEMY
	collision_mask = Config.L_TERRAIN | Config.L_GUN
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.0
	physics_material_override = pm

	# Caja (no cápsula): con base plana el arma no se puede colar por debajo.
	var body := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(BODY_R * 2.0, BODY_H, 0.5)
	body.shape = box
	body.position.y = BODY_H / 2.0
	add_child(body)
	_head_cs = CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = HEAD_R
	_head_cs.shape = sph
	_head_cs.position.y = HEAD_Y
	add_child(_head_cs)
	if kind == "shield":
		_shield_cs = CollisionShape3D.new()
		var sb := BoxShape3D.new()
		sb.size = SHIELD_SIZE
		_shield_cs.shape = sb
		_shield_cs.position = SHIELD_POS
		add_child(_shield_cs)
	if kind == "sword":
		_reach = Area3D.new()
		_reach.collision_layer = 0
		_reach.collision_mask = Config.L_GUN
		var rc := CollisionShape3D.new()
		var rs := SphereShape3D.new()
		rs.radius = Config.SWORD_REACH
		rc.shape = rs
		rc.position.y = 1.0
		_reach.add_child(rc)
		add_child(_reach)

	_build_mesh()


## Una bala le pegó. Devuelve {result: "kill"|"headshot"|"blocked", reward}.
func shot(hit: Dictionary, dir: Vector2) -> Dictionary:
	if not alive:
		return {"result": "none", "reward": 0}
	var part: Object = shape_owner_get_owner(shape_find_owner(hit.get("shape", 0)))
	if part == _shield_cs and part != null:
		return {"result": "blocked", "reward": 0}
	var head := part == _head_cs or is_head_hit(hit.position)
	if head and kind == "helmet":
		return {"result": "blocked", "reward": 0}
	kill(hit.position, dir)
	if head:
		return {"result": "headshot", "reward": Config.HEADSHOT_REWARD}
	return {"result": "kill", "reward": Config.KILL_REWARD}


## hit_point en coordenadas globales; dir = dirección de la bala.
func kill(hit_point: Vector3, dir: Vector2) -> void:
	if not alive:
		return
	alive = false
	_death_y = global_position.y
	lock_rotation = false
	mass = Config.CORPSE_MASS
	collision_layer = Config.L_CORPSE
	collision_mask = Config.L_TERRAIN | Config.L_CORPSE
	_mat.albedo_color = Color("b30f0f")
	for a in _arms:
		a.rotation.z = signf(a.position.z) * 1.2
	if _reach:
		_reach.queue_free()
		_reach = null
	var impulse := Vector3(dir.x, dir.y, 0.0) * Config.KILL_IMPULSE + Vector3(0.0, Config.KILL_IMPULSE * 0.5, 0.0)
	apply_impulse(impulse, hit_point - global_position)


func is_head_hit(global_point: Vector3) -> bool:
	return to_local(global_point).y >= Config.NECK_Y


func _process(delta: float) -> void:
	if alive:
		_phase += delta * 2.0
		var s := sin(_phase)
		if not _swinging:
			_arms[0].rotation.z = 0.15 + s * 0.12
		_arms[1].rotation.z = -0.15 - s * 0.12
		_head.position.y = HEAD_Y + absf(s) * 0.02
	elif global_position.y < _death_y - 30.0:
		queue_free()


func _physics_process(delta: float) -> void:
	if not alive or _reach == null or game == null:
		return
	var gun: Node3D = game.gun
	# Mira hacia el arma (la espada del lado de donde viene).
	_vis.scale.x = -1.0 if gun.global_position.x > global_position.x else 1.0
	_sword_cd -= delta
	if _sword_cd <= 0.0 and _reach.overlaps_body(gun):
		_swing(gun)


func _swing(gun: Node3D) -> void:
	_sword_cd = Config.SWORD_COOLDOWN
	_swinging = true
	var tw := create_tween()
	tw.tween_property(_sword_pivot, "rotation:z", 1.4, 0.12) # levanta
	tw.tween_property(_sword_pivot, "rotation:z", -1.2, 0.08) # golpe
	tw.tween_callback(func():
		if alive and _reach and _reach.overlaps_body(gun):
			var away := signf(gun.global_position.x - global_position.x)
			game.hurt(1, global_position + Vector3(0, 1.0, 0), Vector2(away * Config.SWORD_KNOCK.x, Config.SWORD_KNOCK.y), 0.0, "sword"))
	tw.tween_property(_sword_pivot, "rotation:z", 0.0, 0.3)
	tw.tween_callback(func(): _swinging = false)


func _build_mesh() -> void:
	_vis = Node3D.new()
	add_child(_vis)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color("ff1a1a")
	_mat.roughness = 0.55
	_head = _part(_sphere(HEAD_R), Vector3(0, HEAD_Y, 0), 0.0)
	_part(_capsule(0.2, 0.84), Vector3(0, 1.06, 0), 0.0)
	_part(_capsule(0.09, 0.78), Vector3(0.08, 0.42, 0.11), -0.18)
	_part(_capsule(0.09, 0.78), Vector3(-0.08, 0.42, -0.11), 0.18)
	_arms.append(_part(_capsule(0.075, 0.65), Vector3(-0.05, 1.02, 0.27), 0.15))
	_arms.append(_part(_capsule(0.075, 0.65), Vector3(0.05, 1.02, -0.27), -0.15))

	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("c9d1dc")
	steel.metallic = 0.8
	steel.roughness = 0.25
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("3a3f4a")
	dark.metallic = 0.5
	dark.roughness = 0.4
	match kind:
		"shield":
			var sh := _mesh_box(SHIELD_SIZE, steel)
			sh.position = SHIELD_POS
			_vis.add_child(sh)
			var boss := _mesh_box(Vector3(0.06, 0.3, 0.3), dark)
			boss.position = SHIELD_POS + Vector3(-0.07, 0.05, 0)
			_vis.add_child(boss)
		"helmet":
			var dome := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = HEAD_R * 1.15
			sm.height = HEAD_R * 1.4
			sm.is_hemisphere = true
			sm.material = dark
			dome.mesh = sm
			_head.add_child(dome)
			dome.position.y = -0.02
			var rim := _mesh_box(Vector3(0.75, 0.05, 0.75), dark)
			rim.position.y = -0.02
			_head.add_child(rim)
		"sword":
			# La espada cuelga de la mano del brazo delantero y gira desde el hombro.
			_sword_pivot = Node3D.new()
			_sword_pivot.position = Vector3(-0.05, 1.32, 0.3)
			_vis.add_child(_sword_pivot)
			var blade := _mesh_box(Vector3(0.08, 1.1, 0.03), steel)
			blade.position = Vector3(-0.35, -0.2, 0)
			blade.rotation.z = -1.0
			_sword_pivot.add_child(blade)
			var guard := _mesh_box(Vector3(0.06, 0.06, 0.28), dark)
			guard.position = Vector3(-0.05, -0.4, 0)
			_sword_pivot.add_child(guard)


func _mesh_box(size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	return mi


func _part(mesh: Mesh, pos: Vector3, rot_z: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat
	mi.position = pos
	mi.rotation.z = rot_z
	_vis.add_child(mi)
	return mi


func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	return m


func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	return m
