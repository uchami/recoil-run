class_name BossShot
extends Node3D
## Lo que te tiran los jefes (no se le puede pegar: se esquiva).
##   rock   - piedra del topo: vuela en arco; si te toca, -ROCK_DAMAGE.
##   bomb   - bomba del zepelín: cae; al tocar el piso explota (radio BOMB_RADIUS).
##   bullet - bala del arma rival: va derecho y rápido; si te toca, -BULLET_DAMAGE.

const ROCK_DAMAGE := 2
const BOMB_DAMAGE := 3
const BOMB_RADIUS := 1.8
const BULLET_DAMAGE := 3
const GRAVITY := 14.0

var game: Node
var kind := "rock"
var vel := Vector3.ZERO
var _life := 6.0
var _done := false


func _ready() -> void:
	var mi := MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	match kind:
		"rock":
			var sm := SphereMesh.new()
			sm.radius = 0.32
			sm.height = 0.56
			m.albedo_color = Color("7a5a3a")
			m.roughness = 0.9
			sm.material = m
			mi.mesh = sm
		"bomb":
			var sm := SphereMesh.new()
			sm.radius = 0.38
			sm.height = 0.76
			m.albedo_color = Color("2a2a32")
			m.metallic = 0.5
			sm.material = m
			mi.mesh = sm
			var fuse := MeshInstance3D.new() # mecha encendida
			var fm := SphereMesh.new()
			fm.radius = 0.1
			fm.height = 0.2
			var fmat := StandardMaterial3D.new()
			fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			fmat.albedo_color = Color("ffb21a")
			fm.material = fmat
			fuse.mesh = fm
			fuse.position.y = 0.42
			add_child(fuse)
		"bullet":
			var bm := BoxMesh.new()
			bm.size = Vector3(0.5, 0.12, 0.12)
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color("ff3a4a")
			bm.material = m
			mi.mesh = bm
			rotation.z = atan2(vel.y, vel.x)
	add_child(mi)


func _physics_process(delta: float) -> void:
	if _done or game == null:
		return
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if kind != "bullet":
		vel.y -= GRAVITY * delta
	global_position += vel * delta
	if kind == "rock":
		rotation.z += delta * 6.0
	var gp: Vector3 = game.gun.global_position
	var radius := 0.55 if kind == "bullet" else 0.6
	if kind != "bomb" and global_position.distance_to(gp) < radius:
		game.hurt(BULLET_DAMAGE if kind == "bullet" else ROCK_DAMAGE, global_position, Vector2(vel.x, vel.y).normalized() * 4.0, 4.0, "boss")
		_end()
		return
	var ground: float = Level.top_at(game.blocks, global_position.x)
	if global_position.y < ground + 0.2:
		if kind == "bomb":
			game.explosion_fx(global_position)
			if global_position.distance_to(gp) < BOMB_RADIUS:
				var away := Vector2(gp.x - global_position.x, 1.0).normalized() * 6.0
				game.hurt(BOMB_DAMAGE, global_position, away, 5.0, "boss")
		_end()
	elif kind == "bomb" and global_position.distance_to(gp) < 0.7: # te cayó encima
		game.explosion_fx(global_position)
		game.hurt(BOMB_DAMAGE, global_position, Vector2(0, -1) * 4.0, 5.0, "boss")
		_end()


func _end() -> void:
	_done = true
	queue_free()
