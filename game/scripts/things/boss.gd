class_name Boss
extends StaticBody3D
## Jefe: robot gigante que cierra el paso. Detrás tiene un campo de fuerza que
## llega hasta el cielo: hasta que no lo matás, no pasás (ni por arriba).
## Tiene 3 puntos débiles (ojo, pecho, antena): rojos, siempre latiendo. Un
## tiro a cualquiera lo rompe. En el blindaje, las balas rebotan.
## Mientras tanto te tira cohetes. Los 3 rotos: explota (+BOSS_REWARD).
## Origen: abajo al centro, mirando a la izquierda (hacia vos).

const SPOTS := {
	"eye": {"pos": Vector3(-1.3, 9.6, 0.0), "r": 0.5},
	"core": {"pos": Vector3(-2.1, 6.3, 0.0), "r": 0.62},
	"antenna": {"pos": Vector3(0.0, 12.3, 0.0), "r": 0.5},
}

var game: Node
var alive := true
var total := 3 # golpes para matarlo (lo que muestra el contador)
var cam_height := 6.5 # la cámara sube para que entre entero
var cam_right := 0.0
var broken := {} # punto -> true
var _fire_cd := 2.5
var _spot_cs := {} # punto -> CollisionShape3D
var _spot_vis := {} # punto -> MeshInstance3D (el núcleo rojo)
var _wall: ForceField
var _vis: Node3D
var _t := 0.0
var _glow: StandardMaterial3D
var _dead_mat: StandardMaterial3D


func _ready() -> void:
	collision_layer = Config.L_ENEMY
	collision_mask = 0
	_box_shape(Vector3(3.0, 4.6, 2.0), Vector3(0, 2.3, 0)) # piernas
	_box_shape(Vector3(4.0, 4.0, 2.4), Vector3(0, 6.5, 0)) # torso
	_box_shape(Vector3(2.4, 2.1, 2.0), Vector3(0, 9.55, 0)) # cabeza
	_box_shape(Vector3(0.25, 1.4, 0.25), Vector3(0, 11.3, 0)) # palo de la antena
	for k in SPOTS:
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = SPOTS[k].r
		cs.shape = sph
		cs.position = SPOTS[k].pos
		add_child(cs)
		_spot_cs[k] = cs
	# campo de fuerza detrás: no se pasa hasta matarlo
	_wall = ForceField.new()
	_wall.position = Vector3(2.8, 0, 0)
	add_child(_wall)
	_build_mesh()


func _box_shape(size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	add_child(cs)


func spot_position(k: String) -> Vector3:
	return to_global(SPOTS[k].pos)


func shot(hit: Dictionary, _dir: Vector2) -> Dictionary:
	if not alive:
		return {"result": "none", "reward": 0}
	var part: Object = shape_owner_get_owner(shape_find_owner(hit.get("shape", 0)))
	var spot := ""
	for k in _spot_cs:
		if _spot_cs[k] == part:
			spot = k
	if spot == "" or broken.has(spot):
		return {"result": "blocked", "reward": 0}
	_break(spot)
	if broken.size() < SPOTS.size():
		return {"result": "boss_hit", "reward": 0, "left": SPOTS.size() - broken.size()}
	_die()
	return {"result": "boss_kill", "reward": Config.BOSS_REWARD}


func _physics_process(delta: float) -> void:
	_t += delta
	if not alive:
		return
	_vis.rotation.z = sin(_t * 1.3) * 0.015 # respira
	for k in _spot_vis: # los sanos laten
		if not broken.has(k):
			(_spot_vis[k] as Node3D).scale = Vector3.ONE * (1.0 + absf(sin(_t * 6.0)) * 0.18)
	if game == null or game.state != game.State.PLAYING:
		return
	var gun_x: float = game.gun.global_position.x
	if global_position.x - gun_x > Config.BOSS_WAKE:
		return # todavía lejos: dormido
	# te tira cohetes
	_fire_cd -= delta
	if _fire_cd <= 0.0:
		_fire_cd = Config.BOSS_FIRE_EVERY
		game.boss_rocket(to_global(Vector3(-2.6, 7.4, 0.0)))


func _break(k: String) -> void:
	broken[k] = true
	var core: MeshInstance3D = _spot_vis[k]
	core.scale = Vector3.ONE
	core.material_override = _dead_mat
	if game:
		game.explosion_fx(spot_position(k))


func _die() -> void:
	alive = false
	set_deferred("collision_layer", 0)
	_wall.open()
	if game:
		for i in 4:
			get_tree().create_timer(0.18 * i).timeout.connect(func():
				if is_instance_valid(self):
					game.explosion_fx(global_position + Vector3(randf_range(-2.0, 2.0), randf_range(2.0, 11.0), 0.5)))
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(_vis, "rotation:z", -1.4, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_vis, "position:y", -3.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(1.0)
	tw.tween_callback(queue_free)


func _build_mesh() -> void:
	_vis = Node3D.new()
	add_child(_vis)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("8e9ab0")
	steel.metallic = 0.75
	steel.roughness = 0.3
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("3a3f4a")
	dark.metallic = 0.6
	dark.roughness = 0.4
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color("ffb21a")
	_glow = StandardMaterial3D.new()
	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow.albedo_color = Color("ff2a3a")
	_dead_mat = StandardMaterial3D.new()
	_dead_mat.albedo_color = Color("1a1a20")
	_box(Vector3(1.1, 4.6, 1.2), Vector3(-0.8, 2.3, 0.4), dark) # piernas
	_box(Vector3(1.1, 4.6, 1.2), Vector3(0.8, 2.3, -0.4), dark)
	_box(Vector3(1.6, 0.5, 1.6), Vector3(-0.9, 0.25, 0.4), accent) # pies
	_box(Vector3(1.6, 0.5, 1.6), Vector3(0.7, 0.25, -0.4), accent)
	_box(Vector3(4.0, 4.0, 2.4), Vector3(0, 6.5, 0), steel) # torso
	_box(Vector3(4.1, 0.35, 2.5), Vector3(0, 8.3, 0), accent) # franja
	_box(Vector3(0.9, 3.2, 0.9), Vector3(-0.6, 6.3, 1.65), dark) # brazo (el que tira cohetes)
	_box(Vector3(1.6, 0.9, 1.0), Vector3(-2.0, 7.4, 1.65), dark) # cañón del brazo
	_box(Vector3(0.9, 3.2, 0.9), Vector3(0.4, 6.3, -1.65), dark)
	_box(Vector3(2.4, 2.1, 2.0), Vector3(0, 9.55, 0), steel) # cabeza
	_box(Vector3(0.25, 1.4, 0.25), Vector3(0, 11.3, 0), dark) # antena
	for k in SPOTS:
		var core := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = SPOTS[k].r
		sm.height = SPOTS[k].r * 2.0
		sm.material = _glow
		core.mesh = sm
		core.position = SPOTS[k].pos
		_vis.add_child(core)
		var ring := MeshInstance3D.new() # aro naranja alrededor: se ve que es un blanco
		var tm := TorusMesh.new()
		tm.inner_radius = SPOTS[k].r + 0.05
		tm.outer_radius = SPOTS[k].r + 0.22
		tm.material = accent
		ring.mesh = tm
		ring.rotation.x = PI / 2.0
		ring.position = SPOTS[k].pos
		_vis.add_child(ring)
		_spot_vis[k] = core


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	_vis.add_child(mi)
	return mi
