class_name Airplane
extends Area3D
## Avión: cruza el cielo despacio hacia la izquierda (hacia vos). Se derriba de
## un tiro a la hélice de adelante (+5); en el resto del avión las balas rebotan.
## Si te choca: -2 balas, te empuja y te hace girar.

var game: Node
const PROP_X := -1.55 # la hélice, adelante (vuela hacia -X)

var alive := true
var _vis: Node3D
var _prop: Node3D
var _prop_cs: CollisionShape3D
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
	# La hélice: un blanco aparte, un poco más grande que el dibujo para que sea justo.
	_prop_cs = CollisionShape3D.new()
	var ps := BoxShape3D.new()
	ps.size = Vector3(0.45, 1.3, 1.0)
	_prop_cs.shape = ps
	_prop_cs.position.x = PROP_X - 0.1
	add_child(_prop_cs)
	_build_mesh()
	body_entered.connect(_on_body)


func shot(hit: Dictionary, _dir: Vector2) -> Dictionary:
	if not alive:
		return {"result": "none", "reward": 0}
	var part: Object = shape_owner_get_owner(shape_find_owner(hit.get("shape", 0)))
	if part != _prop_cs:
		return {"result": "blocked", "reward": 0}
	alive = false
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
	if _life > 30.0:
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
	_prop.position = Vector3(PROP_X, 0, 0)
	_vis.add_child(_prop)
	# La hélice es el blanco: aspas grandes con puntas rojas y un cono amarillo.
	var red := _mat(Color("e8384f"))
	var yellow := _mat(Color("ffd23a"))
	_prop.add_child(_box(Vector3(0.05, 1.2, 0.14), Vector3.ZERO, dark))
	for sy in [-1, 1]:
		_prop.add_child(_box(Vector3(0.06, 0.18, 0.15), Vector3(0, sy * 0.52, 0), red))
	var spinner := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.0
	sm.bottom_radius = 0.2
	sm.height = 0.3
	sm.material = yellow
	spinner.mesh = sm
	spinner.rotation.z = PI / 2.0
	spinner.position = Vector3(PROP_X - 0.12, 0, 0)
	_vis.add_child(spinner)


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
