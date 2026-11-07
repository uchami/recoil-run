class_name Mimic
extends Area3D
## Cofre trampa abierto: boca con dientes, te persigue. Tiene 2 balas (2 tiros).
## Si te toca, -2 balas. Al matarlo te da 5.

var game: Node
var ammo := Config.MIMIC_AMMO
var alive := true
var _lid: Node3D
var _tag: AmmoTag
var _bite_cd := 0.6
var _t := 0.0
var _vis: Node3D
var _fall_v := 0.0


func _ready() -> void:
	collision_layer = Config.L_FLYER
	collision_mask = Config.L_GUN
	var ws := Chest.world_size()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = ws * 0.9
	cs.shape = bs
	cs.position.y = ws.y / 2.0
	add_child(cs)
	_vis = Node3D.new()
	_vis.scale = Chest.SCALE
	add_child(_vis)
	Chest.build_chest(_vis, true)
	_lid = _vis.get_node("Lid")
	_tag = AmmoTag.new()
	_tag.position = Vector3(0, ws.y + 1.2, 0)
	add_child(_tag)
	_tag.set_count(ammo)


func shot(_hit: Dictionary, _dir: Vector2) -> Dictionary:
	if not alive:
		return {"result": "none", "reward": 0}
	ammo -= 1
	_tag.set_count(ammo)
	if ammo > 0:
		return {"result": "mimic_hit", "reward": 0}
	alive = false
	_tag.visible = false
	set_deferred("monitoring", false)
	set_deferred("collision_layer", 0)
	get_tree().create_timer(3.0).timeout.connect(queue_free)
	return {"result": "mimic_kill", "reward": Config.MIMIC_REWARD}


func _physics_process(delta: float) -> void:
	_t += delta
	if not alive:
		_fall_v += Tuning.values.gravity * delta
		global_position.y -= _fall_v * delta
		_vis.rotation.z += delta * 2.0
		return
	_lid.rotation.z = -0.5 - absf(sin(_t * 6.0)) * 0.5 # mastica
	_bite_cd -= delta
	if game == null or game.state != game.State.PLAYING:
		return
	var gun: Node3D = game.gun
	var target := gun.global_position - Vector3(0, Chest.world_size().y * 0.5, 0)
	var to := target - global_position
	to.z = 0.0
	if to.length() > 40.0 or _t > 25.0: # se cansó
		alive = false
		queue_free()
		return
	global_position += to.normalized() * Config.MIMIC_SPEED * delta
	_vis.scale.x = Chest.SCALE.x * (-1.0 if to.x > 0.0 else 1.0)
	if _bite_cd <= 0.0 and overlaps_body(gun):
		_bite_cd = 1.5
		game.hurt(Config.MIMIC_DAMAGE, global_position, Vector2(signf(to.x) * 5.0, 4.0), 0.0, "mimic")
