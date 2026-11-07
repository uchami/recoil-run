class_name Booster
extends Node3D
## Cohete propulsor parado en el piso. Si lo tocás te agarra, despega derecho
## para arriba y te suelta en el espacio (BOOSTER_DROP_ALT sobre el piso).

var game: Node
var launched := false
var _area: Area3D
var _vis: Node3D
var _flame: Node3D
var _drop_y := 0.0
var _released := false
var _t := 0.0
var _smoke: CPUParticles3D


func _ready() -> void:
	_drop_y = global_position.y + Config.BOOSTER_DROP_ALT
	_vis = Node3D.new()
	add_child(_vis)
	var white := _mat(Color("f4f1ea"))
	var red := _mat(Color("e8384f"))
	var dark := _mat(Color("2a2f38"))
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.55
	cm.bottom_radius = 0.6
	cm.height = 3.0
	cm.material = white
	body.mesh = cm
	body.position.y = 1.9
	_vis.add_child(body)
	var nose := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.0
	nm.bottom_radius = 0.55
	nm.height = 1.1
	nm.material = red
	nose.mesh = nm
	nose.position.y = 3.95
	_vis.add_child(nose)
	var window := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 0.22
	wm.bottom_radius = 0.22
	wm.height = 0.1
	wm.material = _mat(Color("8fd8ff"))
	window.mesh = wm
	window.rotation.x = PI / 2.0
	window.position = Vector3(0, 2.6, 0.56)
	_vis.add_child(window)
	for i in 3:
		var fin := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.9, 1.0, 0.08)
		pm.material = red
		fin.mesh = pm
		var a := i * TAU / 3.0
		fin.position = Vector3(cos(a) * 0.6, 0.7, sin(a) * 0.6)
		fin.rotation.y = -a
		_vis.add_child(fin)
	var nozzle := MeshInstance3D.new()
	var zm := CylinderMesh.new()
	zm.top_radius = 0.4
	zm.bottom_radius = 0.5
	zm.height = 0.4
	zm.material = dark
	nozzle.mesh = zm
	nozzle.position.y = 0.2
	_vis.add_child(nozzle)
	_flame = Node3D.new()
	_flame.visible = false
	_vis.add_child(_flame)
	var fl := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.45
	fm.height = 1.8
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color("ffb21a")
	fm.material = fmat
	fl.mesh = fm
	fl.position.y = -0.7
	_flame.add_child(fl)
	_smoke = CPUParticles3D.new()
	_smoke.emitting = false
	_smoke.amount = 40
	_smoke.lifetime = 1.4
	_smoke.direction = Vector3.DOWN
	_smoke.spread = 25.0
	_smoke.initial_velocity_min = 2.0
	_smoke.initial_velocity_max = 5.0
	_smoke.gravity = Vector3.ZERO
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 1.4
	var sm := SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.6
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.85, 0.82, 0.9, 0.7)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = smat
	_smoke.mesh = sm
	_smoke.local_coords = false
	_smoke.position.y = -0.3
	_vis.add_child(_smoke)

	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = Config.L_GUN
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.8, 4.6, 1.6)
	cs.shape = bs
	cs.position.y = 2.3
	_area.add_child(cs)
	add_child(_area)
	_area.body_entered.connect(_on_body)


func _on_body(body: Node) -> void:
	if not launched and body is Gun and game and game.state == game.State.PLAYING:
		launched = true
		_flame.visible = true
		_smoke.emitting = true
		game.sfx.play("engine", 0.0, 0.8)
		game.sfx.play("explosion", -8.0, 1.4)


func _physics_process(delta: float) -> void:
	_t += delta
	if not launched:
		return
	_flame.scale = Vector3.ONE * (0.8 + absf(sin(_t * 25.0)) * 0.5)
	global_position.y += Config.BOOSTER_SPEED * delta
	if _released:
		if global_position.y > _drop_y + 60.0:
			queue_free()
		return
	var gun: Gun = game.gun
	if global_position.y + 4.6 >= _drop_y: # llegamos: te suelta
		_released = true
		gun.knock(Vector3(3.0, 5.0, 0.0), 2.0)
		game.sfx.play("boing", 0.0, 0.6)
		return
	# te lleva agarrado en la punta
	gun.hold(global_position + Vector3(0.0, 4.9, 0.0), Vector3(0.0, Config.BOOSTER_SPEED, 0.0))
	game.fan_ride = 0.15 # viaje limpio: no aparecen bichos en el camino


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	return m
