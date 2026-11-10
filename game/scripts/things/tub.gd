class_name Tub
extends StaticBody3D
## Bañadera con billetes: el mercado. Si el arma se queda adentro más de
## MARKET_STAY segundos, se abre el mercado (una sola vez por bañadera).
## Es piso: el arma choca con el fondo y los bordes, y no rebota (billetes).
## Origen: abajo al centro, apoyada en el piso.

const WALL := 0.16
const BILLS := 0.3 # colchón de billetes: el arma queda apoyada encima (se ve)

var game: Node
var used := false
var _inside: Area3D
var _stay := 0.0
var _sign: Label3D
var _bills: Node3D


func _ready() -> void:
	collision_layer = Config.L_TERRAIN
	collision_mask = 0
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	pm.bounce = 1.0
	pm.absorbent = true # los billetes amortiguan: el arma no rebota
	physics_material_override = pm
	var sz := Config.TUB_SIZE
	var feet := 0.18
	_shape(Vector3(sz.x, WALL + BILLS, sz.z), Vector3(0, feet + (WALL + BILLS) / 2.0, 0)) # fondo (con los billetes)
	for sx in [-1, 1]: # bordes izquierdo y derecho (los que importan en el plano)
		_shape(Vector3(WALL, sz.y, sz.z), Vector3(sx * (sz.x - WALL) / 2.0, feet + sz.y / 2.0, 0))

	_inside = Area3D.new()
	_inside.collision_layer = 0
	_inside.collision_mask = Config.L_GUN
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(sz.x - WALL * 2.0, sz.y, sz.z)
	cs.shape = bs
	cs.position.y = feet + WALL + sz.y / 2.0
	_inside.add_child(cs)
	add_child(_inside)
	_build_mesh(feet)


func _shape(size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	add_child(cs)


func _physics_process(delta: float) -> void:
	if used or game == null:
		return
	_bills.rotation.y = sin(Time.get_ticks_msec() / 600.0) * 0.04
	if game.state != game.State.PLAYING or not _inside.overlaps_body(game.gun):
		_stay = 0.0
		return
	_stay += delta
	if _stay >= Config.MARKET_STAY:
		used = true
		_sign.text = "CERRADO"
		_sign.modulate = Color(1, 1, 1, 0.5)
		game.enter_market(self)


func _build_mesh(feet: float) -> void:
	var sz := Config.TUB_SIZE
	var enamel := StandardMaterial3D.new()
	enamel.albedo_color = Color("f6f3ff")
	enamel.roughness = 0.25
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("ffcf3a")
	gold.metallic = 0.7
	gold.roughness = 0.3
	_box(Vector3(sz.x, WALL, sz.z), Vector3(0, feet + WALL / 2.0, 0), enamel)
	for sx in [-1, 1]:
		_box(Vector3(WALL, sz.y, sz.z), Vector3(sx * (sz.x - WALL) / 2.0, feet + sz.y / 2.0, 0), enamel)
	for sz_side in [-1, 1]: # la de adelante (hacia la cámara) más baja: se ve el arma adentro
		var h := sz.y if sz_side < 0 else WALL + 0.12
		_box(Vector3(sz.x, h, WALL), Vector3(0, feet + h / 2.0, sz_side * (sz.z - WALL) / 2.0), enamel)
	# borde redondeado arriba
	for sx in [-1, 1]:
		var rim := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.12
		cm.bottom_radius = 0.12
		cm.height = sz.z
		cm.material = enamel
		rim.mesh = cm
		rim.rotation.x = PI / 2.0
		rim.position = Vector3(sx * (sz.x - WALL) / 2.0, feet + sz.y, 0)
		add_child(rim)
	# patas doradas
	for sx in [-1, 1]:
		for zz in [-1, 1]:
			var foot := MeshInstance3D.new()
			var fm := SphereMesh.new()
			fm.radius = feet
			fm.height = feet * 2.0
			fm.material = gold
			foot.mesh = fm
			foot.position = Vector3(sx * (sz.x / 2.0 - 0.35), feet, zz * (sz.z / 2.0 - 0.3))
			add_child(foot)
	# billetes: un montón verde asomando
	_bills = Node3D.new()
	add_child(_bills)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var greens := [Color("4caf50"), Color("66c86a"), Color("3d8f40")]
	for i in 34:
		var m := StandardMaterial3D.new()
		m.albedo_color = greens[i % greens.size()]
		m.roughness = 0.8
		var bill := _box(Vector3(0.62, 0.03, 0.3), Vector3(rng.randf_range(-sz.x / 2.0 + 0.4, sz.x / 2.0 - 0.4), feet + WALL + rng.randf_range(0.08, BILLS + 0.06), rng.randf_range(-sz.z / 2.0 + 0.3, sz.z / 2.0 - 0.3)), m)
		bill.rotation = Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(0, TAU), rng.randf_range(-0.35, 0.35))
		bill.reparent(_bills)
	_sign = Label3D.new()
	_sign.font = load("res://assets/LilitaOne-Regular.ttf")
	_sign.text = "$ MERCADO $"
	_sign.font_size = 110
	_sign.pixel_size = 0.006
	_sign.outline_size = 22
	_sign.outline_modulate = Color("2a1838")
	_sign.modulate = Color("7dff6b")
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.no_depth_test = true
	_sign.position = Vector3(0, feet + sz.y + 1.1, 0)
	add_child(_sign)


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	add_child(mi)
	return mi
