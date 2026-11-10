class_name Firefly
extends Area3D
## Lucecita del apagón: una bolita de luz que flota y titila. No es un bicho
## (no te hace nada): es un regalo. Un tiro = +FIREFLY_REWARD balas.
## Origen: el centro de la luz.

const R := 0.45 # radio para pegarle (generoso: está oscuro)

var game: Node
var alive := true
var _t := randf() * TAU
var _speed := randf_range(0.8, 1.3) # cada una titila a su ritmo
var _y0 := 0.0
var _core: MeshInstance3D
var _halo: MeshInstance3D
var _core_mat: StandardMaterial3D
var _halo_mat: StandardMaterial3D


func _ready() -> void:
	collision_layer = Config.L_FLYER
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = R
	cs.shape = sph
	add_child(cs)
	_y0 = position.y
	_build_mesh()


func shot(_hit: Dictionary, _dir: Vector2) -> Dictionary:
	if not alive:
		return {"result": "none", "reward": 0}
	alive = false
	set_deferred("collision_layer", 0)
	var tw := create_tween() # se abre en un destello y se apaga
	tw.tween_property(self, "scale", Vector3.ONE * 2.2, 0.12)
	tw.parallel().tween_property(_halo_mat, "albedo_color:a", 0.0, 0.25)
	tw.parallel().tween_property(_core_mat, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(queue_free)
	return {"result": "firefly", "reward": Config.FIREFLY_REWARD}


## Cuánto brilla ahora (0..1): casi siempre prendida, con apagones cortitos.
func glow() -> float:
	var s := sin(_t * _speed * 2.6)
	return clampf(0.25 + smoothstep(-0.6, 0.2, s) * 0.75, 0.0, 1.0)


func _process(delta: float) -> void:
	if not alive:
		return
	_t += delta
	position.y = _y0 + sin(_t * 0.9) * 0.35 # flota
	position.x += cos(_t * 0.6) * 0.25 * delta
	var g := glow()
	_core_mat.albedo_color.a = 0.35 + g * 0.65
	_halo_mat.albedo_color.a = g * 0.7
	_halo.scale = Vector3.ONE * (0.75 + g * 0.45)


func _build_mesh() -> void:
	_core = MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.16
	cm.height = 0.32
	_core_mat = StandardMaterial3D.new()
	_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_core_mat.albedo_color = Color("faff9a")
	cm.material = _core_mat
	_core.mesh = cm
	add_child(_core)
	_halo = MeshInstance3D.new() # resplandor alrededor
	var hm := SphereMesh.new()
	hm.radius = 0.55
	hm.height = 1.1
	_halo_mat = StandardMaterial3D.new()
	_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_mat.albedo_color = Color(0.8, 1.0, 0.25, 0.7)
	hm.material = _halo_mat
	_halo.mesh = hm
	add_child(_halo)
