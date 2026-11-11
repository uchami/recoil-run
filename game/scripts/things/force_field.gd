class_name ForceField
extends StaticBody3D
## Campo de fuerza de los jefes: una pared celeste que llega hasta el cielo.
## No se pasa (ni por arriba) hasta que el jefe muere y lo apaga (open()).
## Origen: abajo, en el piso.

const HEIGHT := 80.0


func _ready() -> void:
	collision_layer = Config.L_TERRAIN
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.6, HEIGHT, 3.0)
	cs.shape = bs
	cs.position.y = HEIGHT / 2.0
	add_child(cs)
	var field := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.15, HEIGHT, 0.1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.4, 0.9, 1.0, 0.35)
	fm.material = mat
	field.mesh = fm
	field.position.y = HEIGHT / 2.0
	add_child(field)


## El jefe murió: se apaga (deja pasar) y se achica hasta desaparecer.
func open(delay := 0.5) -> void:
	set_deferred("collision_layer", 0)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(self, "scale", Vector3(0.01, 1.0, 1.0), 0.3)
	tw.tween_callback(func(): visible = false)
