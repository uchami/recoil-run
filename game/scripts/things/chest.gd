class_name Chest
extends StaticBody3D
## Cofre: muere con 3 tiros (barrita de vida). Cada tiro escupe 2 balas que hay
## que pasar a recoger. El trampa, al morir, abre la boca con dientes y te persigue.

const SIZE := Vector3(1.0, 0.75, 0.8)

var trap := false
var game: Node
var hp := Config.CHEST_HP
var _lid: Node3D
var _bar: HealthBar
var _body_mat: StandardMaterial3D


func _ready() -> void:
	collision_layer = Config.L_ENEMY
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = SIZE
	cs.shape = bs
	cs.position.y = SIZE.y / 2.0
	add_child(cs)
	Chest.build_chest(self, false)
	_lid = get_node("Lid")
	_bar = HealthBar.new()
	_bar.position = Vector3(0, SIZE.y + 0.55, 0)
	add_child(_bar)
	_bar.set_ratio(1.0)


func shot(hit: Dictionary, dir: Vector2) -> Dictionary:
	if hp <= 0:
		return {"result": "none", "reward": 0}
	hp -= 1
	_bar.set_ratio(float(hp) / Config.CHEST_HP)
	for i in Config.CHEST_SPIT:
		game.spawn_pickup("ammo", global_position + Vector3(0, SIZE.y + 0.2, 0),
			Vector3(randf_range(-2.5, 2.5), randf_range(5.0, 7.0), 0.0))
	var tw := create_tween()
	scale = Vector3(1.15, 0.85, 1.0)
	tw.tween_property(self, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	if hp > 0:
		return {"result": "chest_hit", "reward": 0}
	collision_layer = 0
	if trap:
		game.spawn_mimic(global_position)
		queue_free()
		return {"result": "trap_open", "reward": 0}
	_bar.visible = false
	var tw2 := create_tween()
	tw2.tween_property(_lid, "rotation:z", -1.9, 0.25).set_trans(Tween.TRANS_BACK)
	tw2.tween_interval(0.8)
	tw2.tween_property(self, "scale", Vector3.ONE * 0.01, 0.25)
	tw2.tween_callback(queue_free)
	return {"result": "chest_open", "reward": 0}


## Arma el cofre (cuerpo + tapa "Lid") como hijos de parent. mouth = versión mimic.
static func build_chest(parent: Node3D, mouth: bool) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("a8682f") if not mouth else Color("8a4b22")
	wood.roughness = 0.8
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("ffcf3a")
	gold.metallic = 0.7
	gold.roughness = 0.3
	var low := SIZE.y * 0.62
	parent.add_child(_box(Vector3(SIZE.x, low, SIZE.z), Vector3(0, low / 2.0, 0), wood))
	for x in [-0.42, 0.42]:
		parent.add_child(_box(Vector3(0.08, low + 0.01, SIZE.z + 0.02), Vector3(x, low / 2.0, 0), gold))
	# La tapa gira desde la bisagra de atrás (x = +SIZE.x/2).
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(SIZE.x / 2.0, low, 0)
	parent.add_child(lid)
	var lid_h := SIZE.y - low
	lid.add_child(_box(Vector3(SIZE.x, lid_h, SIZE.z), Vector3(-SIZE.x / 2.0, lid_h / 2.0, 0), wood))
	for x in [-0.42, 0.42]:
		lid.add_child(_box(Vector3(0.08, lid_h + 0.01, SIZE.z + 0.02), Vector3(-SIZE.x / 2.0 + x, lid_h / 2.0, 0), gold))
	parent.add_child(_box(Vector3(0.06, 0.16, 0.16), Vector3(-SIZE.x / 2.0 - 0.02, low, 0), gold)) # cerradura
	if mouth:
		var white := StandardMaterial3D.new()
		white.albedo_color = Color("fffbe8")
		var red := StandardMaterial3D.new()
		red.albedo_color = Color("c2183c")
		parent.add_child(_box(Vector3(SIZE.x * 0.8, 0.05, SIZE.z * 0.7), Vector3(0, low - 0.02, 0), red)) # lengua
		for i in 6:
			var tx := -SIZE.x / 2.0 + 0.1 + i * 0.16
			var tooth := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.1, 0.14, 0.1)
			pm.material = white
			tooth.mesh = pm
			tooth.position = Vector3(tx, low + 0.07, SIZE.z / 2.0 - 0.06)
			parent.add_child(tooth)
			var top_tooth := tooth.duplicate() as MeshInstance3D
			top_tooth.rotation.z = PI
			top_tooth.position = Vector3(tx - lid.position.x + 0.08, -0.07, SIZE.z / 2.0 - 0.06) # en coords de la tapa
			lid.add_child(top_tooth)
		var eye_m := StandardMaterial3D.new()
		eye_m.albedo_color = Color("ffe14a")
		eye_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for x in [-0.25, 0.1]:
			var eye := MeshInstance3D.new()
			var e := SphereMesh.new()
			e.radius = 0.07
			e.height = 0.14
			e.material = eye_m
			eye.mesh = e
			eye.position = Vector3(-SIZE.x / 2.0 + x + 0.2, lid_h * 0.6, SIZE.z / 2.0 + 0.01)
			lid.add_child(eye)


static func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	return mi
