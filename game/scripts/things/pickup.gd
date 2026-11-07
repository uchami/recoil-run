class_name Pickup
extends RigidBody3D
## Bala suelta: +1 al tocarla con el arma (flotando en el nivel aéreo, o cayendo).
## floating = quieta en el aire (si no, cae y rebota en el piso).

const MAGNET_DIST := 1.6

var kind := "ammo"
var floating := false
var game: Node
var taken := false
var _area: Area3D
var _vis: Node3D
var _t := randf() * TAU
var _life := 0.0


func _ready() -> void:
	collision_layer = Config.L_PICKUP
	collision_mask = Config.L_TERRAIN
	mass = 0.2
	lock_rotation = true
	axis_lock_linear_z = true
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.4
	pm.friction = 0.8
	physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.14
	cs.shape = sh
	add_child(cs)
	freeze = floating
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC

	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = Config.L_GUN
	var acs := CollisionShape3D.new()
	var ash := SphereShape3D.new()
	ash.radius = 0.55
	acs.shape = ash
	_area.add_child(acs)
	add_child(_area)
	_area.body_entered.connect(_on_body)
	_build_mesh()


func _on_body(body: Node) -> void:
	if body is Gun and not taken and game:
		taken = true
		game.collect(self)
		queue_free()


func _process(delta: float) -> void:
	_t += delta
	_vis.rotation.y += delta * 3.0
	if floating:
		_vis.position.y = sin(_t * 2.5) * 0.12
	else:
		_life += delta
		if _life > Config.PICKUP_LIFE:
			queue_free()
		elif _life > Config.PICKUP_LIFE - 3.0:
			_vis.visible = fmod(_life, 0.25) < 0.15 # titila antes de desaparecer
	if game and not taken:
		var gun: Node3D = game.gun
		if gun.global_position.distance_to(global_position) < MAGNET_DIST:
			freeze = true
			global_position = global_position.lerp(gun.global_position, 1.0 - exp(-delta * 10.0))


func _build_mesh() -> void:
	_vis = Node3D.new()
	add_child(_vis)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color("ffc93a")
	brass.metallic = 0.8
	brass.roughness = 0.3
	brass.emission_enabled = true
	brass.emission = Color("ffb000")
	brass.emission_energy_multiplier = 0.4
	var tip := StandardMaterial3D.new()
	tip.albedo_color = Color("d9773a")
	tip.metallic = 0.6
	var c := CylinderMesh.new()
	c.top_radius = 0.07
	c.bottom_radius = 0.07
	c.height = 0.22
	c.material = brass
	var body := MeshInstance3D.new()
	body.mesh = c
	_vis.add_child(body)
	var t := CylinderMesh.new()
	t.top_radius = 0.0
	t.bottom_radius = 0.07
	t.height = 0.12
	t.material = tip
	var tipm := MeshInstance3D.new()
	tipm.mesh = t
	tipm.position.y = 0.17
	_vis.add_child(tipm)
	_vis.scale = Vector3.ONE * 1.3
