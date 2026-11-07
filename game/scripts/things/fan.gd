class_name Fan
extends Node3D
## Ventilador en el piso: una columna de viento que te sube hasta la altura donde
## empiezan los cohetes (ROCKET_ALT sobre el piso). La velocidad de subida baja a
## medida que te acercás al tope, así llegás justo ahí y no te pasás.

var game: Node
var _area: Area3D
var _blades: Node3D
var _top := 0.0 # altura global del tope de la columna


func _ready() -> void:
	_top = global_position.y + Config.ROCKET_ALT
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("3a3f4a")
	dark.metallic = 0.6
	dark.roughness = 0.35
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color("4dd2ff")
	var base := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = Config.FAN_WIDTH / 2.0
	cm.bottom_radius = Config.FAN_WIDTH / 2.0 + 0.1
	cm.height = 0.3
	cm.material = dark
	base.mesh = cm
	base.position.y = 0.15
	add_child(base)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = Config.FAN_WIDTH / 2.0 - 0.08
	tm.outer_radius = Config.FAN_WIDTH / 2.0 + 0.05
	tm.material = accent
	ring.mesh = tm
	ring.position.y = 0.32
	add_child(ring)
	_blades = Node3D.new()
	_blades.position.y = 0.36
	add_child(_blades)
	for i in 4:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(Config.FAN_WIDTH * 0.45, 0.04, 0.22)
		bm.material = dark
		b.mesh = bm
		b.position = Vector3(cos(i * PI / 2.0), 0, sin(i * PI / 2.0)) * Config.FAN_WIDTH * 0.22
		b.rotation.y = -i * PI / 2.0
		b.rotation.x = 0.35
		_blades.add_child(b)

	# Viento: rayitas que suben
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 2.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(Config.FAN_WIDTH * 0.4, 0.1, 0.5)
	p.direction = Vector3.UP
	p.spread = 3.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 9.0
	p.initial_velocity_max = 14.0
	var q := BoxMesh.new()
	q.size = Vector3(0.04, 0.9, 0.04)
	var wm := StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.albedo_color = Color(1, 1, 1, 0.55)
	q.material = wm
	p.mesh = q
	p.position.y = 0.5
	add_child(p)

	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = Config.L_GUN
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(Config.FAN_WIDTH, Config.ROCKET_ALT, 1.6)
	cs.shape = bs
	cs.position.y = Config.ROCKET_ALT / 2.0
	_area.add_child(cs)
	add_child(_area)


func _physics_process(delta: float) -> void:
	_blades.rotation.y += delta * 18.0
	if game == null or game.state != game.State.PLAYING:
		return
	var gun: Gun = game.gun
	if not _area.overlaps_body(gun):
		return
	# Velocidad para que el punto más alto del vuelo sea justo el tope.
	var left := maxf(_top - gun.global_position.y, 0.0)
	var vy := minf(Config.FAN_MAX_SPEED, sqrt(2.0 * Tuning.values.gravity * left))
	gun.updraft(vy, global_position.x)
	game.fan_ride = 0.15
