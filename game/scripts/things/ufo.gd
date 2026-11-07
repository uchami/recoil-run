class_name Ufo
extends Area3D
## Ovni: flota y cada tanto te apunta. Primero se ve una línea finita (el aviso)
## hacia donde estabas; a los 0.7 s dispara un láser verde por esa línea. Si te
## da: -5 balas. Tiene 4 balas (4 tiros, +5).

var game: Node
var ammo := Config.UFO_AMMO
var alive := true
var _vis: Node3D
var _tag: AmmoTag
var _anchor := Vector3.ZERO
var _t := randf() * TAU
var _cd := 1.0
var _aim_left := -1.0
var _aim_to := Vector3.ZERO
var _beam: MeshInstance3D
var _beam_mat: StandardMaterial3D
var _fall_v := 0.0
var fired := 0


func _ready() -> void:
	collision_layer = Config.L_FLYER
	collision_mask = Config.L_GUN
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.1
	cyl.height = 0.7
	cs.shape = cyl
	add_child(cs)
	_anchor = global_position
	_build_mesh()
	_tag = AmmoTag.new()
	_tag.position = Vector3(0, 1.2, 0)
	add_child(_tag)
	_tag.set_count(ammo)
	_beam = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1, 1, 1)
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.albedo_color = Color(0.3, 1.0, 0.3, 0.5)
	bm.material = _beam_mat
	_beam.mesh = bm
	_beam.visible = false
	_beam.top_level = true
	add_child(_beam)


func shot(_hit: Dictionary, _dir: Vector2) -> Dictionary:
	if not alive:
		return {"result": "none", "reward": 0}
	ammo -= 1
	_tag.set_count(ammo)
	if ammo > 0:
		return {"result": "plane_hit", "reward": 0}
	alive = false
	_beam.visible = false
	_tag.visible = false
	set_deferred("monitoring", false)
	set_deferred("collision_layer", 0)
	get_tree().create_timer(3.0).timeout.connect(queue_free)
	return {"result": "ufo_kill", "reward": Config.UFO_REWARD}


func _physics_process(delta: float) -> void:
	_t += delta
	_vis.rotation.y += delta * 2.0
	if not alive:
		_fall_v += Tuning.values.gravity * 0.5 * delta
		global_position.y -= _fall_v * delta
		_vis.rotation.z += delta * 2.0
		return
	global_position = _anchor + Vector3(sin(_t * 0.7) * 2.0, sin(_t * 1.4) * 0.4, 0.0)
	if game == null or game.state != game.State.PLAYING:
		_beam.visible = false
		return
	var gun: Node3D = game.gun
	if _aim_left >= 0.0: # apuntando: la línea finita sigue al ovni pero no a vos
		_aim_left -= delta
		_draw_beam(global_position, _aim_to, 0.04, Color(0.3, 1.0, 0.3, 0.45))
		if _aim_left < 0.0:
			_fire(gun)
		return
	_cd -= delta
	if _cd <= 0.0 and global_position.distance_to(gun.global_position) < Config.UFO_SIGHT:
		_cd = Config.UFO_FIRE_EVERY
		_aim_left = Config.UFO_AIM_TIME
		var dir := (gun.global_position - global_position)
		dir.z = 0.0
		_aim_to = global_position + dir.normalized() * Config.UFO_SIGHT * 1.6


func _fire(gun: Node3D) -> void:
	fired += 1
	var from := global_position
	game.sfx.play("laser")
	_draw_beam(from, _aim_to, Config.UFO_BEAM_WIDTH * 0.5, Color(0.4, 1.0, 0.35, 0.9))
	var tw := create_tween()
	tw.tween_property(_beam_mat, "albedo_color:a", 0.0, 0.3)
	tw.tween_callback(func(): _beam.visible = false)
	# ¿te dio? distancia del arma al rayo
	var p: Vector3 = gun.global_position
	var closest := Geometry3D.get_closest_point_to_segment(p, from, _aim_to)
	if p.distance_to(closest) < Config.UFO_BEAM_WIDTH:
		game.hurt(Config.UFO_DAMAGE, closest, Vector2.ZERO, 6.0, "ufo")


func _draw_beam(a: Vector3, b: Vector3, thick: float, color: Color) -> void:
	_beam.visible = true
	_beam_mat.albedo_color = color
	var length := a.distance_to(b)
	var ang := atan2(b.y - a.y, b.x - a.x)
	_beam.global_transform = Transform3D(Basis(Vector3.BACK, ang) * Basis.from_scale(Vector3(length, thick, thick)), (a + b) / 2.0)


func _build_mesh() -> void:
	_vis = Node3D.new()
	add_child(_vis)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("b8c2cc")
	metal.metallic = 0.85
	metal.roughness = 0.25
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.5, 1.0, 0.7, 0.55)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var light := StandardMaterial3D.new()
	light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light.albedo_color = Color("7dff6b")
	var saucer := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.1
	sm.height = 0.5
	sm.material = metal
	saucer.mesh = sm
	_vis.add_child(saucer)
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.5
	dm.height = 0.7
	dm.is_hemisphere = true
	dm.material = glass
	dome.mesh = dm
	dome.position.y = 0.12
	_vis.add_child(dome)
	var alien := MeshInstance3D.new()
	var am := SphereMesh.new()
	am.radius = 0.18
	am.height = 0.36
	am.material = light
	alien.mesh = am
	alien.position.y = 0.3
	_vis.add_child(alien)
	for i in 8:
		var l := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.08
		lm.height = 0.16
		lm.material = light
		l.mesh = lm
		var a := i * TAU / 8.0
		l.position = Vector3(cos(a) * 0.95, -0.02, sin(a) * 0.95)
		_vis.add_child(l)
