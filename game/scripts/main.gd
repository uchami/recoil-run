extends Node3D
## Juego: arma el mundo, maneja disparos, reglas, cámara, slow-mo y efectos.

enum State { READY, PLAYING, OVER }

const FOV := 40.0
const VISIBLE_WIDTH := 8.5 # m visibles a lo ancho (pantallas verticales)
const MIN_VISIBLE_HEIGHT := 10.0 # m visibles a lo alto (pantallas horizontales)
const CAM_OFFSET := Vector3(-2.2, 1.3, 0.0) # vista 3/4 desde atrás y un poco arriba
const LOOK_AHEAD := 3.5
const GAP_CAM_LOOKAHEAD := 5.0 # a esta distancia del borde de un hueco la cámara empieza a alejarse
const GAP_CAM_MAX_WIDTH := 24.0 # ancho visible máximo al cruzar un hueco largo

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
var _sky_progress := 0.0 # metros recorridos (adelante o arriba) desde el último bicho
var _sky_next := 12.0
var _sky_last := Vector3.ZERO


func _ready() -> void:
	Engine.time_scale = 1.0
	Tuning.load_saved()
	_apply_gravity()
	Records.load_saved()
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

	_update_camera(1.0)


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
	if state == State.OVER:
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
	var dir3 := Vector3(d.x, d.y, 0.0)
	gun.fire(first)

	var hit := _raycast(from, from + dir3 * Config.BULLET_RANGE)
	var end := from + dir3 * Config.BULLET_RANGE
	var killed := false
	if not hit.is_empty():
		end = hit.position
		var c: Object = hit.collider
		if c and c.has_method("shot"):
			killed = _on_hit(c.shot(hit, d), end)
		else:
			_fx_puff(end, Color("55555f"), 8, 0.5, false)
	_fx_tracer(from, end)
	_fx_flash(from)
	kill_streak = kill_streak + 1 if killed else 0
	if _power_pending or streak >= Config.STREAK_FOR_POWER or kill_streak >= Config.STREAK_FOR_POWER:
		_power_pending = false
		grant_power(end)


## Lo que pueden pegar las balas: piso, personajes, cofres y bichos (áreas).
func _raycast(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, Config.L_TERRAIN | Config.L_ENEMY | Config.L_FLYER, [gun.get_rid()])
	q.hit_from_inside = true
	q.collide_with_areas = true
	return get_world_3d().direct_space_state.intersect_ray(q)


const KILL_RESULTS := ["headshot", "kill", "flyer_kill", "mimic_kill", "chest_kill", "plane_kill", "rocket_kill"]


## Aplica el resultado de un tiro. Devuelve true si mató algo.
func _on_hit(res: Dictionary, point: Vector3) -> bool:
	var reward: int = res.get("reward", 0)
	var above := point + Vector3(0, 0.4, 0)
	match res.get("result", ""):
		"headshot":
			kills += 1
			headshots += 1
			streak += 1
			_slowmo_left = Config.SLOWMO_DURATION
			Engine.time_scale = Config.SLOWMO_SCALE
			_fx_puff(point, Color("ff2a2a"), 18, 0.9, true)
			hud.popup_world(camera, above, "HEADSHOT! +%d" % reward, "headshot")
			sfx.play("headshot")
			sfx.play("slowmo", -6.0, 1.0, 0.0)
		"kill":
			kills += 1
			streak = 0
			_fx_puff(point, Color("ff2a2a"), 12, 0.9, true)
			hud.popup_world(camera, above, "+%d" % reward, "")
			sfx.play("kill")
		"blocked":
			_fx_puff(point, Color("ffe7a0"), 10, 0.35, false)
			hud.popup_world(camera, above, "¡CLANK!", "clank")
			sfx.play("clank")
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
		"trap_open":
			hud.popup_world(camera, above, "¡TRAMPA!", "hurt")
			sfx.play("chomp")
	if reward > 0:
		ammo += reward
		hud.bump_ammo()
	return res.get("result", "") in KILL_RESULTS


# --- daño, objetos y poderes (los llaman las cosas del mundo) ---

func power_on(power: String) -> bool:
	return powers.get(power, 0.0) > 0.0


## Un golpe: te saca balas (las balas son la vida). Sin balas, un golpe te mata.
## knock: velocidad nueva del arma (cero = no empuja); spin: giro que se suma.
func hurt(amount: int, from: Vector3, knock := Vector2.ZERO, spin := 0.0, _cause := "") -> void:
	if state != State.PLAYING or power_on("untouchable") or _hurt_cd > 0.0:
		return
	_hurt_cd = Config.HURT_COOLDOWN
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


func spawn_mimic(pos: Vector3) -> void:
	var m := Mimic.new()
	m.game = self
	add_child(m)
	m.global_position = pos
	entities.append(m)


# --- loop ---

func _physics_process(delta: float) -> void:
	if state == State.READY:
		_idle_angle += Config.IDLE_SPIN * delta
		_demo_autofire()
		var bob := sin(_time * 2.5) * 0.12
		gun.global_transform = Transform3D(Basis(Vector3.BACK, _idle_angle), Vector3(Level.START.x, Level.START.y + bob, 0.0))
	while _queued_shots > 0:
		_queued_shots -= 1
		shoot()


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
	if state == State.PLAYING:
		_sky_spawner(p)
	_hurt_cd -= real_dt
	for k in powers.keys():
		powers[k] -= real_dt
		if powers[k] <= 0.0:
			powers.erase(k)
			if k == "untouchable":
				gun.set_glow(null)
	_update_laser()
	if state == State.PLAYING:
		_check_game_over(real_dt, p)

	_flash_light.light_energy *= exp(-delta * 40.0)
	_update_camera(real_dt)
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


func _game_over(title: String) -> void:
	state = State.OVER
	_over_at_ms = Time.get_ticks_msec()
	sfx.play("game_over")
	powers.clear()
	gun.set_glow(null)
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
	var ty := maxf(p.y * 0.6 + ground * 0.4, ground) + 1.6
	var goal := Vector3(p.x + LOOK_AHEAD, ty, 0.0)
	var want_width := VISIBLE_WIDTH

	# Hueco adelante (o abajo): alejar y correr la cámara para que se vea dónde aterrizar.
	var landing := _landing_block(p.x)
	if not landing.is_empty() and landing.x0 - p.x < GAP_CAM_MAX_WIDTH * 1.5:
		var left := p.x - 1.5
		var right: float = landing.x0 + 2.5
		want_width = clampf(right - left, VISIBLE_WIDTH, GAP_CAM_MAX_WIDTH)
		goal.x = maxf(goal.x, minf((left + right) / 2.0, left + want_width / 2.0))
		goal.y = maxf((p.y + landing.top) / 2.0, minf(p.y, landing.top)) + 1.6

	_cam_width = lerpf(_cam_width, want_width, 1.0 - exp(-real_dt * 3.0))
	var dist := maxf(_cam_width / 2.0 / (t * aspect), MIN_VISIBLE_HEIGHT / 2.0 / t)
	_cam_target = _cam_target.lerp(goal, 1.0 - exp(-real_dt * 5.0))
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
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Ambiente de color fijo (no del cielo): con el cielo lavanda todo quedaba "quemado".
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9a8fc0")
	env.ambient_light_energy = 0.3
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)


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
		_add_block(b)
		for it in b.items:
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
	_spawn_item({"type": sky_type(p.y - Level.top_at(blocks, p.x)), "x": pos.x, "y": pos.y})


## Qué bicho toca según la altura sobre el piso.
func sky_type(_altitude: float) -> String:
	return "hawk" if randf() < 0.4 else "bat"


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
			return
		"ammo":
			spawn_pickup("ammo", pos, Vector3.ZERO, true)
			return
	var n: Node3D
	match it.type:
		"spring":
			n = Spring.new()
		"chest", "trap":
			var c := Chest.new()
			c.trap = it.type == "trap"
			n = c
		"hawk", "bat":
			var f := Flyer.new()
			f.kind = it.type
			n = f
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
	_laser.visible = power_on("laser") and state != State.OVER
	if not _laser.visible:
		return
	var from := gun.muzzle_position()
	var d := gun.barrel_dir()
	var to := from + Vector3(d.x, d.y, 0.0) * Config.POWER_LASER_RANGE
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


func _fx_tracer(a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	if length < 0.01:
		return
	var m := _unshaded(Color(1.0, 0.95, 0.69, 0.9))
	var bm := BoxMesh.new()
	bm.size = Vector3(length, 0.035, 0.035)
	bm.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = (a + b) / 2.0
	mi.rotation.z = atan2(b.y - a.y, b.x - a.x)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.1)
	tw.tween_callback(mi.queue_free)


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
