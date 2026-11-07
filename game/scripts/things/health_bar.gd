class_name HealthBar
extends Node3D
## Barrita de vida flotante (mira siempre a la cámara).

const WIDTH := 0.9
const HEIGHT := 0.12

var _fill: MeshInstance3D


func _ready() -> void:
	var bg := _quad(Vector2(WIDTH + 0.06, HEIGHT + 0.06), Color(0.1, 0.03, 0.15, 0.85))
	add_child(bg)
	_fill = _quad(Vector2(WIDTH, HEIGHT), Color("ff4d6d"))
	_fill.position.z = 0.01
	add_child(_fill)


func set_ratio(r: float) -> void:
	r = clampf(r, 0.0, 1.0)
	_fill.scale.x = maxf(r, 0.001)
	_fill.position.x = -WIDTH * (1.0 - r) / 2.0


func _quad(size: Vector2, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.render_priority = 10
	q.material = m
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
