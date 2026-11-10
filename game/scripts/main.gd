extends Node3D
## Juego: arma el mundo, maneja disparos, reglas, cámara, slow-mo y efectos.

enum State { READY, PLAYING, OVER, MARKET }

const FOV := 40.0
const VISIBLE_WIDTH := 8.5 # m visibles a lo ancho (pantallas verticales)
const MIN_VISIBLE_HEIGHT := 10.0 # m visibles a lo alto (pantallas horizontales)
const CAM_OFFSET := Vector3(-2.2, 1.3, 0.0) # vista 3/4 desde atrás y un poco arriba
const LOOK_AHEAD := 3.5
const GAP_CAM_LOOKAHEAD := 5.0 # a esta distancia del borde de un hueco la cámara empieza a alejarse
const GAP_CAM_MAX_WIDTH := 24.0 # ancho visible máximo al cruzar un hueco largo
const CAM_KEEP := Vector2(0.7, 0.6) # el arma nunca sale de esta fracción central de la pantalla

var state := State.READY
var ammo := Config.START_AMMO
var distance := 0
var max_height := 0
var max_ammo := Config.START_AMMO
var kills := 0
var headshots := 0

const GEN_AHEAD := 60.0 # metros de mundo generados por delante del arma
const FALL_MARGIN := 6.0 # metros por debajo del borde más bajo del hueco = te caíste
const KEEP_BEHIND := 50.0 # y cuánto se conserva por detrás antes de liberarlo

var level_seed := -1 # -1 = random en cada partida (los tests fijan uno)
var level: Level
var blocks: Array = [] # bloques vivos, ordenados por x
var gun: Gun
var enemies: Array = [] # sin tipo: puede tener instancias ya liberadas
var entities: Array = [] # resortes, bichos, cofres, balas sueltas, poderes
var camera: Camera3D
var hud: Hud
var sfx: Sfx
var streak := 0 # headshots seguidos (los tiros errados no la cortan; un kill al cuerpo sí)
var kill_streak := 0 # tiros seguidos que mataron algo (un tiro que no mata la corta)
var last_power := ""
var _power_pending := false # un cofre soltó un poder en este tiro
var powers := {} # poder -> segundos que le quedan

var _queued_shots := 0
var _cam_target := Vector3.ZERO
var _cam_width := VISIBLE_WIDTH
var _slowmo_left := 0.0
var _idle_angle := 0.0
var _time := 0.0
var _rest_timer := 0.0
var _empty_timer := 0.0
var _over_at_ms := 0
var _rocks: Array[MeshInstance3D] = []
var _flash_light: OmniLight3D
var _hurt_cd := 0.0
var _laser: MeshInstance3D
var _sky_mat: ProceduralSkyMaterial
var _sky_day := {}
var _stars_mat: StandardMaterial3D
var space_t := 0.0 # 0 = cielo violeta, 1 = espacio (negro con estrellas)
var special_zones: Array = [] # niveles especiales ya generados que todavía no empezaron
var special_zone := {} # el nivel especial en curso ({} = ninguno): {kind, x0, x1, total, points, lights, hurt, broken}
var specials_done := 0
var _gen_zone := {} # el nivel especial que se está generando (todavía sin final)
var _chaser: Chaser
var _boss: Boss
var _env: Environment
var _sun: DirectionalLight3D
var _gun_lamp: OmniLight3D
var _gun_torch: SpotLight3D
var _dark_t := 0.0 # 0 = normal, 1 = apagón
var _tint_t := 0.0
var _tint := {"top": Color.BLACK, "hor": Color.BLACK}
var fan_ride := 0.0 # > 0 mientras un ventilador te sube (lo renueva en cada paso)
var sky_spawned := 0
var _sky_progress := 0.0 # metros recorridos (adelante o arriba) desde el último bicho
var _sky_next := 12.0
var _sky_last := Vector3.ZERO
var bullets: Array = [] # balas en vuelo: {pos, dir, left, kills, max_kills, killed, exclude, node}
var perks := {} # mejoras del mercado activas en esta partida: "pierce", "ricochet", "slowmo", "sight"
var pierce: bool: # balas penetrantes
	get:
		return perks.has("pierce")
	set(value):
		if value:
			perks["pierce"] = true
		else:
			perks.erase("pierce")
var markets_visited := 0
var market_offers: Array = [] # lo que ofrece la bañadera en esta visita
var bought_this_run := 0 # cada compra encarece las siguientes (en esta partida)
var _bought_visit: Array = [] # lo que compraste en esta visita al mercado
var revived := false
var eaten := false # el cofre trampa te comió: se ve cómo cierra la boca y perdés
var _float_pos := Vector3(Level.START.x, Level.START.y, 0.0) # dónde flota el arma antes del primer tiro


func _ready() -> void:
	Engine.time_scale = 1.0
	Tuning.load_saved()
	_apply_gravity()
	Records.load_saved()
	ammo = Config.START_AMMO + Records.stat("extra_start")
	max_ammo = ammo
	for k in PERK_STATS:
		if Records.stat(PERK_STATS[k]) > 0:
			perks[k] = true
	level = Level.new(level_seed, Level.debug_special)
	Level.debug_special = "" # "probar nivel" vale para una sola partida

	sfx = Sfx.new()
	add_child(sfx)

	_build_environment()
	_build_block_materials()
	_build_rocks()

	gun = Gun.new()
	gun.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	gun.freeze = true
	add_child(gun)
	gun.global_position = Vector3(Level.START.x, Level.START.y, 0.0)
	gun.landed.connect(func(speed: float): sfx.play("land", linear_to_db(clampf(speed / 10.0, 0.15, 1.0))))
	_build_laser()
	# en el apagón: una luz tenue sobre el arma (del lado de la cámara, para que
	# se vea) y una linterna que alumbra hacia donde apunta el cañón
	_gun_lamp = OmniLight3D.new()
	_gun_lamp.light_color = Color("ffe7b0")
	_gun_lamp.omni_range = 6.0
	_gun_lamp.light_energy = 0.0
	_gun_lamp.position = Vector3(0, 0.3, 1.6)
	gun.add_child(_gun_lamp)
	_gun_torch = SpotLight3D.new()
	_gun_torch.light_color = Color("fff1c8")
	_gun_torch.spot_range = 11.0
	_gun_torch.spot_angle = 22.0
	_gun_torch.spot_attenuation = 0.8
	_gun_torch.light_energy = 0.0
	_gun_torch.rotation.y = -PI / 2.0 # la luz sale por -Z: así sale por +X (el cañón)
	_gun_torch.position = Vector3(0.3, 0, 0.3)
	gun.add_child(_gun_torch)

	_stream_world(Level.START.x)

	camera = Camera3D.new()
	camera.fov = FOV
	camera.far = 250.0
	add_child(camera)
	_cam_target = Vector3(Level.START.x + LOOK_AHEAD, Level.START.y, 0.0)

	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color("ffd27a")
	_flash_light.omni_range = 6.0
	_flash_light.light_energy = 0.0
	add_child(_flash_light)

	hud = Hud.new()
	add_child(hud)
	hud.retry_pressed.connect(restart)
	hud.tuning_changed.connect(_apply_tuning)
	hud.test_level.connect(func(kind: String):
		Level.debug_special = kind
		restart())
	hud.test_power.connect(func(power: String):
		if state == State.PLAYING:
			_activate_power(power, gun.global_position))
	hud.market_buy.connect(_market_buy)
	hud.market_close.connect(_market_close)
	_refresh_perks()

	_build_stars()
	_update_camera(1.0)
	_prewarm()


func _apply_tuning() -> void:
	_apply_gravity()
	gun.apply_tuning()


func _apply_gravity() -> void:
	PhysicsServer3D.area_set_param(get_world_3d().space, PhysicsServer3D.AREA_PARAM_GRAVITY, Tuning.values.gravity)


# --- input ---

func _unhandled_input(event: InputEvent) -> void:
	# En mobile los toques llegan como clicks (emulate_mouse_from_touch).
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_tap()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_ENTER, KEY_UP:
				_on_tap()
			KEY_R:
				restart()


func _on_tap() -> void:
	if state == State.MARKET: # se usa con los botones del mercado
		return
	if state == State.OVER:
		if Time.get_ticks_msec() - _over_at_ms > 600:
			restart()
		return
	_queued_shots += 1


func restart() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


# --- disparo ---

func shoot() -> void:
	if state == State.OVER or eaten:
		return
	var first := state == State.READY
	if first:
		state = State.PLAYING
		gun.freeze = false
		hud.hide_start()
	var infinite := power_on("infinite")
	if ammo <= 0 and not infinite:
		hud.popup_world(camera, gun.global_position + Vector3(0, 1.2, 0), "SIN BALAS", "empty")
		sfx.play("empty")
		return
	if not infinite:
		ammo -= 1
	sfx.play("shot", 0.0, 1.0, 0.08)

	var from := gun.muzzle_position()
	var d := gun.barrel_dir()
	gun.fire(first)
	_fx_flash(from)
	_spawn_bullet(from, d)


# --- balas: vuelan (rápido, pero se ven) ---

## Una bala sale del cañón. Avanza en cada paso de física (en slow-mo, lenta).
func _spawn_bullet(from: Vector3, d: Vector2) -> void:
	var node := Node3D.new()
	var core := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.45, 0.07, 0.07)
	cm.material = _unshaded(Color("fff6d0") if not pierce else Color("bff3ff"))
	core.mesh = cm
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(core)
	var tail := MeshInstance3D.new() # estela: crece hasta 1.8 m detrás de la bala
	tail.name = "Tail"
	var tm := BoxMesh.new()
	tm.size = Vector3(1.0, 0.04, 0.04)
	tm.material = _unshaded(Color(1.0, 0.85, 0.45, 0.45) if not pierce else Color(0.45, 0.9, 1.0, 0.5))
	tail.mesh = tm
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tail.scale.x = 0.01
	node.add_child(tail)
	add_child(node)
	node.global_position = from
	node.rotation.z = atan2(d.y, d.x)
	bullets.append({"pos": from, "dir": Vector3(d.x, d.y, 0.0), "dir2": d, "left": Config.BULLET_RANGE,
		"kills": 0, "max_kills": Config.PIERCE_KILLS if pierce else 1, "killed": false,
		"bounces": Config.RICOCHETS if perks.has("ricochet") else 0, "seg": Config.BULLET_RANGE,
		"exclude": [gun.get_rid()], "node": node})


func _update_bullets(delta: float) -> void:
	for b in bullets.duplicate():
		_step_bullet(b, Config.BULLET_SPEED * delta)


## Avanza una bala `step` metros. Si mata y es penetrante, sigue (hasta PIERCE_KILLS).
func _step_bullet(b: Dictionary, step: float) -> void:
	step = minf(step, b.left)
	for guard in 8:
		if step <= 0.0:
			break
		var to: Vector3 = b.pos + b.dir * step
		var hit := _raycast(b.pos, to, b.exclude)
		if hit.is_empty():
			b.left -= step
			b.pos = to
			break
		var travelled: float = b.pos.distance_to(hit.position)
		b.left -= travelled
		step -= travelled
		b.pos = hit.position
		var c: Object = hit.collider
		if c == null or not c.has_method("shot"):
			_fx_puff(hit.position, Color("55555f"), 8, 0.5, false) # piso
			if b.bounces > 0: # balas que rebotan (mercado)
				_ricochet(b, hit.normal)
				continue
			_end_bullet(b)
			return
		# Regla: no se puede matar lo que todavía no apareció en pantalla (la bala pasa de largo).
		if not _was_seen(c, hit.position):
			b.exclude.append(c.get_rid())
			continue
		var res: Dictionary = c.shot(hit, b.dir2)
		if res.get("result", "none") == "none": # ya estaba muerto: lo atraviesa
			b.exclude.append(c.get_rid())
			continue
		if _on_hit(res, hit.position):
			b.killed = true
			b.kills += 1
			if b.kills < b.max_kills: # penetrante: sigue volando
				b.exclude.append(c.get_rid())
				if b.kills >= 2:
					hud.popup_world(camera, hit.position + Vector3(0, 1.2, 0), "x%d" % b.kills, "headshot")
				if b.kills == Config.PIERCE_SLOWMO_KILLS: # festejo: cámara lenta
					start_slowmo(Config.SLOWMO_DURATION * 1.5)
					sfx.play("slowmo", -6.0, 1.0, 0.0)
				continue
		_end_bullet(b)
		return
	if b.left <= 0.0:
		_end_bullet(b)
		return
	var node: Node3D = b.node
	node.global_position = b.pos
	var tail_len := minf(1.8, b.seg - b.left)
	var tail: Node3D = node.get_node("Tail")
	tail.scale.x = maxf(tail_len, 0.01)
	tail.position.x = -tail_len / 2.0


## Rebota en el piso: sale espejada y la estela arranca de nuevo.
func _ricochet(b: Dictionary, normal: Vector3) -> void:
	b.bounces -= 1
	var od: Vector3 = b.dir
	var nd := od.bounce(normal)
	nd.z = 0.0
	nd = nd.normalized()
	b.dir = nd
	b.dir2 = Vector2(nd.x, nd.y)
	b.pos += normal * 0.02
	b.seg = b.left
	(b.node as Node3D).rotation.z = atan2(nd.y, nd.x)
	sfx.play("clank", -8.0, 1.6)


## La bala terminó (pegó, se fue de rango): rachas y poderes se deciden acá.
func _end_bullet(b: Dictionary) -> void:
	bullets.erase(b)
	var node: Node3D = b.node
	node.global_position = b.pos
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3(0.2, 1.0, 1.0), 0.06)
	tw.tween_callback(node.queue_free)
	kill_streak = kill_streak + 1 if b.killed else 0
	if _power_pending or streak >= Config.STREAK_FOR_POWER or kill_streak >= Config.STREAK_FOR_POWER:
		_power_pending = false
		grant_power(b.pos)


## ¿Esto ya apareció alguna vez en pantalla? (o está en pantalla justo donde le pegaron)
func _was_seen(c: Object, point: Vector3) -> bool:
	if camera.is_position_in_frustum(point):
		return true
	var n: Node = c as Node
	while n != null and n != self:
		if n.has_meta("seen"):
			return true
		n = n.get_parent()
	return false


## Marca lo que está en pantalla como "visto" (desde ahí se lo puede matar).
func _mark_seen() -> void:
	for list in [enemies, entities]:
		for n in list:
			if is_instance_valid(n) and not n.has_meta("seen") and camera.is_position_in_frustum(n.global_position + Vector3(0, 0.6, 0)):
				n.set_meta("seen", true)


const THREAT_COLORS := {"Rocket": Color("ff4d4d"), "Airplane": Color("ffa03a"), "Ufo": Color("7dff6b")}


## Lo peligroso que está cerca pero fuera de pantalla: para las flechas del borde.
func _threats() -> Array:
	var out := []
	var gp := gun.global_position
	for n in entities:
		if not is_instance_valid(n) or not (n is Rocket or n is Airplane or n is Ufo) or not n.alive:
			continue
		var p: Vector3 = n.global_position
		var dist := p.distance_to(gp)
		if dist > Config.ARROW_RANGE or camera.is_position_in_frustum(p):
			continue
		var kind := "Rocket" if n is Rocket else ("Airplane" if n is Airplane else "Ufo")
		out.append({"at": camera.unproject_position(p), "color": THREAT_COLORS[kind], "near": 1.0 - dist / Config.ARROW_RANGE})
	if _chaser and not _chaser.done: # la boca gigante de la persecución
		var mp := Vector3(_chaser.front_x, gp.y, 0.0)
		if not camera.is_position_in_frustum(mp):
			out.append({"at": camera.unproject_position(mp), "color": THREAT_COLORS.Rocket, "near": clampf(1.0 - (gp.x - mp.x) / Config.CHASE_MAX_GAP, 0.3, 1.0)})
	return out


## Lo que pueden pegar las balas: piso, personajes, cofres y bichos (áreas).
func _raycast(from: Vector3, to: Vector3, exclude: Array = []) -> Dictionary:
	var ex: Array[RID] = [gun.get_rid()]
	for r in exclude:
		ex.append(r)
	var q := PhysicsRayQueryParameters3D.create(from, to, Config.L_TERRAIN | Config.L_ENEMY | Config.L_FLYER, ex)
	q.hit_from_inside = true
	q.collide_with_areas = true
	return get_world_3d().direct_space_state.intersect_ray(q)


const KILL_RESULTS := ["headshot", "kill", "flyer_kill", "mimic_kill", "chest_kill", "plane_kill", "rocket_kill", "padlock_kill", "ufo_kill",
	"target_hit", "boss_hit", "boss_kill"]


## Aplica el resultado de un tiro. Devuelve true si mató algo.
func _on_hit(res: Dictionary, point: Vector3) -> bool:
	var reward: int = res.get("reward", 0)
	var above := point + Vector3(0, 0.4, 0)
	match res.get("result", ""):
		"headshot":
			kills += 1
			headshots += 1
			streak += 1
			start_slowmo(Config.SLOWMO_DURATION * (Config.LONG_SLOWMO if perks.has("slowmo") else 1.0))
			_fx_puff(point, Color("ff2a2a") if not res.get("space", false) else Color("f2f2f0"), 18, 0.9, true)
			hud.popup_world(camera, above, "HEADSHOT! +%d" % reward, "headshot")
			sfx.play("headshot")
			sfx.play("slowmo", -6.0, 1.0, 0.0)
		"kill":
			kills += 1
			streak = 0
			_fx_puff(point, Color("ff2a2a") if not res.get("space", false) else Color("f2f2f0"), 12, 0.9, true)
			hud.popup_world(camera, above, "+%d" % reward, "")
			sfx.play("kill")
		"blocked":
			_fx_puff(point, Color("ffe7a0"), 10, 0.35, false)
			hud.popup_world(camera, above, "¡CLANK!", "clank")
			sfx.play("clank")
		"plane_hit":
			_fx_puff(point, Color("d9dde6"), 8, 0.4, false)
			sfx.play("clank", -4.0, 0.8)
		"plane_kill", "rocket_kill", "padlock_kill", "ufo_kill":
			kills += 1
			explosion_fx(point)
			hud.popup_world(camera, above, "+%d" % reward, "")
		"flyer_kill", "mimic_kill":
			kills += 1
			_fx_puff(point, Color("6b4a3a"), 12, 0.8, true)
			hud.popup_world(camera, above, "+%d" % reward, "")
			sfx.play("kill", 0.0, 1.3)
		"chest_hit", "mimic_hit":
			_fx_puff(point, Color("c98a4a"), 8, 0.5, true)
			sfx.play("chest_hit")
		"chest_kill":
			kills += 1
			_fx_puff(point, Color("ffcf3a"), 20, 0.9, true)
			sfx.play("chest_hit")
			sfx.play("chest_open")
			if res.get("power", false):
				_power_pending = true
			else:
				hud.popup_world(camera, above, "+%d" % reward, "headshot")
		"target_hit":
			var pts: int = res.get("points", 1)
			if special_zone.get("kind", "") == "gallery":
				special_zone.points += pts
			_fx_puff(point, Color("f4f1ea"), 12, 0.6, false)
			if pts >= 2:
				hud.popup_world(camera, above, "¡CENTRO! +2", "headshot")
				sfx.play("headshot")
			else:
				hud.popup_world(camera, above, "+1", "")
				sfx.play("clank", -2.0, 1.4)
		"boss_hit":
			if special_zone.get("kind", "") == "boss":
				special_zone.broken += 1
			hud.popup_world(camera, above, "¡FALTAN %d!" % res.get("left", 0), "headshot")
			sfx.play("headshot")
		"boss_kill":
			kills += 1
			if special_zone.get("kind", "") == "boss":
				special_zone.broken += 1
			explosion_fx(point)
			hud.special_banner("¡JEFE DERROTADO!", reward)
			sfx.play("fanfare")
		"firefly":
			if special_zone.get("kind", "") == "blackout":
				special_zone.lights += 1
			_fx_puff(point, Color("eaff8a"), 14, 0.6, false)
			hud.popup_world(camera, above, "+%d" % reward, "headshot")
			sfx.play("coin")
		"trap_open":
			hud.popup_world(camera, above, "¡TRAMPA!", "hurt")
			sfx.play("chomp")
	if reward > 0:
		ammo += reward
		hud.bump_ammo()
	return res.get("result", "") in KILL_RESULTS


# --- daño, objetos y poderes (los llaman las cosas del mundo) ---

func start_slowmo(duration: float) -> void:
	_slowmo_left = maxf(_slowmo_left, duration)
	Engine.time_scale = Config.SLOWMO_SCALE


func power_on(power: String) -> bool:
	return powers.get(power, 0.0) > 0.0


## Un golpe: te saca balas (las balas son la vida). Sin balas, un golpe te mata.
## knock: velocidad nueva del arma (cero = no empuja); spin: giro que se suma.
func hurt(amount: int, from: Vector3, knock := Vector2.ZERO, spin := 0.0, _cause := "") -> void:
	if eaten or state != State.PLAYING or power_on("untouchable") or _hurt_cd > 0.0:
		return
	_hurt_cd = Config.HURT_COOLDOWN
	if not special_zone.is_empty():
		special_zone.hurt = true
	if knock != Vector2.ZERO or spin != 0.0:
		var v := Vector3(knock.x, knock.y, 0.0) if knock != Vector2.ZERO else gun.linear_velocity
		gun.knock(v, spin)
	sfx.play("hurt")
	hud.flash_hurt()
	if ammo <= 0 and not power_on("infinite"):
		_game_over("¡TE MATARON!")
		return
	ammo = maxi(0, ammo - amount)
	hud.popup_world(camera, gun.global_position + Vector3(0, 1.0, 0), "-%d" % amount, "hurt")
	_fx_puff(from.lerp(gun.global_position, 0.5), Color("ff4d6d"), 8, 0.5, false)


## away: -1 = te devuelve a la izquierda (lo normal), +1 = a la derecha.
## Un candado te tocó: se pega al arma y pesa más por unos segundos.
## Devuelve false si no se pudo pegar (intocable, o no estás jugando).
## Si ya tenés uno, se renueva el tiempo.
func lock_gun() -> bool:
	if state != State.PLAYING or power_on("untouchable"):
		return false
	var had := power_on("locked")
	powers.locked = Config.LOCK_TIME
	if had:
		sfx.play("lock")
		return true
	gun.weight = Config.LOCK_WEIGHT
	var lock_vis := Padlock.build_mesh(0.45)
	lock_vis.name = "Lock"
	lock_vis.position = Vector3(-0.05, -0.32, 0.12)
	gun.add_child(lock_vis)
	sfx.play("lock")
	hud.popup_world(camera, gun.global_position + Vector3(0, 1.0, 0), "¡CANDADO!", "hurt")
	return true


## Te chocaste el candado de un cofre: el cofre se entierra.
func chest_lost(at: Vector3) -> void:
	hud.popup_world(camera, at, "COFRE PERDIDO", "hurt")
	sfx.play("land", -2.0, 0.6)


func _unlock_gun() -> void:
	gun.weight = 1.0
	var l := gun.get_node_or_null("Lock")
	if l:
		l.queue_free()


func spring_launch(_spring: Node3D, away: float) -> void:
	if state != State.PLAYING:
		return
	var impact := gun.linear_velocity.length()
	var push := minf(Config.SPRING_BASE_PUSH + impact * Config.SPRING_PUSH_GAIN, Config.SPRING_MAX_PUSH)
	var vel := Vector3(away * push, 2.0 + impact * 0.25, 0.0)
	gun.knock(vel, -away * impact * Config.SPRING_SPIN_GAIN)
	sfx.play("boing", linear_to_db(clampf(0.4 + impact / 12.0, 0.4, 1.0)))


func collect(p: Pickup) -> void:
	ammo += 1
	sfx.play("pickup", -2.0, 1.0, 0.1)
	hud.bump_ammo()


const POWERS := ["infinite", "laser", "ammo15", "untouchable"]


## Un poder random del pool, aplicado al instante. Reinicia las dos rachas.
func grant_power(at: Vector3) -> void:
	streak = 0
	kill_streak = 0
	_activate_power(POWERS.pick_random(), at)


func _activate_power(power: String, at: Vector3) -> void:
	last_power = power
	sfx.play("powerup")
	var names := {"infinite": "¡BALAS INFINITAS!", "laser": "¡MIRILLA LÁSER!", "ammo15": "+15 BALAS", "untouchable": "¡INTOCABLE!"}
	hud.popup_world(camera, at + Vector3(0, 0.8, 0), names.get(power, power), "headshot")
	match power:
		"ammo15":
			ammo += Config.POWER_AMMO
			hud.bump_ammo()
		"infinite":
			powers.infinite = Config.POWER_INFINITE_TIME
		"laser":
			powers.laser = Config.POWER_LASER_TIME
		"untouchable":
			powers.untouchable = Config.POWER_UNTOUCHABLE_TIME
			gun.set_glow(Color(0.75, 0.45, 1.0, 0.45))


func spawn_pickup(kind: String, pos: Vector3, vel: Vector3, floating := false) -> Pickup:
	var p := Pickup.new()
	p.kind = kind
	p.floating = floating
	p.game = self
	add_child(p)
	p.global_position = Vector3(pos.x, pos.y, 0.0)
	if not floating:
		p.linear_velocity = vel
	entities.append(p)
	return p


# --- niveles especiales ---

const SPECIAL_INFO := {
	"chase": {"name": "PERSECUCIÓN", "goal": "¡QUE NO TE ALCANCE!", "top": Color("ff5a3a"), "hor": Color("ffc0a0"), "ui": Color("ff7a5a")},
	"gallery": {"name": "GALERÍA DE TIRO", "goal": "PEGALE A LAS DIANAS\nAL CENTRO VALE DOBLE", "top": Color("ffb21a"), "hor": Color("fff1b8"), "ui": Color("ffcf3a")},
	"blackout": {"name": "APAGÓN", "goal": "LAS LUCECITAS DAN BALAS\nQUE NO TE TOQUEN", "top": Color("000000"), "hor": Color("05030c"), "ui": Color("b48cff")},
	"boss": {"name": "JEFE", "goal": "ROMPÉ SUS 3\nPUNTOS DÉBILES ROJOS", "top": Color("2f4a78"), "hor": Color("a9bfdc"), "ui": Color("6fd0ff")},
}


func _update_specials(p: Vector3) -> void:
	if special_zone.is_empty():
		if not special_zones.is_empty() and state == State.PLAYING and p.x >= special_zones[0].x0:
			_special_start(special_zones.pop_front())
		return
	if state != State.PLAYING and state != State.READY:
		return
	hud.set_special_info(_special_text(p))
	if p.x > special_zone.x1:
		_special_finish()


## Entrás a un nivel especial: cartel con el nombre y el objetivo, el cielo cambia.
func _special_start(z: Dictionary) -> void:
	special_zone = z
	var info: Dictionary = SPECIAL_INFO[z.kind]
	_tint = {"top": info.top, "hor": info.hor}
	match z.kind:
		"chase":
			_chaser = Chaser.new()
			_chaser.game = self
			_chaser.start_x = gun.global_position.x
			_chaser.end_x = z.x0 + Level.SPECIAL_LEN.chase
			_chaser.front_x = gun.global_position.x - Config.CHASE_START_GAP
			add_child(_chaser)
	hud.special_intro(info.name, info.goal, info.ui)
	hud.set_special_info(_special_text(gun.global_position))
	sfx.play("fanfare", -4.0, 0.8)


func _special_text(p: Vector3) -> String:
	var z := special_zone
	match z.kind:
		"chase":
			var end: float = z.x0 + Level.SPECIAL_LEN.chase
			return "¡CORRÉ! FALTAN %d m" % maxi(0, ceili(end - p.x))
		"gallery":
			return "PUNTOS: %d DE %d" % [z.points, z.total * 2]
		"blackout":
			return "LUCES: %d · %s" % [z.lights, "TE TOCARON" if z.hurt else "SIN GOLPES"]
		"boss":
			return "JEFE: %d DE 3" % z.broken
	return ""


## Saliste del nivel especial: premio según cómo te fue.
func _special_finish() -> void:
	var z := special_zone
	special_zone = {}
	hud.set_special_info("")
	if _chaser:
		_chaser.done = true
		get_tree().create_timer(3.0).timeout.connect(_chaser.queue_free)
		_chaser = null
	if state != State.PLAYING and state != State.READY:
		return
	specials_done += 1
	match z.kind:
		"chase":
			_special_result("¡ESCAPASTE!", Config.CHASE_REWARD)
		"gallery":
			var frac: float = float(z.points) / maxf(z.total * 2.0, 1.0)
			for medal in Config.GALLERY_MEDALS:
				if frac >= medal[0]:
					_special_result("¡%s!" % medal[1], medal[2])
					return
			_special_result("SIN MEDALLA", 0)
		"blackout":
			_special_result("¡INTOCADO!" if not z.hurt else "TE TOCARON", Config.BLACKOUT_REWARD if not z.hurt else 0)
		# el jefe da su premio cuando lo matás


func _special_result(title: String, reward: int) -> void:
	if reward > 0:
		ammo += reward
		hud.bump_ammo()
		sfx.play("fanfare")
	else:
		sfx.play("empty")
	hud.special_banner(title, reward)


## El jefe tira un cohete desde el brazo.
func boss_rocket(at: Vector3) -> void:
	_spawn_item({"type": "rocket", "x": at.x, "y": at.y})
	entities[-1].set_meta("seen", true)
	sfx.play("engine", -8.0)


func explosion_fx(at: Vector3) -> void:
	_fx_puff(at, Color("ff8a1a"), 26, 0.9, false)
	_fx_puff(at, Color("4a4550"), 14, 1.2, false)
	_flash_light.global_position = at + Vector3(0, 0, 1.0)
	_flash_light.light_energy = 10.0
	sfx.play("explosion")


func spawn_mimic(pos: Vector3) -> void:
	var m := Mimic.new()
	m.game = self
	add_child(m)
	m.global_position = pos
	entities.append(m)


# --- mercado (bañadera con billetes) ---

## El arma se quedó en la bañadera: se abre el mercado.
func enter_market(tub: Node3D) -> void:
	if state != State.PLAYING:
		return
	state = State.MARKET
	markets_visited += 1
	_queued_shots = 0
	gun.freeze = true
	gun.linear_velocity = Vector3.ZERO
	gun.angular_velocity = Vector3.ZERO
	_idle_angle = gun.angle()
	_float_pos = tub.global_position + Vector3(0.0, Config.TUB_SIZE.y + 2.2, 0.0)
	_roll_offers()
	_bought_visit = []
	sfx.play("powerup")
	hud.show_market(_market_info())


const MARKET_ITEMS := ["pierce", "ricochet", "sight", "slowmo", "insurance", "extra_start"]
const PERK_STATS := {"pierce": "pierce_runs", "ricochet": "ricochet_runs", "sight": "sight_runs", "slowmo": "slowmo_runs"}


func _market_info() -> Dictionary:
	var offers := []
	for item in market_offers:
		var owned := Records.stat(PERK_STATS[item]) if PERK_STATS.has(item) else Records.stat(item)
		offers.append({"item": item, "price": price(item), "can": can_buy(item), "available": _offerable(item), "owned": owned,
			"bought": item in _bought_visit})
	return {"ammo": ammo, "offers": offers}


## Elige al azar las mejoras de esta visita (las que todavía se pueden comprar).
func _roll_offers() -> void:
	var pool := MARKET_ITEMS.filter(_offerable)
	pool.shuffle()
	market_offers = pool.slice(0, Config.MARKET_OFFERS)


func _offerable(item: String) -> bool:
	match item:
		"extra_start":
			return Records.stat("extra_start") < Config.MAX_EXTRA_START
		"insurance":
			return Records.stat("insurance") == 0
	return item in MARKET_ITEMS


func base_price(item: String) -> int:
	return {"pierce": Config.PIERCE_COST, "ricochet": Config.RICOCHET_COST, "sight": Config.SIGHT_COST,
		"slowmo": Config.SLOWMO_COST, "insurance": Config.INSURANCE_COST, "extra_start": Config.EXTRA_START_COST}.get(item, 999)


## Cada compra en esta partida encarece las siguientes.
func price(item: String) -> int:
	return roundi(base_price(item) * (1.0 + Config.MARKET_PRICE_STEP * bought_this_run))


## Se puede gastar todo menos una bala (siempre seguís jugando).
func can_buy(item: String) -> bool:
	return _offerable(item) and ammo - 1 >= price(item)


func _market_buy(item: String) -> void:
	if state != State.MARKET or not can_buy(item):
		return
	ammo -= price(item)
	bought_this_run += 1
	_bought_visit.append(item)
	match item:
		"extra_start":
			Records.set_stat("extra_start", Records.stat("extra_start") + 1)
		"insurance":
			Records.set_stat("insurance", 1)
		_:
			Records.set_stat(PERK_STATS[item], Records.stat(PERK_STATS[item]) + Config.PERK_RUNS)
			perks[item] = true
	sfx.play("pickup")
	hud.bump_ammo()
	_refresh_perks()
	hud.show_market(_market_info())


## Salís del mercado: flotás girando (inmune) hasta el primer tiro, como al arrancar.
func _market_close() -> void:
	if state != State.MARKET:
		return
	hud.hide_market()
	state = State.READY


func _refresh_perks() -> void:
	var names := {"pierce": "PENETRANTES", "ricochet": "REBOTE", "sight": "MIRILLA", "slowmo": "CÁMARA LENTA"}
	var parts := []
	for k in MARKET_ITEMS:
		if perks.has(k):
			parts.append("%s %d" % [names[k], Records.stat(PERK_STATS[k])])
	if Records.stat("insurance") > 0:
		parts.append("SEGURO")
	hud.set_perks(" · ".join(parts))


## Seguro de vida: en vez de perder, flotás con unas balas (una sola vez).
func _revive() -> void:
	Records.set_stat("insurance", 0)
	revived = true
	ammo = Config.INSURANCE_AMMO
	_rest_timer = 0.0
	_empty_timer = 0.0
	_hurt_cd = Config.HURT_COOLDOWN
	_queued_shots = 0
	var p := gun.global_position
	var x := p.x
	for b in blocks: # arriba de piso firme (si te caíste en un hueco, del otro lado)
		if b.x1 > x + 1.0:
			x = maxf(x, b.x0 + 1.5)
			break
	_float_pos = Vector3(x, maxf(p.y, Level.top_at(blocks, x)) + 3.0, 0.0)
	gun.freeze = true
	gun.linear_velocity = Vector3.ZERO
	gun.angular_velocity = Vector3.ZERO
	_idle_angle = gun.angle()
	state = State.READY
	sfx.play("powerup")
	hud.bump_ammo()
	hud.popup_world(camera, _float_pos + Vector3(0, 1.2, 0), "¡SEGURO DE VIDA!", "headshot")
	_refresh_perks()


# --- loop ---

func _physics_process(delta: float) -> void:
	if state == State.READY:
		_idle_angle += Config.IDLE_SPIN * delta
		_demo_autofire()
		var bob := sin(_time * 2.5) * 0.12
		gun.global_transform = Transform3D(Basis(Vector3.BACK, _idle_angle), _float_pos + Vector3(0.0, bob, 0.0))
	while _queued_shots > 0:
		_queued_shots -= 1
		shoot()
	_update_bullets(delta)


## Solo desarrollo: `godot --path . -- --demo-headshot` dispara solo cuando el
## cañón apunta a la cabeza del primer personaje (para grabar/probar el slow-mo).
func _demo_autofire() -> void:
	if not "--demo-headshot" in OS.get_cmdline_user_args() or _time < 1.0 or enemies.is_empty():
		return
	var head: Vector3 = enemies[0].global_position + Vector3(0, Enemy.HEAD_Y, 0)
	var p := gun.global_position
	var target := atan2(head.y - (p.y + Gun.MUZZLE.y), head.x - p.x)
	if absf(wrapf(_idle_angle - target, -PI, PI)) < 0.03:
		_queued_shots = 1


func _process(delta: float) -> void:
	var real_dt := delta / maxf(Engine.time_scale, 0.0001)
	_time += real_dt

	# slow-mo con salida suave
	if _slowmo_left > 0.0:
		_slowmo_left = maxf(0.0, _slowmo_left - real_dt)
		var s := Config.SLOWMO_SCALE
		var ramp := Config.SLOWMO_RAMP_OUT
		Engine.time_scale = s if _slowmo_left > ramp else 1.0 - (_slowmo_left / ramp) * (1.0 - s)

	var p := gun.global_position
	distance = maxi(distance, floori(p.x - Level.START.x))
	if state == State.PLAYING:
		max_height = maxi(max_height, floori(p.y))
	max_ammo = maxi(max_ammo, ammo)
	_stream_world(p.x)
	_update_specials(p)
	fan_ride -= real_dt
	if state == State.PLAYING and fan_ride <= 0.0: # la subida en ventilador es limpia
		_sky_spawner(p)
	_hurt_cd -= real_dt
	for k in powers.keys():
		powers[k] -= real_dt
		if powers[k] <= 0.0:
			powers.erase(k)
			if k == "untouchable":
				gun.set_glow(null)
			elif k == "locked":
				_unlock_gun()
	_update_laser()
	_mark_seen()
	hud.set_threats(_threats() if state == State.PLAYING or state == State.READY else [])
	if state == State.PLAYING:
		_check_game_over(real_dt, p)

	_flash_light.light_energy *= exp(-delta * lerpf(40.0, 7.0, _dark_t)) # a oscuras dura más
	_update_camera(real_dt)
	_update_space(p, real_dt)
	for r in _rocks:
		r.rotate_y(r.get_meta("spin") * real_dt)
		if r.position.x < _cam_target.x - 45.0:
			r.position.x += 90.0
		elif r.position.x > _cam_target.x + 45.0:
			r.position.x -= 90.0
		if r.position.y < _cam_target.y - 15.0: # escaleras: las rocas acompañan en altura
			r.position.y += 30.0
		elif r.position.y > _cam_target.y + 22.0:
			r.position.y -= 30.0

	hud.set_values(maxi(Records.best.dist, distance), distance, ammo, power_on("infinite"))
	hud.set_powers(powers)
	hud.place_ammo(camera.unproject_position(p + Vector3(-0.1, 0.75, 0.0)))
	hud.set_vignette((1.0 - Engine.time_scale) / (1.0 - Config.SLOWMO_SCALE))


func _check_game_over(real_dt: float, p: Vector3) -> void:
	if eaten:
		return
	if p.y < Level.low_top_around(blocks, p.x) - FALL_MARGIN: # se cayó en un hueco
		_game_over("¡TE CAÍSTE!")
		return
	if ammo > 0 or power_on("infinite"):
		_rest_timer = 0.0
		_empty_timer = 0.0
		return
	_empty_timer += real_dt
	var still := gun.linear_velocity.length() < Config.REST_SPEED and absf(gun.angular_velocity.z) < 0.5
	_rest_timer = _rest_timer + real_dt if still else 0.0
	if _rest_timer > Config.REST_TIME_TO_GAME_OVER or _empty_timer > Config.MAX_EMPTY_TIME:
		_game_over("SIN BALAS")


## El cofre trampa te metió en la boca: la cierra y perdés. Sin vueltas (ni seguro
## de vida). Solo te salva el poder intocable. Devuelve true si te comió.
func eat_gun(at: Vector3) -> bool:
	if eaten or state != State.PLAYING or power_on("untouchable"):
		return false
	eaten = true
	_queued_shots = 0
	gun.freeze = true
	gun.linear_velocity = Vector3.ZERO
	gun.angular_velocity = Vector3.ZERO
	gun.visible = false
	sfx.play("chomp")
	hud.flash_hurt()
	hud.popup_world(camera, at + Vector3(0, 1.5, 0), "¡ÑAM!", "hurt")
	get_tree().create_timer(0.9, true, false, true).timeout.connect(func():
		if state == State.PLAYING:
			_game_over("¡TE COMIÓ!", true))
	return true


func _game_over(title: String, final := false) -> void:
	if not final and state == State.PLAYING and Records.stat("insurance") > 0:
		_revive()
		return
	state = State.OVER
	_over_at_ms = Time.get_ticks_msec()
	hud.set_special_info("")
	sfx.play("game_over")
	powers.clear()
	gun.set_glow(null)
	_unlock_gun()
	for k in perks: # las mejoras duran unas partidas: esta cuenta
		Records.set_stat(PERK_STATS[k], maxi(0, Records.stat(PERK_STATS[k]) - 1))
	hud.set_powers(powers)
	max_ammo = maxi(max_ammo, ammo)
	var attempt := {"dist": distance, "height": max_height, "ammo": max_ammo, "kills": kills, "headshots": headshots}
	var result := Records.add(attempt)
	hud.show_over(title, attempt, result)


func _update_camera(real_dt: float) -> void:
	var size := Vector2(get_window().size)
	var aspect := size.x / maxf(size.y, 1.0)
	var t := tan(deg_to_rad(FOV / 2.0))

	var p := gun.global_position
	var ground := Level.top_at(blocks, p.x)
	# Cerca del piso, la cámara se inclina hacia él (para verlo); a gran altura sigue al arma.
	var lean := clampf((p.y - ground) * 0.4, 0.0, 2.5)
	var ty := maxf(p.y - lean, ground) + 1.6
	# En el aire, mirar hacia donde vas: subiendo rápido se ve lo que viene de arriba.
	var vy := gun.linear_velocity.y if not gun.freeze else 0.0
	var look_up := clampf(vy * 0.4, -2.5, 4.0) if p.y - ground > 3.0 else 0.0
	var goal := Vector3(p.x + LOOK_AHEAD, ty + look_up, 0.0)
	var want_width := VISIBLE_WIDTH

	# Hueco adelante (o abajo): si el piso se ve en pantalla, alejar y correr la cámara
	# para que se vea dónde aterrizar. Si estás tan alto que el piso no se ve, no
	# importa: la cámara solo te sigue. (Se mira con la vista normal, sin zoom, para
	# que alejarse no haga aparecer el piso y la cámara no entre en un vaivén.)
	var landing := _landing_block(p.x)
	var base_half_h := maxf(VISIBLE_WIDTH / 2.0 / (t * aspect), MIN_VISIBLE_HEIGHT / 2.0 / t) * t
	var floor_visible := not landing.is_empty() and maxf(ground, landing.top) > ty - base_half_h + 0.5
	if floor_visible and landing.x0 - p.x < GAP_CAM_MAX_WIDTH * 1.5:
		var left := p.x - 1.5
		var right: float = landing.x0 + 2.5
		want_width = clampf(right - left, VISIBLE_WIDTH, GAP_CAM_MAX_WIDTH)
		goal.x = maxf(goal.x, minf((left + right) / 2.0, left + want_width / 2.0))
		goal.y = maxf((p.y + landing.top) / 2.0, minf(p.y, landing.top)) + 1.6

	# Niveles especiales: en la persecución la cámara mira para atrás (se ve la boca
	# que te sigue); con el jefe se aleja para que entre el robot entero.
	match special_zone.get("kind", ""):
		"chase":
			if _chaser:
				want_width = maxf(want_width, 12.0)
				goal.x = (p.x + maxf(_chaser.front_x, p.x - 10.0)) / 2.0 + 1.0
		"boss":
			if is_instance_valid(_boss) and _boss.alive and _boss.global_position.x - p.x < 30.0:
				var bx: float = _boss.global_position.x
				want_width = clampf(bx - p.x + 7.0, VISIBLE_WIDTH, 20.0)
				goal.x = (p.x + bx) / 2.0
				goal.y = maxf(goal.y, _boss.global_position.y + 6.5)
	_cam_width = lerpf(_cam_width, want_width, 1.0 - exp(-real_dt * 3.0))
	var dist := maxf(_cam_width / 2.0 / (t * aspect), MIN_VISIBLE_HEIGHT / 2.0 / t)
	_cam_target = _cam_target.lerp(goal, 1.0 - exp(-real_dt * 5.0))
	# Límite duro: por más rápido que vayas (resorte, ventilador, caída), el arma
	# nunca se sale de la parte central de la pantalla.
	var half_h := dist * t
	var half_w := half_h * aspect
	_cam_target.x = clampf(_cam_target.x, p.x - half_w * CAM_KEEP.x, p.x + half_w * CAM_KEEP.x)
	_cam_target.y = clampf(_cam_target.y, p.y - half_h * CAM_KEEP.y, p.y + half_h * CAM_KEEP.y)
	var slow_zoom := 1.0 - (1.0 - Engine.time_scale) * 0.18 # acerca un poco en slow-mo
	camera.global_position = _cam_target + CAM_OFFSET + Vector3(0, 0, dist * slow_zoom)
	camera.look_at(_cam_target)


## Bloque del otro lado del hueco si estás sobre un hueco o a menos de
## GAP_CAM_LOOKAHEAD metros del borde de uno; si no, {}.
func _landing_block(x: float) -> Dictionary:
	for i in blocks.size():
		var b: Dictionary = blocks[i]
		if b.x0 > x: # x está en un hueco (o antes del primer bloque)
			return b if i > 0 else {}
		if x < b.x1:
			if i + 1 < blocks.size() and blocks[i + 1].x0 - b.x1 > 0.5 and b.x1 - x < GAP_CAM_LOOKAHEAD:
				return blocks[i + 1]
			return {}
	return {}


# --- construcción del mundo ---

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("b46cff")
	sky_mat.sky_horizon_color = Color("f0d4ff")
	sky_mat.ground_horizon_color = Color("f0d4ff")
	sky_mat.ground_bottom_color = Color("e2c4ff")
	sky_mat.sky_curve = 0.25
	sky_mat.sun_angle_max = 0.0
	_sky_mat = sky_mat
	_sky_day = {"top": sky_mat.sky_top_color, "hor": sky_mat.sky_horizon_color,
		"ghor": sky_mat.ground_horizon_color, "gbot": sky_mat.ground_bottom_color}
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Ambiente de color fijo (no del cielo): con el cielo lavanda todo quedaba "quemado".
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9a8fc0")
	env.ambient_light_energy = 0.3
	_env = env
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	_sun = sun


var _block_mats: Array[StandardMaterial3D] = []
var _block_pm: PhysicsMaterial
var _built_count := 0
var _stream_x := -INF


func _build_block_materials() -> void:
	for c in [Color("a9afc2"), Color("9ea5ba")]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		_block_mats.append(m)
	_block_pm = PhysicsMaterial.new()
	_block_pm.friction = 0.7


## Genera piso y personajes por delante y libera lo que quedó muy atrás.
func _stream_world(x: float) -> void:
	_stream_x = maxf(_stream_x, x)
	while blocks.is_empty() or blocks[-1].x1 < _stream_x + GEN_AHEAD:
		var b := level.next_block()
		var prev: String = blocks[-1].special if not blocks.is_empty() else ""
		if b.special != prev:
			# (el final se anota en el mismo diccionario: puede que ya hayas entrado
			# y esté en special_zone, no en special_zones)
			if prev != "" and not _gen_zone.is_empty():
				_gen_zone.x1 = blocks[-1].x1
				_gen_zone = {}
			if b.special != "":
				_gen_zone = {"kind": b.special, "x0": b.x0, "x1": INF, "total": 0, "points": 0,
					"lights": 0, "hurt": false, "broken": 0}
				special_zones.append(_gen_zone)
		_add_block(b)
		for it in b.items:
			it["zone"] = b.special
			_spawn_item(it)
	var limit := _stream_x - KEEP_BEHIND
	while blocks.size() > 1 and blocks[0].x1 < limit:
		blocks.pop_front().node.queue_free()
	var keep_e := []
	for e in enemies:
		if _keep(e, limit):
			keep_e.append(e)
	enemies = keep_e
	var keep_n := []
	for n in entities:
		if _keep(n, limit):
			keep_n.append(n)
	entities = keep_n


## false si ya no existe o quedó muy atrás (y entonces lo libera).
func _keep(n, limit: float) -> bool:
	if not is_instance_valid(n):
		return false
	if (n as Node3D).global_position.x < limit:
		n.queue_free()
		return false
	return true


## Bichos voladores alrededor de tu altura: uno cada SKY_SPAWN_EVERY metros
## recorridos hacia adelante o hacia arriba (subir rápido también los trae).
func _sky_spawner(p: Vector3) -> void:
	if _sky_last == Vector3.ZERO:
		_sky_last = p
	var d := p - _sky_last
	_sky_last = p
	_sky_progress += maxf(d.x, 0.0) + maxf(d.y, 0.0)
	if _sky_progress < _sky_next:
		return
	_sky_progress = 0.0
	_sky_next = randf_range(Config.SKY_SPAWN_EVERY.x, Config.SKY_SPAWN_EVERY.y)
	var climbing := d.y > absf(d.x) * 1.5
	var pos: Vector3
	if climbing: # aparece arriba, fuera de pantalla
		pos = Vector3(p.x + randf_range(-2.0, 8.0), p.y + randf_range(10.0, 14.0), 0.0)
	else: # aparece adelante, cerca de tu altura
		pos = Vector3(p.x + randf_range(Config.SKY_SPAWN_AHEAD.x, Config.SKY_SPAWN_AHEAD.y), p.y + randf_range(-2.0, 5.0), 0.0)
	pos.y = maxf(pos.y, Level.top_at(blocks, pos.x) + 2.5) # nunca metido en el piso
	var alt := p.y - Level.top_at(blocks, p.x)
	if _air_market_ok(pos, alt) and randf() < Config.MARKET_AIR_CHANCE: # el mercado también vuela
		_spawn_item({"type": "market_air", "x": pos.x, "y": minf(pos.y, p.y + 1.0) - 2.0})
		sky_spawned += 1
		return
	var type := sky_type(alt)
	if type == "ufo" and entities.filter(func(n): return is_instance_valid(n) and n is Ufo and n.alive).size() >= Config.UFO_MAX:
		type = "astronaut" # los ovnis te persiguen: no más de UFO_MAX a la vez
	if type == "astronaut": # vienen en grupito (a veces en fila: ideal para balas penetrantes)
		var n := randi_range(Config.ASTRONAUT_GROUP.x, Config.ASTRONAUT_GROUP.y)
		var in_row := randf() < 0.4
		for i in n:
			var off := Vector3(i * 1.6, randf_range(-0.3, 0.3), 0.0) if in_row else Vector3(randf_range(-1.0, 4.0), randf_range(-2.5, 2.5), 0.0)
			_spawn_item({"type": type, "x": pos.x + off.x, "y": pos.y + off.y})
	else:
		_spawn_item({"type": type, "x": pos.x, "y": pos.y})
	sky_spawned += 1


## ¿Puede aparecer una bañadera voladora acá? Pasados MARKET_FROM m, en el aire,
## y lejos de cualquier otra bañadera (del piso o del aire).
func _air_market_ok(pos: Vector3, alt: float) -> bool:
	if alt < Config.MARKET_AIR_ALT or pos.x - Level.START.x < Config.MARKET_FROM:
		return false
	for n in entities:
		if is_instance_valid(n) and n is Tub and absf(n.global_position.x - pos.x) < Config.MARKET_MIN_GAP:
			return false
	return true


## Qué aparece según la altura sobre el piso.
func sky_type(altitude: float) -> String:
	if randf() < Config.AIR_SPRING_CHANCE: # resortes flotando, a cualquier altura
		return "spring_air"
	if randf() < Config.PADLOCK_CHANCE: # candados, a cualquier altura
		return "padlock"
	var r := randf()
	if altitude >= Config.UFO_ALT: # ovnis, astronautas y cohetes; ya no hay aviones
		return "ufo" if r < 0.25 else ("astronaut" if r < 0.75 else "rocket")
	if altitude >= Config.ROCKET_ALT: # astronautas, cohetes y aviones; sin pájaros
		return "astronaut" if r < 0.45 else ("rocket" if r < 0.8 else "plane")
	if altitude >= Config.PLANE_ALT: # aviones junto con los halcones
		return "plane" if r < 0.45 else ("hawk" if r < 0.85 else "bat")
	return "hawk" if r < 0.4 else "bat"


func _spawn_item(it: Dictionary) -> void:
	var pos := Vector3(it.x, it.y, 0.0)
	match it.type:
		"plain", "sword", "shield", "helmet":
			var e := Enemy.new()
			e.kind = it.type
			e.game = self
			add_child(e)
			e.global_position = pos + Vector3(0, 0.01, 0)
			enemies.append(e)
			if it.get("zone", "") == "blackout": # en la oscuridad solo se les ven los ojos
				e.add_glow_eyes()
			return
		"ammo":
			spawn_pickup("ammo", pos, Vector3.ZERO, true)
			return
	var n: Node3D
	match it.type:
		"spring":
			n = Spring.new()
		"spring_air": # flotando: pos es su centro
			n = Spring.new()
			pos.y -= Config.SPRING_HEIGHT / 2.0
		"chest", "trap":
			var c := Chest.new()
			c.trap = it.type == "trap"
			n = c
		"hawk", "bat":
			var f := Flyer.new()
			f.kind = it.type
			n = f
		"plane":
			n = Airplane.new()
		"fan":
			n = Fan.new()
		"booster":
			n = Booster.new()
		"market":
			n = Tub.new()
		"market_air":
			var t := Tub.new()
			t.floating = true
			n = t
		"firefly":
			n = Firefly.new()
		"target":
			var tg := Target.new()
			tg.mode = it.get("mode", "ground")
			n = tg
			if not special_zones.is_empty() and it.get("zone", "") == "gallery":
				special_zones[-1].total += 1
		"boss":
			_boss = Boss.new()
			n = _boss
		"rocket":
			n = Rocket.new()
		"padlock":
			n = Padlock.new()
		"ufo":
			n = Ufo.new()
		"astronaut":
			n = Astronaut.new()
		_:
			return
	n.set("game", self)
	n.position = pos
	add_child(n)
	entities.append(n)


func _add_block(b: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Config.L_TERRAIN
	body.collision_mask = 0
	body.physics_material_override = _block_pm
	var size := Vector3(b.x1 - b.x0, Level.BLOCK_DEPTH, Level.DEPTH)
	body.position = Vector3((b.x0 + b.x1) / 2.0, b.top - Level.BLOCK_DEPTH / 2.0, 0.0)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _block_mats[_built_count % 2]
	mi.mesh = bm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	add_child(body)
	b.node = body
	blocks.append(b)
	_built_count += 1


func _build_rocks() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("a993e6")
	mat.roughness = 1.0
	for i in 22:
		var sphere := SphereMesh.new()
		var r := randf_range(0.4, 1.6)
		sphere.radius = r
		sphere.height = r * 2.0
		sphere.radial_segments = 6
		sphere.rings = 3
		# Normales planas => look low-poly.
		var st := SurfaceTool.new()
		st.create_from(sphere, 0)
		st.deindex()
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(randf_range(-40.0, 40.0), randf_range(2.0, 20.0), randf_range(-48.0, -18.0))
		mi.rotation = Vector3(randf() * 3.0, randf() * 3.0, 0.0)
		mi.set_meta("spin", randf_range(-0.15, 0.15))
		add_child(mi)
		_rocks.append(mi)


## Crea una vez cada cosa del juego escondida adentro del piso (en cámara pero
## tapada): así el renderer compila sus shaders al arrancar y no hay un tirón
## la primera vez que aparece un avión, un cofre, etc.
func _prewarm() -> void:
	var holder := Node3D.new()
	holder.process_mode = Node.PROCESS_MODE_DISABLED # sin física ni lógica
	add_child(holder)
	holder.position = Vector3(Level.START.x + 3.0, -4.0, 0.0)
	for k in ["plain", "sword", "shield", "helmet"]:
		var e := Enemy.new()
		e.kind = k
		holder.add_child(e)
	holder.add_child(Boss.new())
	holder.add_child(Target.new())
	holder.add_child(Firefly.new())
	for k in ["hawk", "bat"]:
		var f := Flyer.new()
		f.kind = k
		holder.add_child(f)
	for n in [Airplane.new(), Rocket.new(), Chest.new(), Mimic.new(), Spring.new(), Pickup.new(), AmmoTag.new(), Fan.new(), Padlock.new(), Ufo.new(), Astronaut.new(), Booster.new(), Tub.new()]:
		holder.add_child(n)
	for i in 3:
		await get_tree().process_frame
	holder.queue_free()


# --- cielo de noche (arriba de todo) ---

func _build_stars() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 0.35)
	_stars_mat = StandardMaterial3D.new()
	_stars_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_stars_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_stars_mat.albedo_color = Color(1, 1, 1, 0)
	q.material = _stars_mat
	mm.mesh = q
	mm.instance_count = 260
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in mm.instance_count:
		var s := rng.randf_range(0.4, 1.3)
		var pos := Vector3(rng.randf_range(-90.0, 90.0), rng.randf_range(-110.0, 110.0), -150.0)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), pos))
	var stars := MultiMeshInstance3D.new()
	stars.multimesh = mm
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stars.visible = false
	stars.name = "Stars"
	camera.add_child(stars) # las estrellas van con la cámara (están "en el infinito")


func _update_space(p: Vector3, real_dt: float) -> void:
	var alt := p.y - Level.top_at(blocks, p.x)
	var goal := clampf((alt - (Config.ROCKET_ALT - Config.SPACE_FADE)) / Config.SPACE_FADE, 0.0, 1.0)
	space_t = lerpf(space_t, goal, 1.0 - exp(-real_dt * 2.0))
	var night := Color("05030c")
	_sky_mat.sky_top_color = _sky_day.top.lerp(night, space_t)
	_sky_mat.sky_horizon_color = _sky_day.hor.lerp(Color("120a24"), space_t)
	_sky_mat.ground_horizon_color = _sky_day.ghor.lerp(Color("120a24"), space_t)
	_sky_mat.ground_bottom_color = _sky_day.gbot.lerp(night, space_t)
	# nivel especial: el cielo toma su color (y en el apagón, todo a oscuras)
	var k := 1.0 - exp(-real_dt * 1.5)
	_tint_t = lerpf(_tint_t, 0.0 if special_zone.is_empty() else 1.0, k)
	_dark_t = lerpf(_dark_t, 1.0 if special_zone.get("kind", "") == "blackout" else 0.0, k)
	if _tint_t > 0.001:
		_sky_mat.sky_top_color = _sky_mat.sky_top_color.lerp(_tint.top, _tint_t)
		_sky_mat.sky_horizon_color = _sky_mat.sky_horizon_color.lerp(_tint.hor, _tint_t)
		_sky_mat.ground_horizon_color = _sky_mat.ground_horizon_color.lerp(_tint.hor, _tint_t)
		_sky_mat.ground_bottom_color = _sky_mat.ground_bottom_color.lerp(_tint.top, _tint_t)
	_env.ambient_light_energy = lerpf(0.3, 0.05, _dark_t)
	_sun.light_energy = lerpf(1.1, 0.0, _dark_t)
	_gun_lamp.light_energy = lerpf(0.0, 1.6, _dark_t)
	_gun_torch.light_energy = lerpf(0.0, 2.2, _dark_t)
	_flash_light.omni_range = lerpf(6.0, 13.0, _dark_t) # el fogonazo ilumina más lejos
	_stars_mat.albedo_color.a = smoothstep(0.3, 1.0, space_t)
	gun.gravity_scale = lerpf(1.0, Config.SPACE_GRAVITY, space_t) * gun.weight
	camera.get_node("Stars").visible = space_t > 0.05


# --- mirilla láser (poder) ---

func _build_laser() -> void:
	_laser = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, 0.03, 0.03)
	bm.material = _unshaded(Color(1.0, 0.15, 0.15, 0.7))
	_laser.mesh = bm
	_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_laser.visible = false
	add_child(_laser)


func _update_laser() -> void:
	var reach := Config.POWER_LASER_RANGE if power_on("laser") else (Config.SIGHT_RANGE if perks.has("sight") else 0.0)
	_laser.visible = reach > 0.0 and state != State.OVER and state != State.MARKET
	if not _laser.visible:
		return
	var from := gun.muzzle_position()
	var d := gun.barrel_dir()
	var to := from + Vector3(d.x, d.y, 0.0) * reach
	var hit := _raycast(from, to)
	if not hit.is_empty():
		to = hit.position
	var length := maxf(from.distance_to(to), 0.01)
	_laser.global_transform = Transform3D(Basis(Vector3.BACK, atan2(d.y, d.x)) * Basis.from_scale(Vector3(length, 1, 1)), (from + to) / 2.0)


# --- efectos (corren en tiempo de juego => se ven lentos en slow-mo) ---

func _unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	return m


func _fx_flash(at: Vector3) -> void:
	_flash_light.global_position = at + Vector3(0, 0, 0.6)
	_flash_light.light_energy = 6.0
	var m := _unshaded(Color("fff6d0"))
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	sm.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = at
	var tw := create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * 2.5, 0.08)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.08)
	tw.chain().tween_callback(mi.queue_free)


func _fx_puff(at: Vector3, color: Color, amount: int, life: float, heavy: bool) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 0.09
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	bm.material = m
	p.mesh = bm
	p.direction = Vector3.UP
	p.spread = 90.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -14.0 if heavy else -1.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	p.scale_amount_curve = c
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)
