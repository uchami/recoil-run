class_name Mimic
extends Area3D
## Cofre-trampa abierto: boca con dientes, te persigue. Si te toca, -2 balas.

var game: Node
var hp := Config.MIMIC_HP
var alive := true
var _lid: Node3D
var _bar: HealthBar
var _bite_cd := 0.6
var _t := 0.0
var _vis: Node3D
var _fall_v := 0.0


func _ready() -> void:
	collision_layer = Config.L_FLYER
	collision_mask = Config.L_GUN
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Chest.SIZE + Vector3(0.1, 0.2, 0.1)
	cs.shape = bs
	cs.position.y = Chest.SIZE.y / 2.0
	add_child(cs)
	_vis = Node3D.new()
	add_child(_vis)
	Chest.build_chest(_vis, true)
	_lid = _vis.get_node("Lid")
	_bar = HealthBar.new()
	_bar.position = Vector3(0, Chest.SIZE.y + 0.75, 0)
	add_child(_bar)
	_bar.set_ratio(1.0)


func shot(_hit: Dictionary, _dir: Vector2) -> Dictionary:
	if not alive:
		return {"result": "none", "reward": 0}
	hp -= 1
	_bar.set_ratio(float(hp) / Config.MIMIC_HP)
	if hp > 0:
		return {"result": "mimic_hit", "reward": 0}
	alive = false
	_bar.visible = false
	set_deferred("monitoring", false)
	set_deferred("collision_layer", 0)
	get_tree().create_timer(3.0).timeout.connect(queue_free)
	return {"result": "mimic_kill", "reward": Config.MIMIC_REWARD}


func _physics_process(delta: float) -> void:
	_t += delta
	if not alive:
		_fall_v += Tuning.values.gravity * delta
		global_position.y -= _fall_v * delta
		_vis.rotation.z += delta * 4.0
		return
	_lid.rotation.z = -0.5 - absf(sin(_t * 9.0)) * 0.5 # mastica
	_bite_cd -= delta
	if game == null or game.state != game.State.PLAYING:
		return
	var gun: Node3D = game.gun
	var target := gun.global_position - Vector3(0, Chest.SIZE.y * 0.5, 0)
	var to := target - global_position
	to.z = 0.0
	if to.length() > 35.0 or _t > 25.0: # se cansó
		alive = false
		queue_free()
		return
	global_position += to.normalized() * Config.MIMIC_SPEED * delta
	_vis.scale.x = -1.0 if to.x > 0.0 else 1.0
	if _bite_cd <= 0.0 and overlaps_body(gun):
		_bite_cd = 1.5
		game.hurt(Config.MIMIC_DAMAGE, global_position, Vector2(signf(to.x) * 4.0, 3.0), 0.0, "mimic")
