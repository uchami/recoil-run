class_name AmmoTag
extends Node3D
## Las balas que le quedan a algo (cofre, mimic, avión), igual que las tuyas:
## un iconito de bala y el número, siempre mirando a la cámara.

var _label: Label3D


func _ready() -> void:
	_label = Label3D.new()
	_label.font = load("res://assets/LilitaOne-Regular.ttf")
	_label.font_size = 120
	_label.pixel_size = 0.006
	_label.outline_size = 22
	_label.outline_modulate = Color("2a1838")
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.render_priority = 10
	_label.outline_render_priority = 9
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.position.x = 0.12
	add_child(_label)
	# Bala: casquillo dorado + punta cobre, parada al lado del número.
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color("ffc93a")
	brass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	brass.no_depth_test = true
	brass.render_priority = 10
	var tip := brass.duplicate() as StandardMaterial3D
	tip.albedo_color = Color("d9773a")
	var body := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.1
	c.bottom_radius = 0.1
	c.height = 0.32
	c.material = brass
	body.mesh = c
	body.position = Vector3(-0.08, -0.04, 0)
	add_child(body)
	var t := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.0
	tm.bottom_radius = 0.1
	tm.height = 0.16
	tm.material = tip
	t.mesh = tm
	t.position = Vector3(-0.08, 0.2, 0)
	add_child(t)


func set_count(n: int) -> void:
	_label.text = str(n)
	_label.modulate = Color("ff6b6b") if n <= 0 else Color.WHITE
