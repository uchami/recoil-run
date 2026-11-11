class_name Drone
extends Node3D
## Poder del espacio "dron": un dronecito que da vueltas alrededor del arma y le
## dispara solo al enemigo más cercano que esté en pantalla (a la cabeza si
## tiene). Sus balas no gastan las tuyas ni te empujan. Dura lo que dura el poder.

const ORBIT := Vector2(1.3, 0.9) # radio de la vuelta (x, y)
const RANGE := 12.0

var game: Node
var _t := 0.0
var _cd := 0.4
var _rotors: Array[Node3D] = []


func _ready() -> void:
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color("3a3f4a")
	body_mat.metallic = 0.6
	var light := StandardMaterial3D.new()
	light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light.albedo_color = Color("4fd8ff")
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.36, 0.12, 0.36)
	bm.material = body_mat
	body.mesh = bm
	add_child(body)
	var eye := MeshInstance3D.new()
	var em := SphereMesh.new()
	em.radius = 0.07
	em.height = 0.14
	em.material = light
	eye.mesh = em
	eye.position = Vector3(0.0, -0.06, 0.18)
	add_child(eye)
	for p in [Vector3(0.25, 0.08, 0.25), Vector3(-0.25, 0.08, 0.25), Vector3(0.25, 0.08, -0.25), Vector3(-0.25, 0.08, -0.25)]:
		var r := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.14
		rm.bottom_radius = 0.14
		rm.height = 0.02
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(0.85, 0.9, 1.0, 0.6)
		rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.material = rmat
		r.mesh = rm
		r.position = p
		add_child(r)
		_rotors.append(r)


func _physics_process(delta: float) -> void:
	_t += delta
	if game == null:
		return
	var gp: Vector3 = game.gun.global_position
	global_position = gp + Vector3(cos(_t * 2.4) * ORBIT.x, 0.8 + sin(_t * 2.4) * ORBIT.y * 0.5, 0.4)
	for r in _rotors:
		r.rotation.y += delta * 30.0
	if game.state != game.State.PLAYING:
		return
	_cd -= delta
	if _cd > 0.0:
		return
	var target := find_target()
	if target == Vector3.INF:
		return
	_cd = Config.DRONE_FIRE_EVERY
	game.drone_fire(global_position, target)


## Adónde tirarle: el enemigo vivo más cercano, en pantalla y a menos de RANGE
## (a la cabeza / cúpula si tiene). Vector3.INF si no hay ninguno.
func find_target() -> Vector3:
	var best := Vector3.INF
	var best_d := RANGE
	for list in [game.enemies, game.entities]:
		for n in list:
			if not is_instance_valid(n) or not n.get("alive"):
				continue
			if not (n is Enemy or n is Flyer or n is Ufo or n is Astronaut or n is Rocket or n is Airplane):
				continue
			var aim: Vector3 = (n as Node3D).global_position
			if n is Enemy:
				aim += Vector3(0, Enemy.HEAD_Y, 0)
			elif n is Ufo:
				aim = n.dome_position()
			elif n is Astronaut:
				aim = (n as Node3D).to_global(Vector3(0, Astronaut.HEAD_Y, 0))
			var d := aim.distance_to(global_position)
			if d < best_d and game.on_screen(aim):
				best_d = d
				best = aim
	return best
