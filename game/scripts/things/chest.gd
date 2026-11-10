class_name Chest
extends StaticBody3D
## Cofre grande con un candado adelante (del lado de donde venís).
## - Tiro al candado: el cofre se abre. Bueno: 50 % +15 balas, 50 % un poder.
##   Trampa: abre la boca con dientes y te persigue (se mata de un tiro a la boca).
## - Tiros al cofre: rebotan en la madera, no le hacen nada.
## - Si te chocás el candado: se te pega al arma (pesás más) y el cofre se entierra
##   ("COFRE PERDIDO").
## Los primeros SAFE_CHESTS cofres que abrís (contados para siempre en el teléfono) nunca son trampa.

const SIZE := Vector3(1.0, 0.75, 0.8) # tamaño del dibujo base (se escala por SCALE)
const SCALE := Vector3(5.0, 5.0, 3.5)
const LOCK_SCALE := 1.15
const LOCK_POS := Vector3(-2.82, 2.0, 0.4) # colgando adelante, a la altura de la cerradura

var trap := false
var game: Node
var opened := false
var lost := false
var _vis: Node3D
var _lid: Node3D
var _lock: LockArea
var _lock_vis: Node3D


## El candado del cofre: es lo que hay que pegarle (y lo que no hay que tocar).
class LockArea extends Area3D:
	var chest: Chest

	func shot(hit: Dictionary, dir: Vector2) -> Dictionary:
		return chest.shot_lock(hit, dir)


static func world_size() -> Vector3:
	return SIZE * SCALE


func _ready() -> void:
	collision_layer = Config.L_ENEMY
	collision_mask = 0
	var ws := world_size()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = ws
	cs.shape = bs
	cs.position.y = ws.y / 2.0
	add_child(cs)
	_vis = Node3D.new()
	_vis.scale = SCALE
	add_child(_vis)
	Chest.build_chest(_vis, false)
	_lid = _vis.get_node("Lid")

	_lock_vis = Padlock.build_mesh(LOCK_SCALE)
	_lock_vis.position = LOCK_POS
	add_child(_lock_vis)
	_lock = LockArea.new()
	_lock.chest = self
	_lock.collision_layer = Config.L_FLYER
	_lock.collision_mask = Config.L_GUN
	var lcs := CollisionShape3D.new()
	var lbs := BoxShape3D.new()
	lbs.size = Vector3(0.95, 1.25, 1.0) * LOCK_SCALE
	lcs.shape = lbs
	lcs.position = LOCK_POS + Vector3(0, 0.05, -0.4)
	_lock.add_child(lcs)
	add_child(_lock)
	_lock.body_entered.connect(_on_lock_touched)


## Una bala le pegó al cofre (no al candado): rebota en la madera.
func shot(_hit: Dictionary, _dir: Vector2) -> Dictionary:
	if opened or lost:
		return {"result": "none", "reward": 0}
	_wobble()
	return {"result": "chest_hit", "reward": 0}


## Una bala le pegó al candado: se abre.
func shot_lock(_hit: Dictionary, dir: Vector2) -> Dictionary:
	if opened or lost:
		return {"result": "none", "reward": 0}
	opened = true
	collision_layer = 0
	_drop_lock(dir)
	# Los primeros cofres que abrís en tu vida nunca son trampa (se decide al abrirlo).
	if Records.bump("chests_killed") <= Config.SAFE_CHESTS:
		trap = false
	if trap:
		game.spawn_mimic(global_position)
		queue_free()
		return {"result": "trap_open", "reward": 0}
	var tw := create_tween()
	tw.tween_property(_lid, "rotation:z", -1.9, 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.8)
	tw.tween_property(_vis, "scale", Vector3.ONE * 0.01, 0.25)
	tw.tween_callback(queue_free)
	if randf() < Config.CHEST_POWER_CHANCE:
		return {"result": "chest_kill", "reward": 0, "power": true}
	return {"result": "chest_kill", "reward": Config.CHEST_REWARD}


## Te chocaste el candado: se te pega y el cofre se entierra.
func _on_lock_touched(body: Node) -> void:
	if opened or lost or not body is Gun or game == null:
		return
	if not game.lock_gun():
		return # intocable (o la partida no está en juego)
	lost = true
	_lock_vis.visible = false
	_lock.set_deferred("monitoring", false)
	_lock.set_deferred("collision_layer", 0)
	set_deferred("collision_layer", 0)
	game.chest_lost(global_position + Vector3(0, world_size().y + 0.5, 0))
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y - world_size().y - 0.6, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _wobble() -> void:
	_vis.scale = SCALE * Vector3(1.04, 0.96, 1.0)
	create_tween().tween_property(_vis, "scale", SCALE, 0.2).set_trans(Tween.TRANS_BACK)


## El candado se suelta y cae girando.
func _drop_lock(dir: Vector2) -> void:
	_lock.set_deferred("monitoring", false)
	_lock.collision_layer = 0
	var tw := create_tween().set_parallel()
	tw.tween_property(_lock_vis, "position", _lock_vis.position + Vector3(dir.x * 1.5 - 0.5, -2.2, 0), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_lock_vis, "rotation:z", 4.0, 0.6)
	tw.chain().tween_callback(_lock_vis.hide)


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
	if not mouth:
		return
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("fffbe8")
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("2a0c14")
	parent.add_child(_box(Vector3(SIZE.x * 0.9, 0.03, SIZE.z * 0.85), Vector3(0, low - 0.01, 0), dark)) # adentro de la boca
	# La lengua: el punto débil. Sale por adelante y se mueve (el mimic la anima).
	var tongue := Node3D.new()
	tongue.name = "Tongue"
	tongue.position = Vector3(0.1, low + 0.03, 0)
	parent.add_child(tongue)
	var pink := StandardMaterial3D.new()
	pink.albedo_color = Color("ff3d6e")
	pink.emission_enabled = true
	pink.emission = Color("ff2a5a")
	pink.emission_energy_multiplier = 0.6
	tongue.add_child(_box(Vector3(0.72, 0.07, SIZE.z * 0.45), Vector3(-0.36, 0.0, 0), pink))
	tongue.add_child(_box(Vector3(0.12, 0.09, SIZE.z * 0.5), Vector3(-0.72, 0.01, 0), pink))
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
