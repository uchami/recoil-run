class_name Flyer
extends Area3D
## Bichos voladores.
##   bat  - revolotea en el lugar; si lo tocás se muere y te saca 1 bala.
##   hawk - cuando te ve, toma tu posición y va lento en línea recta hacia ahí.
##          Si te toca te saca 1 bala y te hace girar; después sigue de largo.

var kind := "bat"
var game: Node
var alive := true
var _anchor := Vector3.ZERO
var _t := randf() * TAU
var _vis: Node3D
var _wings: Array[Node3D] = []
var _dir := Vector3.ZERO # halcón: dirección de ataque (cero = esperando)
var _hit_done := false
var _fall_v := 0.0
var _life := 0.0


func _ready() -> void:
	collision_layer = Config.L_FLYER
	collision_mask = Config.L_GUN
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.38 if kind == "bat" else 0.5
	cs.shape = sh
	add_child(cs)
	_anchor = global_position
	_build_mesh()
	body_entered.connect(_on_body)


func shot(_hit: Dictionary, _dir_b: Vector2) -> Dictionary:
	if not alive:
		return {"result": "none", "reward": 0}
	_die()
	return {"result": "flyer_kill", "reward": Config.FLYER_REWARD}


func _die() -> void:
	alive = false
	set_deferred("monitoring", false)
	set_deferred("collision_layer", 0)
	_vis.rotation.z = PI # panza arriba
	get_tree().create_timer(3.0).timeout.connect(queue_free)


func _on_body(body: Node) -> void:
	if not alive or not body is Gun or game == null:
		return
	if kind == "bat":
		game.hurt(1, global_position, Vector2.ZERO, 0.0, "bat")
		_die()
	elif not _hit_done:
		_hit_done = true
		var spin := Config.HAWK_SPIN * (1.0 if randf() < 0.5 else -1.0)
		game.hurt(1, global_position, Vector2(_dir.x, _dir.y) * 3.0, spin, "hawk")


func _physics_process(delta: float) -> void:
	_t += delta
	for i in _wings.size():
		# Alas en V que suben y bajan (vistas de costado se lee el aleteo).
		var lift := 0.55 + sin(_t * (22.0 if kind == "bat" else 9.0)) * 0.55
		_wings[i].rotation.x = lift * (1.0 if i == 0 else -1.0)
	if not alive:
		_fall_v += Tuning.values.gravity * delta
		global_position.y -= _fall_v * delta
		return
	if kind == "bat":
		global_position = _anchor + Vector3(sin(_t * 1.3) * 1.2, sin(_t * 2.6) * 0.6, 0.0)
		return
	# halcón
	if _dir == Vector3.ZERO:
		global_position = _anchor + Vector3(0.0, sin(_t * 1.5) * 0.25, 0.0)
		if game and game.state == game.State.PLAYING:
			var to: Vector3 = game.gun.global_position - global_position
			if to.length() < Config.HAWK_SIGHT:
				_dir = Vector3(to.x, to.y, 0.0).normalized()
				_vis.scale.x = absf(_vis.scale.x) * (1.0 if _dir.x >= 0.0 else -1.0)
				game.sfx.play("screech", -4.0)
		return
	global_position += _dir * Config.HAWK_SPEED * delta
	_life += delta
	if _life > 14.0:
		queue_free()


func _build_mesh() -> void:
	_vis = Node3D.new()
	add_child(_vis)
	var body_c := Color("2b2233") if kind == "bat" else Color("7a4a2a")
	var mb := _mat(body_c)
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22 if kind == "bat" else 0.3
	sm.height = sm.radius * 2.0
	sm.material = mb
	body.mesh = sm
	body.scale = Vector3(1.4, 1.0, 1.0) if kind == "hawk" else Vector3.ONE
	_vis.add_child(body)
	if kind == "hawk":
		var head := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 0.17
		hm.height = 0.34
		hm.material = _mat(Color("f2efe6"))
		head.mesh = hm
		head.position = Vector3(0.38, 0.12, 0)
		_vis.add_child(head)
		var beak := MeshInstance3D.new()
		var bm := PrismMesh.new()
		bm.size = Vector3(0.12, 0.14, 0.1)
		bm.material = _mat(Color("ffc21a"))
		beak.mesh = bm
		beak.rotation.z = -PI / 2
		beak.position = Vector3(0.55, 0.1, 0)
		_vis.add_child(beak)
	else:
		for s in [-1, 1]:
			var ear := MeshInstance3D.new()
			var em := PrismMesh.new()
			em.size = Vector3(0.1, 0.16, 0.06)
			em.material = mb
			ear.mesh = em
			ear.position = Vector3(s * 0.09, 0.24, 0)
			_vis.add_child(ear)
		var eyes := _mat(Color("ffe14a"))
		eyes.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for s in [-1, 1]:
			var eye := MeshInstance3D.new()
			var e := SphereMesh.new()
			e.radius = 0.04
			e.height = 0.08
			e.material = eyes
			eye.mesh = e
			eye.position = Vector3(s * 0.08, 0.06, 0.19)
			_vis.add_child(eye)
	_vis.scale = Vector3.ONE * (1.3 if kind == "bat" else 1.4)
	if kind == "hawk":
		_vis.scale.x = -_vis.scale.x # mira hacia donde vas a venir (izquierda)
	var wing_len := 0.6 if kind == "bat" else 0.85
	var wing_mat := _mat(body_c.darkened(0.15) if kind == "bat" else Color("5c361c"))
	for s in [-1, 1]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0, 0.05, s * 0.12)
		_vis.add_child(pivot)
		var w := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.45 if kind == "hawk" else 0.35, 0.04, wing_len)
		wm.material = wing_mat
		w.mesh = wm
		w.position.z = s * wing_len / 2.0
		pivot.add_child(w)
		_wings.append(pivot)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	return m
