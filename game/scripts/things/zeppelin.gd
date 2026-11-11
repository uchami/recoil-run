class_name Zeppelin
extends Node3D
## Jefe zepelín blindado: flota arriba de la arena, va y viene y te tira bombas.
## Tiene 4 bolsas de gas rojas (arriba, abajo, adelante y atrás): un tiro a una
## la pincha y el zepelín baja un poco. En el casco la bala rebota. Las 4
## pinchadas: se cae y explota. Detrás, un campo de fuerza.
## Origen: el piso, en el medio de la arena.

const BAGS := {
	"front": {"pos": Vector3(-3.9, 0.2, 0.0), "r": 0.6},
	"top": {"pos": Vector3(-0.8, 1.75, 0.0), "r": 0.6},
	"bottom": {"pos": Vector3(1.4, -1.65, 0.0), "r": 0.55},
	"back": {"pos": Vector3(3.9, 0.6, 0.0), "r": 0.6},
}
const FIELD_X := 12.0
const PATROL := 4.0 # va y viene esto a cada lado

var game: Node
var alive := true
var total := 4
var cam_height := 10.0
var cam_right := PATROL + 4.5 # (que entre entero aunque esté en la punta de su recorrido)
var popped := {} # bolsa -> true
var _ship: Node3D
var _body: StaticBody3D
var _bag_cs := {}
var _bag_vis := {}
var _field: ForceField
var _t := 0.0
var _bomb_cd := 1.5
var _alt := 0.0
var _fall_v := 0.0


func _ready() -> void:
	_alt = Config.ZEP_ALT
	_field = ForceField.new()
	_field.position = Vector3(FIELD_X, 0, 0)
	add_child(_field)
	_ship = Node3D.new()
	_ship.position.y = _alt
	add_child(_ship)
	_body = StaticBody3D.new()
	_body.collision_layer = Config.L_ENEMY
	_body.collision_mask = 0
	_body.set_meta("boss", self)
	_ship.add_child(_body)
	var hull := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.35
	cap.height = 7.4
	hull.shape = cap
	hull.rotation.z = PI / 2.0
	_body.add_child(hull)
	var gondola := CollisionShape3D.new()
	var gb := BoxShape3D.new()
	gb.size = Vector3(2.2, 0.7, 1.0)
	gondola.shape = gb
	gondola.position = Vector3(-0.6, -1.65, 0)
	_body.add_child(gondola)
	for k in BAGS:
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = BAGS[k].r
		cs.shape = sph
		cs.position = BAGS[k].pos
		_body.add_child(cs)
		_bag_cs[k] = cs
	_build_mesh()


func bag_position(k: String) -> Vector3:
	return _ship.to_global(BAGS[k].pos)


func ship_position() -> Vector3:
	return _ship.global_position


func shot(hit: Dictionary, _dir: Vector2) -> Dictionary:
	if not alive:
		return {"result": "none", "reward": 0}
	var part: Object = _body.shape_owner_get_owner(_body.shape_find_owner(hit.get("shape", 0)))
	var bag := ""
	for k in _bag_cs:
		if _bag_cs[k] == part:
			bag = k
	if bag == "" or popped.has(bag):
		return {"result": "blocked", "reward": 0}
	popped[bag] = true
	(_bag_cs[bag] as CollisionShape3D).set_deferred("disabled", true)
	(_bag_vis[bag] as Node3D).visible = false
	if game:
		game._fx_puff(bag_position(bag), Color("ff5a6a"), 16, 0.6, false)
		game.sfx.play("boing", -2.0, 1.8)
	_alt -= Config.ZEP_DROP
	if popped.size() >= total:
		_die()
		return {"result": "boss_kill", "reward": Config.BOSS_REWARD}
	return {"result": "boss_hit", "reward": 0, "left": total - popped.size()}


func _physics_process(delta: float) -> void:
	_t += delta
	if not alive:
		_fall_v += 9.0 * delta
		_ship.position.y -= _fall_v * delta
		_ship.rotation.z = lerpf(_ship.rotation.z, -0.5, delta * 2.0)
		return
	_ship.position.x = sin(_t * 0.45) * PATROL
	_ship.position.y = lerpf(_ship.position.y, _alt + sin(_t * 1.1) * 0.25, 1.0 - exp(-delta * 2.0))
	_ship.rotation.z = sin(_t * 0.7) * 0.04
	if game == null or game.state != game.State.PLAYING:
		return
	var gx: float = game.gun.global_position.x
	if global_position.x - gx > Config.BOSS_WAKE:
		return
	_bomb_cd -= delta
	if _bomb_cd <= 0.0 and game.on_screen(_ship.global_position):
		_bomb_cd = Config.ZEP_BOMB_EVERY
		var from := _ship.to_global(Vector3(-0.6, -2.1, 0))
		# la tira con algo de puntería: un poco hacia donde estás
		var vx := clampf((gx - from.x) * 0.5, -4.0, 4.0)
		game.boss_shoot("bomb", from, Vector3(vx, 0.0, 0))


func _die() -> void:
	alive = false
	_body.set_deferred("collision_layer", 0)
	_field.open()
	if game:
		for i in 4:
			get_tree().create_timer(0.25 * i).timeout.connect(func():
				if is_instance_valid(self):
					game.explosion_fx(_ship.global_position + Vector3(randf_range(-3.0, 3.0), randf_range(-1.0, 1.0), 0.6)))
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_callback(queue_free)


func _build_mesh() -> void:
	var canvas := StandardMaterial3D.new()
	canvas.albedo_color = Color("c9c3b4")
	canvas.roughness = 0.7
	var plate := StandardMaterial3D.new()
	plate.albedo_color = Color("5c6470")
	plate.metallic = 0.7
	plate.roughness = 0.35
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("ff3a4a")
	red.emission_enabled = true
	red.emission = Color("ff2a3a")
	red.emission_energy_multiplier = 0.6
	var hull := MeshInstance3D.new()
	var hm := CapsuleMesh.new()
	hm.radius = 1.35
	hm.height = 7.4
	hm.material = canvas
	hull.mesh = hm
	hull.rotation.z = PI / 2.0
	_ship.add_child(hull)
	for x in [-2.0, 0.0, 2.0]: # bandas de blindaje
		var band := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.4
		cm.bottom_radius = 1.4
		cm.height = 0.35
		cm.material = plate
		band.mesh = cm
		band.rotation.z = PI / 2.0
		band.position.x = x
		_ship.add_child(band)
	for s in [1.0, -1.0]: # aletas de cola
		var fin := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(1.2, 1.3, 0.12)
		fm.material = plate
		fin.mesh = fm
		fin.position = Vector3(3.3, s * 1.1, 0)
		_ship.add_child(fin)
	var gondola := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(2.2, 0.7, 1.0)
	gm.material = plate
	gondola.mesh = gm
	gondola.position = Vector3(-0.6, -1.65, 0)
	_ship.add_child(gondola)
	for k in BAGS:
		var bag := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = BAGS[k].r
		bm.height = BAGS[k].r * 2.0
		bm.material = red
		bag.mesh = bm
		bag.position = BAGS[k].pos + Vector3(0, 0, 0.15)
		_ship.add_child(bag)
		_bag_vis[k] = bag
