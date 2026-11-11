class_name Mole
extends Node3D
## Jefe topo gigante: hay 4 pozos en el piso; sale de uno, un ratito, con la
## nariz roja brillando. Un tiro a la nariz = un golpe (y se esconde). En el
## cuerpo la bala rebota. Mientras está afuera te tira una piedra. 4 golpes: muere.
## Detrás, un campo de fuerza: hasta que no lo matás, no pasás.
## Origen: el piso, en el medio de los pozos.

const HOLES := [-9.0, -3.0, 3.0, 9.0] # x de cada pozo (local)
const NOSE := Vector3(-0.95, 1.95, 0.0) # nariz (local al topo)
const NOSE_R := 0.32
const HIDDEN_Y := -3.2
const FIELD_X := 12.0

var game: Node
var alive := true
var total := 4
var hits := 0
var cam_height := 3.0
var cam_right := 10.0
var state := "wait" # wait -> rising -> up -> sinking -> wait
var hole := -1 # pozo en el que está (o va a salir)
var _cd := 1.2
var _threw := false
var _body: StaticBody3D
var _nose_cs: CollisionShape3D
var _nose_mat: StandardMaterial3D
var _field: ForceField
var _t := 0.0


func _ready() -> void:
	_field = ForceField.new()
	_field.position = Vector3(FIELD_X, 0, 0)
	add_child(_field)
	for x in HOLES: # pozos: agujero negro con borde de tierra
		var ring := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 1.5
		rm.bottom_radius = 1.6
		rm.height = 0.12
		var dirt := StandardMaterial3D.new()
		dirt.albedo_color = Color("8a6238")
		rm.material = dirt
		ring.mesh = rm
		ring.position = Vector3(x, 0.03, 0)
		add_child(ring)
		var pit := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 1.15
		pm.bottom_radius = 1.15
		pm.height = 0.14
		var black := StandardMaterial3D.new()
		black.albedo_color = Color("120a08")
		pm.material = black
		pit.mesh = pm
		pit.position = Vector3(x, 0.05, 0)
		add_child(pit)
	_body = StaticBody3D.new()
	_body.collision_layer = 0
	_body.collision_mask = 0
	add_child(_body)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.0
	cap.height = 3.6
	cs.shape = cap
	cs.position.y = 1.0
	_body.add_child(cs)
	_nose_cs = CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = NOSE_R
	_nose_cs.shape = sph
	_nose_cs.position = NOSE
	_body.add_child(_nose_cs)
	_build_mesh()
	_body.position.y = HIDDEN_Y
	_body.visible = false
	_body.set_meta("boss", self) # los tiros al cuerpo los atiende el topo


## Dónde está la nariz (para los tests).
func nose_position() -> Vector3:
	return _body.to_global(NOSE)


func shot(hit: Dictionary, _dir: Vector2) -> Dictionary:
	if not alive or state == "wait":
		return {"result": "none", "reward": 0}
	var part: Object = _body.shape_owner_get_owner(_body.shape_find_owner(hit.get("shape", 0)))
	if part != _nose_cs or state == "sinking":
		return {"result": "blocked", "reward": 0}
	hits += 1
	if hits >= total:
		_die()
		return {"result": "boss_kill", "reward": Config.BOSS_REWARD}
	_sink(0.0)
	return {"result": "boss_hit", "reward": 0, "left": total - hits}


func _physics_process(delta: float) -> void:
	_t += delta
	if not alive or game == null:
		return
	_nose_mat.albedo_color = Color("ff2a3a").lerp(Color("ffd0d0"), absf(sin(_t * 8.0)) * 0.5)
	if game.state != game.State.PLAYING:
		return
	if global_position.x - game.gun.global_position.x > Config.BOSS_WAKE:
		return # todavía lejos
	match state:
		"wait":
			_cd -= delta
			if _cd <= 0.0:
				_rise()
		"up":
			_cd -= delta
			if not _threw and _cd < Config.MOLE_UP_TIME - 0.5:
				_threw = true
				_throw()
			if _cd <= 0.0:
				_sink(0.0)


func _rise() -> void:
	var options := []
	for i in HOLES.size():
		if i != hole:
			options.append(i)
	hole = options.pick_random()
	state = "rising"
	_threw = false
	_body.position = Vector3(HOLES[hole], HIDDEN_Y, 0)
	_body.visible = true
	_body.collision_layer = Config.L_ENEMY
	var tw := create_tween()
	tw.tween_property(_body, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if state == "rising":
			state = "up"
			_cd = Config.MOLE_UP_TIME)
	if game.sfx:
		game.sfx.play("boing", -6.0, 0.6)


func _sink(delay: float) -> void:
	state = "sinking"
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(_body, "position:y", HIDDEN_Y, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if not alive:
			return
		state = "wait"
		_body.visible = false
		_body.collision_layer = 0
		_cd = Config.MOLE_HIDDEN_TIME)


## Te tira una piedra en arco hacia donde estás.
func _throw() -> void:
	var from := _body.to_global(Vector3(-0.6, 2.6, 0))
	var to: Vector3 = game.gun.global_position
	var t := clampf(absf(to.x - from.x) / 9.0, 0.5, 1.4) # tiempo de vuelo
	var vx := (to.x - from.x) / t
	var vy := (to.y - from.y) / t + 0.5 * BossShot.GRAVITY * t
	game.boss_shoot("rock", from, Vector3(vx, vy, 0))


func _die() -> void:
	alive = false
	state = "dead"
	_body.set_deferred("collision_layer", 0)
	_field.open()
	if game:
		game.explosion_fx(nose_position())
	var tw := create_tween()
	tw.tween_property(_body, "position:y", 1.2, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_body, "rotation:z", -1.5, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_body, "position:y", -0.4, 0.6)
	tw.tween_interval(1.5)
	tw.tween_callback(queue_free)


func _build_mesh() -> void:
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color("6b4a35")
	fur.roughness = 0.9
	var belly := StandardMaterial3D.new()
	belly.albedo_color = Color("a8825f")
	var black := StandardMaterial3D.new()
	black.albedo_color = Color("140c0a")
	var pink := StandardMaterial3D.new()
	pink.albedo_color = Color("ff9fb0")
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 1.0
	bm.height = 3.6
	bm.material = fur
	body.mesh = bm
	body.position.y = 1.0
	_body.add_child(body)
	var tummy := MeshInstance3D.new()
	var tm := SphereMesh.new()
	tm.radius = 0.7
	tm.height = 1.8
	tm.material = belly
	tummy.mesh = tm
	tummy.position = Vector3(-0.45, 0.9, 0.3)
	_body.add_child(tummy)
	var snout := MeshInstance3D.new() # hocico
	var sm := SphereMesh.new()
	sm.radius = 0.45
	sm.height = 0.7
	sm.material = belly
	snout.mesh = sm
	snout.position = Vector3(-0.65, 1.95, 0)
	_body.add_child(snout)
	var nose := MeshInstance3D.new() # nariz: el punto débil
	var nm := SphereMesh.new()
	nm.radius = NOSE_R
	nm.height = NOSE_R * 2.0
	_nose_mat = StandardMaterial3D.new()
	_nose_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_nose_mat.albedo_color = Color("ff2a3a")
	nm.material = _nose_mat
	nose.mesh = nm
	nose.position = NOSE
	_body.add_child(nose)
	for z in [0.35, -0.35]: # ojitos
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.11
		em.height = 0.22
		em.material = black
		eye.mesh = em
		eye.position = Vector3(-0.55, 2.45, z + 0.2)
		_body.add_child(eye)
	for z in [0.75, -0.75]: # garras
		var paw := MeshInstance3D.new()
		var pm := SphereMesh.new()
		pm.radius = 0.32
		pm.height = 0.4
		pm.material = pink
		paw.mesh = pm
		paw.position = Vector3(-0.85, 0.9, z)
		_body.add_child(paw)
