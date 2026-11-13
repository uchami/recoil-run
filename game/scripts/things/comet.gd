class_name Comet
extends Area3D
## Cometa dorado, la "estrella fugaz" (solo en el espacio): cada tanto cruza la
## pantalla rápido, en diagonal, y vuelve: pasa 2 veces (ida de derecha a
## izquierda y vuelta de izquierda a derecha). Antes de cada pasada espera un
## ratito afuera de la pantalla y una flecha dorada en el borde avisa por dónde
## viene. Si le pegás: +COMET_REWARD balas y un poder del espacio. No te hace nada:
## es un premio. Se mueve relativo a vos (cruza la pantalla aunque vayas rápido).

const R := 0.5 # radio para pegarle
const MAX_LIFE := 12.0 # por las dudas

enum Phase { WARN, GO, TURN, BACK }

var game: Node
var alive := true
var phase := Phase.WARN
var rel_vel := Vector3(-11.0, -3.5, 0.0) # velocidad respecto del arma
var passes := 0 # pasadas que empezó (1 = ida, 2 = vuelta)
var _wait := Config.COMET_WARN
var _life := MAX_LIFE
var _t := 0.0
var _vis: Node3D
var _glow_mat: StandardMaterial3D


func _ready() -> void:
	collision_layer = Config.L_FLYER
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = R
	cs.shape = sph
	add_child(cs)
	_build_mesh()


func shot(_hit: Dictionary, _dir: Vector2) -> Dictionary:
	if not alive:
		return {"result": "none", "reward": 0}
	alive = false
	set_deferred("collision_layer", 0)
	var tw := create_tween()
	tw.tween_property(_vis, "scale", Vector3.ONE * 2.5, 0.15)
	tw.parallel().tween_property(_glow_mat, "albedo_color:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
	return {"result": "comet", "reward": Config.COMET_REWARD}


func _physics_process(delta: float) -> void:
	_t += delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if not alive:
		return
	var follow := Vector3.ZERO
	if game != null and not game.gun.freeze:
		follow = game.gun.linear_velocity
		follow.z = 0.0
	var moving := phase == Phase.GO or phase == Phase.BACK
	global_position += (follow + (rel_vel if moving else Vector3.ZERO)) * delta
	var rel_x: float = global_position.x - game.gun.global_position.x if game != null else 0.0
	match phase:
		Phase.WARN, Phase.TURN: # esperando afuera, con la flecha
			_wait -= delta
			if _wait <= 0.0:
				phase = Phase.GO if phase == Phase.WARN else Phase.BACK
				passes += 1
				if phase == Phase.BACK and game != null:
					game.sfx.play("screech", -8.0, 2.1)
		Phase.GO:
			if rel_x < -Config.COMET_TURN_X:
				_turn()
		Phase.BACK:
			if rel_x > Config.COMET_TURN_X:
				queue_free()
				return
	_vis.rotation.z = atan2(rel_vel.y, rel_vel.x) + PI # la cola para atrás
	_glow_mat.albedo_color.a = 0.45 + absf(sin(_t * 14.0)) * 0.25


## Pasó de largo: espera afuera (atrás tuyo) y vuelve por otra diagonal.
func _turn() -> void:
	phase = Phase.TURN
	_wait = Config.COMET_TURN
	if game != null: # vuelve a una altura que se vea
		global_position.y = game.gun.global_position.y + randf_range(-1.0, 1.5)
	rel_vel = Vector3(randf_range(Config.COMET_SPEED.x, Config.COMET_SPEED.y), randf_range(1.0, 2.5), 0.0)


## ¿Viene hacia la pantalla? (para la flecha del borde)
func incoming() -> bool:
	if not alive:
		return false
	match phase:
		Phase.WARN, Phase.TURN:
			return true
		Phase.GO:
			return game == null or global_position.x > game.gun.global_position.x
		_:
			return game == null or global_position.x < game.gun.global_position.x


func _build_mesh() -> void:
	_vis = Node3D.new()
	add_child(_vis)
	var core := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.32
	cm.height = 0.64
	var gold := StandardMaterial3D.new()
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold.albedo_color = Color("fff3a6")
	cm.material = gold
	core.mesh = cm
	_vis.add_child(core)
	var glow := MeshInstance3D.new()
	var gm := SphereMesh.new()
	gm.radius = 0.62
	gm.height = 1.24
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_mat.albedo_color = Color(1.0, 0.75, 0.2, 0.6)
	gm.material = _glow_mat
	glow.mesh = gm
	_vis.add_child(glow)
	# cola: conos dorados que se afinan hacia atrás (eje +x local = atrás)
	for i in 3:
		var tail := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.0
		tm.bottom_radius = 0.42 - i * 0.1
		tm.height = 2.6 - i * 0.5
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = [Color(1.0, 0.6, 0.15, 0.35), Color(1.0, 0.8, 0.3, 0.4), Color(1.0, 0.95, 0.7, 0.5)][i]
		tm.material = mat
		tail.mesh = tm
		tail.rotation.z = -PI / 2.0 # el cono apunta a +x
		tail.position.x = (2.6 - i * 0.5) / 2.0 + 0.1
		_vis.add_child(tail)
