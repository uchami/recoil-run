class_name Chaser
extends Node3D
## Persecución: un cofre trampa gigante (más alto que la pantalla) te persigue
## desde atrás, cada vez más rápido. Nunca queda a más de CHASE_MAX_GAP: si te
## frenás, te alcanza. Si su boca llega a donde estás, te come: perdés.
## front_x = dónde está su boca (lo que te alcanza).

var game: Node
var front_x := 0.0
var start_x := 0.0
var end_x := 0.0
var done := false
var _vis: Node3D
var _lid: Node3D
var _t := 0.0
var _half := 0.0


func _ready() -> void:
	_vis = Node3D.new()
	var k := Config.CHASE_HEIGHT / Chest.SIZE.y
	_vis.scale = Vector3(-k, k, k * 0.5) # mirando a la derecha (hacia vos)
	add_child(_vis)
	Chest.build_chest(_vis, true)
	_lid = _vis.get_node("Lid")
	_half = Chest.SIZE.x * k / 2.0


## Velocidad: arranca despacio y acelera hasta el final del tramo.
func speed() -> float:
	var prog := clampf((front_x - start_x) / maxf(end_x - start_x, 1.0), 0.0, 1.0)
	return lerpf(Config.CHASE_SPEED.x, Config.CHASE_SPEED.y, prog)


func _physics_process(delta: float) -> void:
	_t += delta
	_lid.rotation.z = -0.35 - absf(sin(_t * 4.0)) * 0.45 # mastica
	if game == null:
		return
	var gun: Node3D = game.gun
	var gp: Vector3 = gun.global_position
	if not done and game.state == game.State.PLAYING and not game.eaten:
		front_x = maxf(front_x + speed() * delta, gp.x - Config.CHASE_MAX_GAP)
		if front_x >= gp.x - 0.3:
			if game.eat_gun(gp):
				var tw := create_tween()
				tw.tween_property(_lid, "rotation:z", 0.0, 0.12)
	elif done:
		front_x -= 6.0 * delta # se queda atrás
		_vis.position.y -= 4.0 * delta
	# la boca a la altura del arma (la mandíbula de abajo, un poco por debajo)
	var jaw := Chest.SIZE.y * 0.62 * _vis.scale.y
	var goal_y := gp.y - jaw * 0.85
	global_position.y = lerpf(global_position.y, goal_y, 1.0 - exp(-delta * 3.0)) if _t > 0.1 else goal_y
	global_position.x = front_x - _half
