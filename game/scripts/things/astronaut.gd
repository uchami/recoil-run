class_name Astronaut
extends Area3D
## Astronauta: flota dando vueltas despacio. Si te choca: -1 bala y te empuja.
## Tiene 2 balas (2 tiros, +3).

var game: Node
var ammo := Config.ASTRONAUT_AMMO
var alive := true
var _vis: Node3D
var _tag: AmmoTag
var _vel := Vector3.ZERO
var _spin := 0.0
var _hit_cd := 0.0


func _ready() -> void:
	collision_layer = Config.L_FLYER
	collision_mask = Config.L_GUN
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.7
	cs.shape = cap
	add_child(cs)
	_vel = Vector3(randf_range(-0.8, -0.3), randf_range(-0.3, 0.3), 0.0)
	_spin = randf_range(-0.8, 0.8)
	_build_mesh()
	_tag = AmmoTag.new()
	_tag.position = Vector3(0, 1.4, 0)
	add_child(_tag)
	_tag.set_count(ammo)
	body_entered.connect(_on_body)


func shot(_hit: Dictionary, _dir: Vector2) -> Dictionary:
	if not alive:
		return {"result": "none", "reward": 0}
	ammo -= 1
	_tag.set_count(ammo)
	if ammo > 0:
		return {"result": "chest_hit", "reward": 0}
	alive = false
	_tag.visible = false
	set_deferred("monitoring", false)
	set_deferred("collision_layer", 0)
	get_tree().create_timer(3.0).timeout.connect(queue_free)
	_spin *= 6.0
	return {"result": "flyer_kill", "reward": Config.ASTRONAUT_REWARD}


func _on_body(body: Node) -> void:
	if alive and body is Gun and game and _hit_cd <= 0.0:
		_hit_cd = 1.0
		var away: Vector3 = body.global_position - global_position
		away.z = 0.0
		away = away.normalized() * 6.0
		game.hurt(Config.ASTRONAUT_DAMAGE, global_position, Vector2(away.x, away.y), 4.0, "astronaut")


func _physics_process(delta: float) -> void:
	_hit_cd -= delta
	_vis.rotation.z += _spin * delta
	global_position += _vel * delta
	if not alive:
		_vel.y -= Tuning.values.gravity * 0.3 * delta


func _build_mesh() -> void:
	_vis = Node3D.new()
	add_child(_vis)
	var suit := StandardMaterial3D.new()
	suit.albedo_color = Color("f2f2f0")
	suit.roughness = 0.6
	var visor := StandardMaterial3D.new()
	visor.albedo_color = Color("ffb21a")
	visor.metallic = 0.9
	visor.roughness = 0.1
	var gray := StandardMaterial3D.new()
	gray.albedo_color = Color("9aa3ad")
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.32
	bm.height = 1.0
	bm.material = suit
	body.mesh = bm
	_vis.add_child(body)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.32
	hm.height = 0.64
	hm.material = suit
	head.mesh = hm
	head.position.y = 0.72
	_vis.add_child(head)
	var vis := MeshInstance3D.new()
	var vm := SphereMesh.new()
	vm.radius = 0.22
	vm.height = 0.3
	vm.material = visor
	vis.mesh = vm
	vis.position = Vector3(0, 0.74, 0.2)
	_vis.add_child(vis)
	var pack := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.5, 0.6, 0.25)
	pm.material = gray
	pack.mesh = pm
	pack.position = Vector3(0, 0.1, -0.3)
	_vis.add_child(pack)
	for s in [-1, 1]:
		var arm := MeshInstance3D.new()
		var am := CapsuleMesh.new()
		am.radius = 0.12
		am.height = 0.7
		am.material = suit
		arm.mesh = am
		arm.position = Vector3(s * 0.45, 0.15, 0)
		arm.rotation.z = s * 0.6
		_vis.add_child(arm)
		var leg := arm.duplicate() as MeshInstance3D
		leg.position = Vector3(s * 0.18, -0.7, 0)
		leg.rotation.z = s * 0.2
		_vis.add_child(leg)
