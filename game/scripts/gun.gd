class_name Gun
extends RigidBody3D
## El arma: cuerpo rígido en el plano XY (cañón hacia +X local, corredera arriba).

const SLIDE_SIZE := Vector3(0.9, 0.18, 0.14)
const SLIDE_POS := Vector3(0.0, 0.09, 0.0)
const GRIP_SIZE := Vector3(0.18, 0.38, 0.13)
const GRIP_POS := Vector3(-0.27, -0.14, 0.0)
const GRIP_ANGLE := -0.25
const MUZZLE := Vector3(0.46, 0.11, 0.0)
# Mirilla delantera (con colisión): dada vuelta, el arma se apoya en la mirilla
# y en la cola de la corredera => queda inclinada, nunca plana.
const SIGHT_SIZE := Vector3(0.05, 0.08, 0.05)
const SIGHT_POS := Vector3(0.38, 0.21, 0.0)

signal landed(speed: float) # tocó algo viniendo rápido (para el sonido)

var _pending_shot := false
var _pending_knock := false
var _knock_vel := Vector3.ZERO
var _knock_spin := 0.0
var _prev_speed := 0.0
var _glow: StandardMaterial3D
var _shot_dir := Vector2.RIGHT
var grounded := false
var _from_rest := false
var _material: PhysicsMaterial


func _ready() -> void:
	mass = 1.0
	axis_lock_linear_z = true
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	angular_damp = Config.ANGULAR_DAMP
	linear_damp = 0.05
	can_sleep = false
	collision_layer = Config.L_GUN
	collision_mask = Config.L_TERRAIN | Config.L_ENEMY
	_material = PhysicsMaterial.new()
	_material.friction = 0.6
	physics_material_override = _material
	apply_tuning()
	# Centro de masa bajo y hacia la empuñadura: el retroceso (aplicado arriba) hace levantar el cañón.
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(-0.1, -0.02, 0.0)

	_add_box_shape(SLIDE_SIZE, SLIDE_POS, 0.0)
	_add_box_shape(GRIP_SIZE, GRIP_POS, GRIP_ANGLE)
	_add_box_shape(SIGHT_SIZE, SIGHT_POS, 0.0)
	_build_mesh()


## Relee los valores del panel AJUSTES que afectan al cuerpo (rebote).
func apply_tuning() -> void:
	_material.bounce = Tuning.values.bounce


## Ángulo del cañón en el plano (rad, antihorario desde +X).
func angle() -> float:
	var x := global_transform.basis.x
	return atan2(x.y, x.x)


func barrel_dir() -> Vector2:
	var a := angle()
	return Vector2(cos(a), sin(a))


func muzzle_position() -> Vector3:
	return global_transform * MUZZLE


## Programa el retroceso para el próximo paso de física.
## from_rest: ignora la velocidad previa (primer disparo, al soltarla de la pose flotante).
func fire(from_rest := false) -> void:
	_pending_shot = true
	_from_rest = from_rest
	_shot_dir = barrel_dir()


## Empujón externo (resorte, golpe): reemplaza la velocidad y suma giro.
func knock(vel: Vector3, spin := 0.0) -> void:
	_pending_knock = true
	_knock_vel = vel
	_knock_spin = spin


## Brillo sobre el arma (poder intocable); null lo apaga.
func set_glow(color: Variant) -> void:
	if color == null:
		_set_overlay(null)
		return
	if _glow == null:
		_glow = StandardMaterial3D.new()
		_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow.albedo_color = color
	_set_overlay(_glow)


func _set_overlay(m: Material) -> void:
	for c in get_children():
		if c is MeshInstance3D:
			c.material_overlay = m


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var was_grounded := grounded
	grounded = state.get_contact_count() > 0
	if grounded and not was_grounded and _prev_speed > 2.5:
		landed.emit.call_deferred(_prev_speed)
	_prev_speed = state.linear_velocity.length()

	if _pending_knock:
		_pending_knock = false
		state.linear_velocity = _knock_vel
		state.angular_velocity = Vector3(0.0, 0.0, state.angular_velocity.z + _knock_spin)
		return

	if _pending_shot:
		_pending_shot = false
		var recoil: Vector2 = -_shot_dir * Tuning.values.recoil_speed
		if recoil.x < 0.0:
			recoil.x *= Tuning.values.backward_recoil_factor
		var v: Vector3 = Vector3.ZERO if _from_rest else state.linear_velocity * Tuning.values.velocity_keep
		var vy := v.y + recoil.y
		# Lift: todo disparo te levanta como mínimo esta velocidad, apunte donde apunte
		# el cañón (el ángulo decide sobre todo lo horizontal). Distinto en piso y aire.
		var lift: float = Tuning.values.ground_lift if grounded else Tuning.values.air_lift
		vy = maxf(vy, lift)
		state.linear_velocity = Vector3(v.x + recoil.x, vy, 0.0)
		state.angular_velocity = Vector3(0.0, 0.0, Tuning.values.spin_on_shot)
		return

	# Tope de velocidad de caída: planea en vez de desplomarse.
	if state.linear_velocity.y < -Tuning.values.max_fall_speed:
		var lv := state.linear_velocity
		state.linear_velocity = Vector3(lv.x, -Tuning.values.max_fall_speed, 0.0)


func _add_box_shape(size: Vector3, pos: Vector3, rot_z: float) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = pos
	cs.rotation.z = rot_z
	add_child(cs)


func _build_mesh() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("aab3bd")
	metal.metallic = 0.75
	metal.roughness = 0.3
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("24272c")
	dark.roughness = 0.55

	_box(SLIDE_SIZE, SLIDE_POS, 0.0, metal)
	_box(Vector3(SLIDE_SIZE.x * 0.75, 0.08, 0.12), Vector3(-0.05, -0.02, 0.0), 0.0, dark)
	_box(GRIP_SIZE, GRIP_POS, GRIP_ANGLE, dark)
	_box(SIGHT_SIZE, SIGHT_POS, 0.0, dark) # mirilla delantera
	_box(Vector3(0.06, 0.04, 0.1), Vector3(-0.39, 0.19, 0.0), 0.0, dark) # alza trasera (solo visual, más baja)
	_box(Vector3(0.14, 0.02, 0.1), Vector3(-0.08, -0.13, 0.0), 0.0, dark) # guardamonte
	_box(Vector3(0.02, 0.08, 0.1), Vector3(-0.01, -0.09, 0.0), 0.0, dark)
	for i in 5:
		_box(Vector3(0.012, SLIDE_SIZE.y * 0.8, SLIDE_SIZE.z + 0.005), Vector3(-0.38 + i * 0.035, SLIDE_POS.y, 0.0), 0.0, dark)
	var bore := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.03
	cyl.height = 0.02
	cyl.material = dark
	bore.mesh = cyl
	bore.position = MUZZLE + Vector3(0.001, 0, 0)
	bore.rotation.z = PI / 2
	add_child(bore)


func _box(size: Vector3, pos: Vector3, rot_z: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	mi.rotation.z = rot_z
	add_child(mi)
