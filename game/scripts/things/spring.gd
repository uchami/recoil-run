class_name Spring
extends Node3D
## Resorte: si lo tocás te manda bastantes metros para atrás.

var game: Node
var _area: Area3D
var _coil: Node3D
var _cd := 0.0


func _ready() -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("3a3f4a")
	dark.metallic = 0.6
	dark.roughness = 0.35
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("ff3b6b")
	red.roughness = 0.5
	var base := _box(Vector3(1.0, 0.12, 0.9), dark)
	base.position.y = 0.06
	add_child(base)
	_coil = Node3D.new()
	_coil.position.y = 0.12
	add_child(_coil)
	for i in 5:
		var ring := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.22
		t.outer_radius = 0.3
		t.material = dark
		ring.mesh = t
		ring.position.y = 0.08 + i * 0.13
		_coil.add_child(ring)
	var pad := _box(Vector3(0.9, 0.14, 0.8), red)
	pad.position.y = 0.78
	_coil.add_child(pad)

	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = Config.L_GUN
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.1, 1.0, 1.0)
	cs.shape = bs
	cs.position.y = 0.5
	_area.add_child(cs)
	add_child(_area)
	_area.body_entered.connect(_on_body)


func _process(delta: float) -> void:
	_cd -= delta


func _on_body(body: Node) -> void:
	if body is Gun and _cd <= 0.0 and game:
		_cd = 0.5
		game.spring_launch(self)
		_coil.scale.y = 0.4
		var tw := create_tween()
		tw.tween_property(_coil, "scale:y", 1.35, 0.08)
		tw.tween_property(_coil, "scale:y", 1.0, 0.35).set_trans(Tween.TRANS_ELASTIC)


func _box(size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	return mi
