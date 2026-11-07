class_name Padlock
extends Area3D
## Candado que flota. Tiene 4 balas (4 tiros para matarlo, +4).
## Si te toca se te pega al arma: pesa el doble por unos segundos.

var game: Node
var ammo := Config.PADLOCK_AMMO
var alive := true
var _vis: Node3D
var _tag: AmmoTag
var _anchor := Vector3.ZERO
var _t := randf() * TAU
var _fall_v := 0.0


func _ready() -> void:
	collision_layer = Config.L_FLYER
	collision_mask = Config.L_GUN
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.9, 1.2, 0.6)
	cs.shape = bs
	cs.position.y = 0.1
	add_child(cs)
	_anchor = global_position
	_vis = Padlock.build_mesh(1.0)
	add_child(_vis)
	_tag = AmmoTag.new()
	_tag.position = Vector3(0, 1.1, 0)
	add_child(_tag)
	_tag.set_count(ammo)
	body_entered.connect(_on_body)


func shot(_hit: Dictionary, _dir: Vector2) -> Dictionary:
	if not alive:
		return {"result": "none", "reward": 0}
	ammo -= 1
	_tag.set_count(ammo)
	if ammo > 0:
		return {"result": "plane_hit", "reward": 0} # clank metálico
	alive = false
	_tag.visible = false
	set_deferred("monitoring", false)
	set_deferred("collision_layer", 0)
	get_tree().create_timer(3.0).timeout.connect(queue_free)
	return {"result": "padlock_kill", "reward": Config.PADLOCK_REWARD}


func _on_body(body: Node) -> void:
	if alive and body is Gun and game:
		if game.lock_gun():
			alive = false
			queue_free()


func _physics_process(delta: float) -> void:
	_t += delta
	if not alive:
		_fall_v += Tuning.values.gravity * delta
		global_position.y -= _fall_v * delta
		_vis.rotation.z += delta * 3.0
		return
	global_position = _anchor + Vector3(sin(_t * 0.9) * 0.4, sin(_t * 1.8) * 0.35, 0.0)
	_vis.rotation.z = sin(_t * 1.3) * 0.2


## Dibujo del candado (también se usa chiquito pegado al arma).
static func build_mesh(s: float) -> Node3D:
	var root := Node3D.new()
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("ffcf3a")
	gold.metallic = 0.8
	gold.roughness = 0.3
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("c9d1dc")
	steel.metallic = 0.9
	steel.roughness = 0.25
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("2a1838")
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 0.65, 0.35) * s
	bm.material = gold
	body.mesh = bm
	body.position.y = -0.15 * s
	root.add_child(body)
	var shackle := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.2 * s
	tm.outer_radius = 0.3 * s
	tm.material = steel
	shackle.mesh = tm
	shackle.rotation.x = PI / 2.0
	shackle.position.y = 0.2 * s
	root.add_child(shackle)
	var hole := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.07 * s
	hm.bottom_radius = 0.07 * s
	hm.height = 0.05 * s
	hm.material = dark
	hole.mesh = hm
	hole.rotation.x = PI / 2.0
	hole.position = Vector3(0, -0.12 * s, 0.18 * s)
	root.add_child(hole)
	return root
