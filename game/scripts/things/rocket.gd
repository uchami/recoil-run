class_name Rocket
extends Area3D
## Cohete: cuando te ve, toma tu posición y va rápido en línea recta hacia ahí.
## Tiene 1 bala: un tiro lo explota (+1). Si te toca, explota: -2 balas, empujón y giro.

var game: Node
var alive := true
var _dir := Vector3.ZERO
var _vis: Node3D
var _flame: MeshInstance3D
var _life := 0.0
var _t := 0.0


func _ready() -> void:
	collision_layer = Config.L_FLYER
	collision_mask = Config.L_GUN
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	cs.shape = cap
	cs.rotation.z = PI / 2.0
	add_child(cs)
	_build_mesh()
	body_entered.connect(_on_body)


func shot(_hit: Dictionary, _d: Vector2) -> Dictionary:
	if not alive:
		return {"result": "none", "reward": 0}
	_explode()
	return {"result": "rocket_kill", "reward": Config.ROCKET_REWARD}


func _on_body(body: Node) -> void:
	if alive and body is Gun and game:
		var away: Vector3 = body.global_position - global_position
		away.z = 0.0
		away = away.normalized() * 8.0
		game.hurt(Config.ROCKET_DAMAGE, global_position, Vector2(away.x, away.y), 12.0 * (1.0 if randf() < 0.5 else -1.0), "rocket")
		_explode()


func _explode() -> void:
	alive = false
	set_deferred("monitoring", false)
	set_deferred("collision_layer", 0)
	if game:
		game.explosion_fx(global_position)
	queue_free()


func _physics_process(delta: float) -> void:
	_t += delta
	_flame.scale = Vector3.ONE * (0.8 + absf(sin(_t * 30.0)) * 0.5)
	if game == null:
		return
	if _dir == Vector3.ZERO:
		if game.state != game.State.PLAYING:
			return
		var to: Vector3 = game.gun.global_position - global_position
		to.z = 0.0
		if to.length() < Config.ROCKET_SIGHT:
			_dir = to.normalized()
			_vis.rotation.z = atan2(_dir.y, _dir.x)
			game.sfx.play("engine", -6.0)
		return
	global_position += _dir * Config.ROCKET_SPEED * delta
	_life += delta
	if _life > 8.0:
		queue_free()


func _build_mesh() -> void:
	_vis = Node3D.new()
	_vis.rotation.z = PI # apunta hacia la izquierda mientras espera
	add_child(_vis)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("e8384f")
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("f4f1ea")
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.22
	cyl.bottom_radius = 0.22
	cyl.height = 1.1
	cyl.material = white
	body.mesh = cyl
	body.rotation.z = -PI / 2.0
	_vis.add_child(body)
	var nose := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.0
	nm.bottom_radius = 0.22
	nm.height = 0.45
	nm.material = red
	nose.mesh = nm
	nose.rotation.z = -PI / 2.0
	nose.position.x = 0.77
	_vis.add_child(nose)
	for s in [-1, 1]:
		var fin := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.4, 0.35, 0.05)
		pm.material = red
		fin.mesh = pm
		fin.position = Vector3(-0.45, s * 0.3, 0)
		fin.rotation.z = 0.0 if s > 0 else PI
		_vis.add_child(fin)
	_flame = MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.2
	fm.height = 0.5
	var flame_mat := StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.albedo_color = Color("ffb21a")
	fm.material = flame_mat
	_flame.mesh = fm
	_flame.rotation.z = PI / 2.0
	_flame.position.x = -0.72
	_vis.add_child(_flame)
