class_name Airplane
extends Area3D
## Avión: cruza el cielo volando hacia la izquierda (hacia vos). Tiene 3 balas.
## Si te choca: -2 balas, te empuja y te hace girar. Al derribarlo: +3.

var game: Node
var ammo := Config.PLANE_AMMO
var alive := true
var _vis: Node3D
var _prop: Node3D
var _tag: AmmoTag
var _life := 0.0
var _fall_v := 0.0
var _hit_done := false


func _ready() -> void:
	collision_layer = Config.L_FLYER
	collision_mask = Config.L_GUN
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.0, 1.0, 1.2)
	cs.shape = bs
	add_child(cs)
	_build_mesh()
	_tag = AmmoTag.new()
	_tag.position = Vector3(0, 1.3, 0)
	add_child(_tag)
	_tag.set_count(ammo)
	body_entered.connect(_on_body)


func shot(_hit: Dictionary, _dir: Vector2) -> Dictionary:
	if not alive:
		return {"result": "none", "reward": 0}
	ammo -= 1
	_tag.set_count(ammo)
	if ammo > 0:
		return {"result": "plane_hit", "reward": 0}
	alive = false
	_tag.visible = false
	set_deferred("monitoring", false)
	set_deferred("collision_layer", 0)
	get_tree().create_timer(4.0).timeout.connect(queue_free)
	return {"result": "plane_kill", "reward": Config.PLANE_REWARD}


func _on_body(body: Node) -> void:
	if alive and body is Gun and game and not _hit_done:
		_hit_done = true
		game.hurt(Config.PLANE_DAMAGE, global_position, Vector2(-6.0, -2.0), 10.0, "plane")


func _physics_process(delta: float) -> void:
	_prop.rotation.x += delta * 40.0
	if not alive:
		_fall_v += Tuning.values.gravity * delta
		global_position += Vector3(-Config.PLANE_SPEED * 0.5, -_fall_v, 0.0) * delta
		_vis.rotation.z -= delta * 1.5
		return
	global_position.x -= Config.PLANE_SPEED * delta
	_life += delta
	if _life > 14.0:
		queue_free()


func _build_mesh() -> void:
	_vis = Node3D.new()
	add_child(_vis)
	var white := _mat(Color("f4f1ea"))
	var teal := _mat(Color("2bb8c4"))
	var dark := _mat(Color("2a2f38"))
	var glass := _mat(Color("8fd8ff"))
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.38
	cm.height = 3.0
	cm.material = white
	body.mesh = cm
	body.rotation.z = PI / 2.0
	_vis.add_child(body)
	_vis.add_child(_box(Vector3(0.7, 0.08, 3.2), Vector3(0.1, -0.05, 0), teal)) # alas
	_vis.add_child(_box(Vector3(0.45, 0.7, 0.08), Vector3(1.3, 0.4, 0), teal)) # timón
	_vis.add_child(_box(Vector3(0.4, 0.06, 1.2), Vector3(1.3, 0.1, 0), teal))
	_vis.add_child(_box(Vector3(0.5, 0.22, 0.4), Vector3(-0.7, 0.32, 0), glass)) # cabina
	_prop = Node3D.new()
	_prop.position = Vector3(-1.55, 0, 0)
	_vis.add_child(_prop)
	_prop.add_child(_box(Vector3(0.05, 1.1, 0.12), Vector3.ZERO, dark))


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	return mi


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	return m
