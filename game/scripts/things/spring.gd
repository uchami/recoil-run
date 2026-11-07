class_name Spring
extends StaticBody3D
## Resorte vertical (como una pared acolchada): si lo chocás te devuelve para atrás.
## Cuanto más fuerte chocás, más fuerte te empuja y más te hace girar.
## Es sólido (no se atraviesa); un área un poco más grande dispara el empujón.

const THICK := 1.0
const DEPTH := 1.2

var game: Node
var _area: Area3D
var _pad: Node3D
var _cd := 0.0


func _ready() -> void:
	collision_layer = Config.L_TERRAIN
	collision_mask = 0
	var h := Config.SPRING_HEIGHT
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(THICK, h, DEPTH)
	cs.shape = bs
	cs.position.y = h / 2.0
	add_child(cs)

	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("3a3f4a")
	dark.metallic = 0.6
	dark.roughness = 0.35
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("ff3b6b")
	red.roughness = 0.5
	# Poste central y dos almohadillas (una de cada lado) unidas por resortes horizontales.
	add_child(_box(Vector3(0.18, h + 0.1, DEPTH * 0.8), Vector3(0, (h + 0.1) / 2.0, 0), dark))
	_pad = Node3D.new()
	add_child(_pad)
	for side in [-1.0, 1.0]:
		_pad.add_child(_box(Vector3(0.14, h, DEPTH), Vector3(side * (THICK / 2.0 - 0.07), h / 2.0, 0), red))
		for j in 3:
			var y := h * (0.2 + j * 0.3)
			for k in 3:
				var ring := MeshInstance3D.new()
				var t := TorusMesh.new()
				t.inner_radius = 0.13
				t.outer_radius = 0.19
				t.material = dark
				ring.mesh = t
				ring.rotation.z = PI / 2.0 # eje horizontal
				ring.position = Vector3(side * (0.15 + k * 0.1), y, 0)
				_pad.add_child(ring)

	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = Config.L_GUN
	var acs := CollisionShape3D.new()
	var abs_ := BoxShape3D.new()
	abs_.size = Vector3(THICK + 0.7, h + 0.5, DEPTH + 0.4)
	acs.shape = abs_
	acs.position.y = h / 2.0
	_area.add_child(acs)
	add_child(_area)
	_area.body_entered.connect(_on_body)


func _process(delta: float) -> void:
	_cd -= delta


func _on_body(body: Node) -> void:
	if body is Gun and _cd <= 0.0 and game:
		_cd = 0.4
		var away := signf(body.global_position.x - global_position.x)
		if away == 0.0:
			away = -1.0
		game.spring_launch(self, away)
		_pad.scale.x = 0.6
		var tw := create_tween()
		tw.tween_property(_pad, "scale:x", 1.25, 0.07)
		tw.tween_property(_pad, "scale:x", 1.0, 0.35).set_trans(Tween.TRANS_ELASTIC)


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	return mi
