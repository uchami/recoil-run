class_name Target
extends Area3D
## Diana de la galería de tiro. Escondida hasta que te acercás; ahí asoma unos
## segundos y se vuelve a esconder. Al centro: 2 puntos; al resto: 1. Cada
## acierto te devuelve la bala. Se pega de costado (las balas van en el plano),
## así que el centro se mide por lo cerca que pasó la bala del medio.
## mode: "ground" (sube desde el piso), "hang" (baja colgando), "fly" (va y viene).
## Origen: el centro de la diana cuando está a la vista.

const R := 0.75 # radio de la diana
const BULLSEYE := 0.24 # radio del centro

var game: Node
var mode := "ground"
var state := "hidden" # hidden -> up -> done
var points := 0 # lo que hizo esta diana (0 si no le pegaste)
var _t := 0.0
var _vis: Node3D
var _cs: CollisionShape3D
var _x0 := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	_cs = CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = R
	cyl.height = 0.3
	_cs.shape = cyl
	_cs.rotation.x = PI / 2.0 # disco de frente a la cámara
	add_child(_cs)
	_build_mesh()
	_x0 = position.x
	_vis.position = _hidden_offset()
	_vis.visible = false


func _hidden_offset() -> Vector3:
	match mode:
		"ground":
			return Vector3(0, -2.2, 0)
		"hang":
			return Vector3(0, 6.0, 0)
	return Vector3(0, 0, 0)


func shot(hit: Dictionary, dir: Vector2) -> Dictionary:
	if state != "up":
		return {"result": "none", "reward": 0}
	# distancia del centro a la línea de la bala
	var to_c := Vector2(global_position.x - hit.position.x, global_position.y - hit.position.y)
	var d := absf(dir.normalized().cross(to_c))
	points = 2 if d <= BULLSEYE else 1
	_hide(true)
	return {"result": "target_hit", "reward": 1, "points": points}


func _physics_process(delta: float) -> void:
	if game == null:
		return
	_t += delta
	match state:
		"hidden":
			if game.state == game.State.PLAYING and global_position.x - game.gun.global_position.x < Config.TARGET_TRIGGER:
				_pop()
		"up":
			if mode == "fly":
				position.x = _x0 + sin(_t * 2.2) * 2.0
			if _t > Config.TARGET_UP_TIME:
				_hide(false)


func _pop() -> void:
	state = "up"
	_t = 0.0
	collision_layer = Config.L_FLYER
	set_meta("seen", true) # asomó en pantalla: se le puede pegar
	_vis.visible = true
	var tw := create_tween()
	tw.tween_property(_vis, "position", Vector3.ZERO, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if game.sfx:
		game.sfx.play("boing", -10.0, 1.6)


## Se esconde: tumbada si le pegaste, o se va si no llegaste.
func _hide(hit: bool) -> void:
	state = "done"
	set_deferred("collision_layer", 0)
	var tw := create_tween()
	if hit:
		tw.tween_property(_vis, "rotation:x", -PI / 2.0, 0.18)
		tw.tween_interval(0.4)
	tw.tween_property(_vis, "position", _hidden_offset() if mode != "fly" else Vector3(0, 6.0, 0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _vis.visible = false)


func _build_mesh() -> void:
	_vis = Node3D.new()
	add_child(_vis)
	var cols := [Color("f4f1ea"), Color("e8384f"), Color("f4f1ea"), Color("e8384f")]
	var radii := [R, R * 0.74, R * 0.5, BULLSEYE]
	for i in 4:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = radii[i]
		cm.bottom_radius = radii[i]
		cm.height = 0.12 + i * 0.03
		var m := StandardMaterial3D.new()
		m.albedo_color = cols[i]
		m.roughness = 0.6
		cm.material = m
		mi.mesh = cm
		mi.rotation.x = PI / 2.0
		_vis.add_child(mi)
	var ring := MeshInstance3D.new() # aro de afuera
	var tm := TorusMesh.new()
	tm.inner_radius = R - 0.05
	tm.outer_radius = R + 0.06
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("ffcf3a")
	gold.metallic = 0.6
	gold.roughness = 0.3
	tm.material = gold
	ring.mesh = tm
	ring.rotation.x = PI / 2.0
	_vis.add_child(ring)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("a8682f")
	match mode:
		"ground": # palo hasta el piso
			_vis.add_child(_stick(Vector3(0, -1.4, -0.12), 2.0, wood))
		"hang": # soga hacia arriba
			var rope := StandardMaterial3D.new()
			rope.albedo_color = Color("f4f1ea")
			_vis.add_child(_stick(Vector3(0, 3.5, -0.12), 5.5, rope, 0.03))
		"fly": # globito que la lleva
			var b := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.4
			sm.height = 0.95
			var bm := StandardMaterial3D.new()
			bm.albedo_color = Color("4fd8ff")
			sm.material = bm
			b.mesh = sm
			b.position = Vector3(0, 1.75, -0.1)
			_vis.add_child(b)
			_vis.add_child(_stick(Vector3(0, 1.05, -0.12), 0.6, wood, 0.02))


func _stick(pos: Vector3, h: float, mat: Material, r := 0.07) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.material = mat
	mi.mesh = cm
	mi.position = pos
	return mi
