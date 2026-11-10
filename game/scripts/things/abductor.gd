class_name Abductor
extends Node3D
## Nave nodriza que te abduce cuando llegás a un nivel especial volando muy
## alto: baja, te chupa con el rayo, te lleva y te deja a la altura del piso.
## Solo es la parte visual; la secuencia la maneja main.gd (_abduct).

var _beam: MeshInstance3D
var _beam_mat: StandardMaterial3D
var _vis: Node3D
var _t := 0.0


func _ready() -> void:
	_vis = Node3D.new()
	_vis.scale = Vector3.ONE * 1.8
	add_child(_vis)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("9aa6b4")
	metal.metallic = 0.85
	metal.roughness = 0.25
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.5, 1.0, 0.7, 0.55)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var light := StandardMaterial3D.new()
	light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light.albedo_color = Color("ffd23a")
	var saucer := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.3
	sm.height = 0.6
	sm.material = metal
	saucer.mesh = sm
	_vis.add_child(saucer)
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.6
	dm.height = 0.8
	dm.is_hemisphere = true
	dm.material = glass
	dome.mesh = dm
	dome.position.y = 0.15
	_vis.add_child(dome)
	for i in 10:
		var l := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.09
		lm.height = 0.18
		lm.material = light
		l.mesh = lm
		var a := i * TAU / 10.0
		l.position = Vector3(cos(a) * 1.12, -0.04, sin(a) * 1.12)
		_vis.add_child(l)
	# rayo: cono de luz hacia abajo
	_beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.5
	cm.bottom_radius = 1.4
	cm.height = 1.0
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_mat.albedo_color = Color(0.55, 1.0, 0.5, 0.35)
	cm.material = _beam_mat
	_beam.mesh = cm
	_beam.visible = false
	add_child(_beam)


## Prende el rayo hasta `length` metros hacia abajo (0 = apagado).
func set_beam(length: float) -> void:
	_beam.visible = length > 0.05
	_beam.scale = Vector3(1.0, maxf(length, 0.01), 1.0)
	_beam.position.y = -0.3 - length / 2.0


func _process(delta: float) -> void:
	_t += delta
	_vis.rotation.y += delta * 2.5
	_beam_mat.albedo_color.a = 0.28 + absf(sin(_t * 9.0)) * 0.12
