class_name Mimic
extends Area3D
## Cofre trampa abierto: boca con dientes, te persigue con la boca abierta.
## Si te mete en la boca, la cierra y perdés la partida (sin seguro que valga).
## Si solo te roza la madera, -2 balas. Se mata de un tiro a la boca (la lengua):
## +5. En la madera (abajo o la tapa de atrás) la bala rebota.

var game: Node
var alive := true
var _lid: Node3D
var _tongue: Node3D
var _bite_cd := 0.6
var _t := 0.0
var _vis: Node3D
var _fall_v := 0.0
var _facing := -1.0 # -1 = la boca mira a la izquierda (como el cofre), +1 = a la derecha
var _jaw_cs: CollisionShape3D
var _mouth_cs: CollisionShape3D
var _back_cs: CollisionShape3D
var _chomped := false


func _ready() -> void:
	collision_layer = Config.L_FLYER
	collision_mask = Config.L_GUN
	_jaw_cs = _shape()
	_mouth_cs = _shape()
	_back_cs = _shape()
	_vis = Node3D.new()
	_vis.scale = Chest.SCALE
	add_child(_vis)
	Chest.build_chest(_vis, true)
	_lid = _vis.get_node("Lid")
	_tongue = _vis.get_node("Tongue")
	_set_facing(-1.0)


func _shape() -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	add_child(cs)
	return cs


## Arma las tres partes según para dónde mira: abajo (madera), la boca adelante
## (el punto débil) y la tapa cerrada atrás, cerca de la bisagra (madera).
func _set_facing(f: float) -> void:
	_facing = f
	var ws := Chest.world_size() * Vector3(0.9, 1.0, 0.9)
	var low := Chest.SIZE.y * 0.62 * Chest.SCALE.y - 0.1
	var mouth_h := 1.9
	var mouth_w := ws.x * 0.58
	(_jaw_cs.shape as BoxShape3D).size = Vector3(ws.x, low, ws.z)
	_jaw_cs.position = Vector3(0, low / 2.0, 0)
	(_mouth_cs.shape as BoxShape3D).size = Vector3(mouth_w, mouth_h, ws.z)
	_mouth_cs.position = Vector3(f * (ws.x - mouth_w) / 2.0, low + mouth_h / 2.0, 0)
	(_back_cs.shape as BoxShape3D).size = Vector3(ws.x - mouth_w, mouth_h, ws.z)
	_back_cs.position = Vector3(-f * mouth_w / 2.0, low + mouth_h / 2.0, 0)
	_vis.scale.x = Chest.SCALE.x * -f


## Dónde pegarle (para los tests y la demo): adentro de la boca.
func mouth_position() -> Vector3:
	return _mouth_cs.global_position + Vector3(_facing * 0.6, -0.3, 0)


func shot(hit: Dictionary, _dir: Vector2) -> Dictionary:
	if not alive:
		return {"result": "none", "reward": 0}
	var part: Object = shape_owner_get_owner(shape_find_owner(hit.get("shape", 0)))
	if part != _mouth_cs:
		return {"result": "mimic_hit", "reward": 0}
	alive = false
	set_deferred("monitoring", false)
	set_deferred("collision_layer", 0)
	get_tree().create_timer(3.0).timeout.connect(queue_free)
	return {"result": "mimic_kill", "reward": Config.MIMIC_REWARD}


## ¿El arma está adentro de la boca?
func _in_mouth(p: Vector3) -> bool:
	var local := to_local(p) - _mouth_cs.position
	var half := (_mouth_cs.shape as BoxShape3D).size / 2.0 + Vector3(0.4, 0.3, 0) # el arma tiene tamaño
	return absf(local.x) < half.x and absf(local.y) < half.y


## Cierra la boca de golpe (con el arma adentro).
func _chomp() -> void:
	_chomped = true
	var tw := create_tween()
	tw.tween_property(_lid, "rotation:z", 0.0, 0.12).set_trans(Tween.TRANS_BACK)
	_tongue.visible = false


func _physics_process(delta: float) -> void:
	_t += delta
	if not alive:
		_fall_v += Tuning.values.gravity * delta
		global_position.y -= _fall_v * delta
		_vis.rotation.z += delta * 2.0
		return
	if _chomped: # boca cerrada, masticando
		_vis.scale.y = Chest.SCALE.y * (1.0 + sin(_t * 14.0) * 0.04)
		return
	_lid.rotation.z = -0.5 - absf(sin(_t * 6.0)) * 0.5 # mastica
	_tongue.rotation.z = sin(_t * 9.0) * 0.25 # la lengua se mueve: es el blanco
	_bite_cd -= delta
	if game == null or game.state != game.State.PLAYING:
		return
	var gun: Node3D = game.gun
	if _in_mouth(gun.global_position) and game.eat_gun(global_position + Vector3(0, Chest.world_size().y, 0)):
		_chomp()
		return
	# va con la boca hacia vos: que el arma le quede en la boca
	var target := gun.global_position - (_mouth_cs.position + Vector3(-_facing * 0.4, -0.2, 0))
	var to := target - global_position
	to.z = 0.0
	if to.length() > 40.0 or _t > 25.0: # se cansó
		alive = false
		queue_free()
		return
	global_position += to.normalized() * Config.MIMIC_SPEED * delta
	var f := 1.0 if to.x > 0.0 else -1.0
	if f != _facing and absf(to.x) > 0.5:
		_set_facing(f)
	if _bite_cd <= 0.0 and overlaps_body(gun):
		_bite_cd = 1.5
		game.hurt(Config.MIMIC_DAMAGE, global_position, Vector2(signf(to.x) * 5.0, 4.0), 0.0, "mimic")
