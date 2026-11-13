extends SceneTree
## Prueba headless del juego real (escena + física Jolt):
##   godot --headless --path . -s res://tests/smoke.gd

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	Tuning.save_path = "user://test_tuning.cfg" # no pisar los ajustes reales
	Tuning.reset(false) # valores por defecto, ignora lo guardado desde el panel
	Records.save_path = "user://test_save.cfg" # no pisar los récords reales
	Records.reset()
	# solo algunos tests: godot ... -s res://tests/smoke.gd -- test_boss_mole test_boss_wall
	var only := OS.get_cmdline_user_args()
	if not only.is_empty():
		for name in only:
			await call(name)
		print("SMOKE OK" if failures == 0 else "SMOKE FAIL (%d)" % failures)
		quit(1 if failures > 0 else 0)
		return
	await test_moon_airtime()
	await test_recoil_asymmetric()
	await test_headshot()
	await test_body_kill()
	await test_enemy_blocks_gun()
	await test_rests_on_sight()
	await test_ground_lift(0.0)
	await test_ground_lift(PI)
	await test_bounce()
	await test_air_lift()
	await test_game_over_no_ammo()
	test_level_generator()
	test_records()
	await test_game_over_saves_attempt()
	await test_world_streams()
	await test_fall_in_gap()
	await test_sounds()
	await test_shield_and_helmet()
	await test_sword()
	await test_spring()
	await test_air_spring()
	await test_sky_spawner()
	await test_altitude_zones()
	await test_plane()
	await test_fan()
	await test_padlock()
	await test_ufo()
	await test_booster()
	await test_astronaut()
	await test_special_chase()
	await test_special_gallery()
	await test_special_blackout()
	await test_special_ends_while_inside()
	await test_abduction()
	await test_special_boss()
	await test_boss_rotation()
	await test_boss_mole()
	await test_boss_zeppelin()
	await test_boss_wall()
	await test_boss_duel()
	await test_camera_follows_high_flight()
	await test_camera_gap_zoom_only_if_floor_visible()
	await test_camera_bot_gameplay()
	await test_rocket()
	await test_bat()
	await test_hawk()
	await test_chest()
	await test_safe_chests()
	await test_trap_chest()
	await test_chest_lost()
	await test_bullets_fly()
	await test_unseen_rule()
	await test_pierce()
	await test_market()
	await test_settings_panel()
	await test_dev_lock()
	await test_perks()
	await test_pierce_slowmo()
	await test_arrows()
	test_market_in_level()
	await test_market_air()
	await test_power_streak()
	await test_powers()
	await test_space_rewards()
	await test_combo()
	await test_retry_only_button()
	await test_hurt_without_ammo()
	await test_special_levels()
	await test_stress()
	print("SMOKE OK" if failures == 0 else "SMOKE FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)


# --- helpers ---

func spawn(level_seed := 1234) -> Node:
	Engine.time_scale = 1.0
	var m: Node = load("res://main.tscn").instantiate()
	m.level_seed = level_seed
	root.add_child(m)
	await physics_frame
	await physics_frame
	return m


func despawn(m: Node) -> void:
	Engine.time_scale = 1.0
	m.queue_free()
	await process_frame


func wait_s(s: float) -> void:
	await create_timer(s, true, false, true).timeout


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		print("  FAIL ", msg)


## Dispara desde la posición inicial con el cañón en el ángulo dado.
func shoot_from_start(m: Node, a: float) -> void:
	m._idle_angle = a - Config.IDLE_SPIN / float(Engine.physics_ticks_per_second)
	m._queued_shots = 1
	await physics_frame
	await physics_frame


## Pone el arma en juego, quieta, en una pose dada.
func place_gun(m: Node, pos: Vector2, a: float) -> void:
	m.state = m.State.PLAYING
	m.hud.hide_start()
	var g: Gun = m.gun
	g.freeze = false
	g.global_transform = Transform3D(Basis(Vector3.BACK, a), Vector3(pos.x, pos.y, 0))
	g.linear_velocity = Vector3.ZERO
	g.angular_velocity = Vector3.ZERO
	await physics_frame


func aim_angle(m: Node, target: Vector3) -> float:
	var p: Vector3 = m.gun.global_position
	return atan2(target.y - (p.y + Gun.MUZZLE.y), target.x - p.x)


# --- tests ---

func test_moon_airtime() -> void:
	print("vuelo lunar")
	var m := await spawn()
	m.enemies.map(func(e): e.queue_free())
	m.enemies.clear()
	await place_gun(m, Vector2(-3.0, 2.4), -PI / 2.0) # cañón al piso, en el aire
	m._queued_shots = 1
	await physics_frame
	var t0 := Time.get_ticks_msec()
	var peak := 0.0
	while not m.gun.grounded and Time.get_ticks_msec() - t0 < 6000:
		peak = maxf(peak, m.gun.global_position.y)
		await physics_frame
	var airtime := (Time.get_ticks_msec() - t0) / 1000.0
	check(airtime > 2.0, "tiempo en el aire de un salto: %.2fs (antes ~1s)" % airtime)
	check(peak < 9.0, "altura máxima razonable para la cámara: %.1fm" % peak)
	await despawn(m)


func test_recoil_asymmetric() -> void:
	print("retroceso asimétrico")
	var m := await spawn()
	m.enemies.map(func(e): e.queue_free())
	m.enemies.clear()
	await shoot_from_start(m, 0.0) # cañón hacia adelante
	var back_vx: float = m.gun.linear_velocity.x
	await despawn(m)
	m = await spawn()
	await shoot_from_start(m, PI) # cañón hacia atrás
	var fwd_vx: float = m.gun.linear_velocity.x
	var r: float = Tuning.values.recoil_speed
	check(back_vx < -0.5, "disparar adelante empuja atrás (vx=%.2f)" % back_vx)
	check(fwd_vx > r * 0.9, "disparar atrás empuja adelante (vx=%.2f)" % fwd_vx)
	check(absf(back_vx) < fwd_vx * 0.6, "empuje hacia atrás es menor (%.2f vs %.2f)" % [absf(back_vx), fwd_vx])
	check(m.ammo == Config.START_AMMO - 1, "gasta una bala (%d)" % m.ammo)
	await despawn(m)


func test_headshot() -> void:
	print("headshot")
	var m := await spawn()
	var e: Enemy = m.enemies[0]
	await shoot_from_start(m, aim_angle(m, e.global_position + Vector3(0, Enemy.HEAD_Y, 0)))
	await bullets_done(m)
	check(not e.alive, "personaje muerto")
	check(m.headshots == 1, "cuenta headshot")
	check(m.ammo == Config.START_AMMO - 1 + Config.HEADSHOT_REWARD, "balas +%d (%d)" % [Config.HEADSHOT_REWARD, m.ammo])
	await wait_s(0.2)
	check(Engine.time_scale < 0.5, "slow-mo activo (%.2f)" % Engine.time_scale)
	var y0: float = e.global_position.y
	await wait_s(1.2)
	check(is_equal_approx(Engine.time_scale, 1.0), "slow-mo terminó")
	check(not is_instance_valid(e) or e.global_position.y != y0 or e.rotation.z != 0.0, "el cuerpo se movió (ragdoll)")
	await despawn(m)


func test_body_kill() -> void:
	print("kill al cuerpo")
	var m := await spawn()
	var e: Enemy = m.enemies[0]
	await shoot_from_start(m, aim_angle(m, e.global_position + Vector3(0, 0.8, 0)))
	await bullets_done(m)
	check(not e.alive, "personaje muerto")
	check(m.headshots == 0, "no es headshot")
	check(m.ammo == Config.START_AMMO - 1 + Config.KILL_REWARD, "balas +%d (%d)" % [Config.KILL_REWARD, m.ammo])
	check(is_equal_approx(Engine.time_scale, 1.0), "sin slow-mo")
	await despawn(m)


func test_enemy_blocks_gun() -> void:
	print("el arma choca con los personajes")
	var m := await spawn()
	var e: Enemy = m.enemies[0]
	# Arma a la altura del pecho, cañón hacia atrás => sale disparada hacia el personaje.
	# Sin lift en el aire, para que vaya derecho al cuerpo y no le pase por arriba.
	Tuning.values.air_lift = 0.0
	await place_gun(m, Vector2(1.5, 1.0), PI)
	m._queued_shots = 1
	await wait_s(1.5)
	var gx: float = m.gun.global_position.x
	Tuning.reset(false)
	check(e.alive, "el personaje sigue vivo")
	check(gx < e.global_position.x, "el arma no lo atravesó (arma x=%.2f, personaje x=%.2f)" % [gx, e.global_position.x])
	await despawn(m)


## Ángulo respecto de la horizontal, en grados (0 = plana).
func tilt_deg(g: Gun) -> float:
	var a := absf(wrapf(g.angle(), -PI / 2.0, PI / 2.0))
	return rad_to_deg(a)


func test_rests_on_sight() -> void:
	print("dada vuelta se apoya en la mirilla (física real, sin enderezado)")
	var m := await spawn()
	await place_gun(m, Vector2(-3.0, 0.5), PI) # corredera hacia abajo
	await wait_s(3.0)
	var g: Gun = m.gun
	check(g.linear_velocity.length() < 0.3, "quedó quieta (v=%.2f)" % g.linear_velocity.length())
	check(tilt_deg(g) > 2.0, "no queda plana: inclinada %.1f°" % tilt_deg(g))
	check(absf(g.angle()) > PI / 2.0, "sigue dada vuelta, nadie la enderezó (%.0f°)" % rad_to_deg(g.angle()))
	await despawn(m)


func test_ground_lift(start_angle: float) -> void:
	print("disparo apoyada en el piso => lift (ángulo inicial %.0f°)" % rad_to_deg(start_angle))
	var m := await spawn()
	await place_gun(m, Vector2(-3.0, 0.5), start_angle)
	await wait_s(3.0)
	var g: Gun = m.gun
	check(g.grounded, "está apoyada")
	m._queued_shots = 1
	await physics_frame
	await physics_frame
	check(g.linear_velocity.y >= Tuning.values.ground_lift * 0.9 and g.linear_velocity.y < Tuning.values.ground_lift * 1.3, "el tiro la levanta (vy=%.2f)" % g.linear_velocity.y)
	await despawn(m)


func test_bounce() -> void:
	print("rebote")
	var m := await spawn()
	await place_gun(m, Vector2(-3.0, 3.0), 0.0)
	var max_up := 0.0
	var touched := false
	for i in 240:
		await physics_frame
		touched = touched or m.gun.grounded
		if touched:
			max_up = maxf(max_up, m.gun.linear_velocity.y)
	check(max_up > 1.0, "rebota contra el piso (vy máx después del golpe %.2f)" % max_up)
	await despawn(m)


func test_air_lift() -> void:
	print("lift en el aire: todo tiro levanta")
	for a in [0.0, PI, PI / 2.0]: # cañón adelante, atrás y hacia arriba
		var m := await spawn()
		await place_gun(m, Vector2(-3.0, 4.0), a)
		m.gun.linear_velocity = Vector3(0, -8.0, 0) # cayendo
		m._queued_shots = 1
		await physics_frame
		await physics_frame
		var vy: float = m.gun.linear_velocity.y
		check(vy >= Tuning.values.air_lift * 0.9, "cañón a %.0f°, cayendo: el tiro levanta (vy=%.2f)" % [rad_to_deg(a), vy])
		await despawn(m)


func test_game_over_no_ammo() -> void:
	print("game over sin balas")
	var m := await spawn()
	await place_gun(m, Vector2(-3.0, 0.6), 0.0)
	m.ammo = 0
	await wait_s(4.0)
	check(m.state == m.State.OVER, "terminó la partida")
	await despawn(m)


func test_stress() -> void:
	print("estrés: 120 disparos")
	var m := await spawn()
	m.ammo = 9999
	var ok := true
	for i in 120:
		m._queued_shots = 1
		await wait_s(0.12)
		if m.state == m.State.OVER:
			break
		var p: Vector3 = m.gun.global_position
		var blk := Level.block_at(m.blocks, p.x)
		var floor_y: float = blk.top if not blk.is_empty() else -INF # en un hueco puede caer
		if not p.is_finite() or p.y < floor_y - 0.3:
			ok = false
			print("    pos rara: ", p, " piso ", floor_y)
			break
	check(ok, "sin NaN ni atravesar el piso (distancia %dm)" % m.distance)
	await despawn(m)


func test_level_generator() -> void:
	print("generador del piso")
	var lv := Level.new(7)
	var bs := []
	while bs.is_empty() or bs[-1].x1 < 3000.0:
		bs.append(lv.next_block())
	var gaps := 0
	var max_gap := 0.0
	var max_up := 0.0
	var max_down := 0.0
	var heights := {}
	var enemy_xs := []
	var types := {}
	var specials := {}
	for i in bs.size():
		var b: Dictionary = bs[i]
		heights[snappedf(b.top, 0.5)] = true
		specials[b.special] = true
		for it in b.items:
			types[it.type] = types.get(it.type, 0) + 1
			if b.special != "": # los niveles especiales tienen su test
				continue
			enemy_xs.append(it.x)
			if it.x < b.x0 + 0.5 or it.x > b.x1 - 0.5 or it.y != b.top:
				check(false, "%s fuera del bloque en x=%.1f" % [it.type, it.x])
		if i > 0 and b.special == "" and bs[i - 1].special == "": # el piso normal
			var gap: float = b.x0 - bs[i - 1].x1
			if gap > 0.01:
				gaps += 1
			max_gap = maxf(max_gap, gap)
			max_up = maxf(max_up, b.top - bs[i - 1].top)
			max_down = maxf(max_down, bs[i - 1].top - b.top)
	var b0: Dictionary = bs[0]
	check(b0.top == 0.0 and b0.items.map(func(it): return it.x) == Level.ENEMY_XS and b0.items.all(func(it): return it.type == "plain"), "el arranque es fijo: piso plano y los 3 personajes")
	check(bs[1].x0 == b0.x1, "no hay hueco pegado al arranque")
	check(gaps > 30, "hay huecos (%d en 3km)" % gaps)
	check(max_gap <= Level.GAP_LEN.y + Level.GAP_RAMP_MAX + 0.01, "huecos cruzables (máx %.1fm)" % max_gap)
	check(heights.size() >= 20, "alturas variadas (%d niveles distintos)" % heights.size())
	check(max_up <= Level.MAX_STEP_UP + 0.01, "paredes trepables (máx %.1fm)" % max_up)
	check(max_down <= Level.MAX_STEP_DOWN + 0.01, "bajadas acotadas (máx %.1fm)" % max_down)
	var min_sep := INF
	for i in range(1, enemy_xs.size()):
		min_sep = minf(min_sep, enemy_xs[i] - enemy_xs[i - 1])
	check(enemy_xs.size() > 150, "personajes infinitos (%d en 3km)" % enemy_xs.size())
	check(min_sep >= 2.0, "espaciados (mínimo %.1fm entre dos)" % min_sep)
	var fan_xs := []
	for b in bs:
		for it in b.items:
			if it.type == "fan":
				fan_xs.append(it.x)
	check(fan_xs.size() >= 3 and fan_xs.size() < 40, "ventiladores: pocos (%d en 3km)" % fan_xs.size())
	check(fan_xs.all(func(x): return x > Config.FAN_FROM), "ventiladores solo pasados los %dm" % Config.FAN_FROM)
	for t in ["plain", "sword", "shield", "helmet", "chest", "trap", "spring"]:
		check(types.get(t, 0) > 0, "aparece %s (%d)" % [t, types.get(t, 0)])
	var total_chests: int = types.get("chest", 0) + types.get("trap", 0)
	check(types.get("trap", 0) < total_chests * 0.6, "trampas: la minoría (%d de %d)" % [types.get("trap", 0), total_chests])
	for sp in Level.SPECIALS:
		check(specials.has(sp), "aparece el nivel %s" % sp)
	var other := Level.new(99)
	other.next_block()
	var lv2 := Level.new(99)
	lv2.next_block()
	check(other.next_block().top == lv2.next_block().top, "misma semilla => mismo piso")


func test_world_streams() -> void:
	print("el mundo se genera adelante y se libera atrás")
	var m := await spawn()
	var start_blocks: int = m.blocks.size()
	await place_gun(m, Vector2(500.0, 8.0), 0.0)
	await process_frame
	await process_frame
	var last: Dictionary = m.blocks[-1]
	check(last.x1 > 500.0 + m.GEN_AHEAD - 1.0, "hay piso generado por delante (hasta x=%.0f)" % last.x1)
	check(m.blocks[0].x1 > 500.0 - m.KEEP_BEHIND - 15.0, "lo de atrás se liberó (primer bloque termina en x=%.0f)" % m.blocks[0].x1)
	check(m.blocks.size() < 40, "cantidad de bloques acotada (%d)" % m.blocks.size())
	var ahead := 0
	for e in m.enemies:
		if is_instance_valid(e) and e.global_position.x > 500.0:
			ahead += 1
	check(ahead >= 3, "hay personajes por delante (%d)" % ahead)
	await despawn(m)


func test_fall_in_gap() -> void:
	print("caer en un hueco => game over")
	var m := await spawn()
	var gap_x := 0.0
	for i in range(1, m.blocks.size()):
		if m.blocks[i].x0 - m.blocks[i - 1].x1 > 1.0:
			gap_x = (m.blocks[i].x0 + m.blocks[i - 1].x1) / 2.0
			break
	check(gap_x > 0.0, "hay un hueco cerca del arranque (x=%.1f)" % gap_x)
	await place_gun(m, Vector2(gap_x, 3.0), -PI / 2.0)
	await wait_s(4.0)
	check(m.state == m.State.OVER, "terminó la partida al caer")
	await despawn(m)


func test_records() -> void:
	print("récords y leaderboard")
	Records.reset()
	var r1 := Records.add({"dist": 100, "height": 5, "ammo": 9, "kills": 1, "headshots": 0})
	var r2 := Records.add({"dist": 300, "height": 3, "ammo": 7, "kills": 2, "headshots": 1})
	var r3 := Records.add({"dist": 50, "height": 12, "ammo": 4, "kills": 0, "headshots": 0})
	check(r1.rank == 1 and r2.rank == 1 and r3.rank == 3, "rank por distancia (%d, %d, %d)" % [r1.rank, r2.rank, r3.rank])
	check(Records.attempts.map(func(a): return a.dist) == [300, 100, 50], "leaderboard ordenado por distancia")
	check(Records.best.dist == 300 and Records.best.height == 12 and Records.best.ammo == 9, "récords por separado: dist 300, altura 12, balas 9")
	check(r3.new.height and not r3.new.dist and not r3.new.ammo, "marca solo el récord nuevo (altura)")
	Records.load_saved(true)
	check(Records.attempts.size() == 3 and Records.best.height == 12, "persiste en disco")
	for i in 30:
		Records.add({"dist": i, "height": 0, "ammo": 0, "kills": 0, "headshots": 0})
	check(Records.attempts.size() == Records.MAX_ATTEMPTS, "guarda como máximo %d intentos" % Records.MAX_ATTEMPTS)
	check(Records.best.dist == 300, "el récord no se pierde al recortar la lista")
	Records.reset()


func test_game_over_saves_attempt() -> void:
	print("game over guarda el intento")
	Records.reset()
	var m := await spawn()
	await place_gun(m, Vector2(-3.0, 6.0), 0.0)
	m.ammo = 0
	m.max_ammo = 8
	await wait_s(7.0) # rebota un rato; a los 6 s sin balas termina igual
	check(m.state == m.State.OVER, "terminó la partida")
	check(Records.attempts.size() == 1, "quedó guardado")
	var a: Dictionary = Records.attempts[0] if Records.attempts.size() > 0 else {}
	check(a.get("height", 0) >= 5, "altura máxima registrada (%dm)" % a.get("height", 0))
	check(a.get("ammo", 0) == 8, "balas máximas registradas (%d)" % a.get("ammo", 0))
	check(m.hud._over.visible and m.hud._over_board.get_child_count() >= 8, "game over muestra el leaderboard")
	await despawn(m)
	Records.reset()


# --- mecánicas nuevas ---

func clear_world(m: Node) -> void:
	for e in m.enemies + m.entities:
		if is_instance_valid(e):
			e.queue_free()
	m.enemies.clear()
	m.entities.clear()


## seen: ya apareció en pantalla (si no, la regla del motor no deja matarlo).
func put(m: Node, type: String, x: float, y := 0.0, seen := true) -> Node:
	m._spawn_item({"type": type, "x": x, "y": y})
	var n: Node = m.enemies[-1] if type in ["plain", "sword", "shield", "helmet"] else m.entities[-1]
	if seen:
		n.set_meta("seen", true)
	return n


## Espera a que terminen las balas en vuelo (las balas no son instantáneas).
func bullets_done(m: Node) -> void:
	var t0 := Time.get_ticks_msec()
	while not m.bullets.is_empty() and Time.get_ticks_msec() - t0 < 3000:
		await physics_frame


## Pone el arma quieta en pos apuntando a target y dispara en el mismo paso.
func fire_at(m: Node, pos: Vector2, target: Vector3) -> void:
	if m.state != m.State.PLAYING:
		await place_gun(m, pos, 0.0)
	var g: Gun = m.gun
	var a := atan2(target.y - (pos.y + Gun.MUZZLE.y), target.x - pos.x)
	g.global_transform = Transform3D(Basis(Vector3.BACK, a), Vector3(pos.x, pos.y, 0))
	g.linear_velocity = Vector3.ZERO
	g.angular_velocity = Vector3.ZERO
	m._queued_shots = 1
	await physics_frame
	await physics_frame
	await bullets_done(m)


func test_sounds() -> void:
	print("sonidos")
	var m := await spawn()
	check(m.sfx._streams.size() == Sfx.NAMES.size(), "cargan todos los sonidos (%d/%d)" % [m.sfx._streams.size(), Sfx.NAMES.size()])
	await shoot_from_start(m, 0.0)
	check("shot" in m.sfx.played, "suena el disparo")
	await despawn(m)


func test_shield_and_helmet() -> void:
	print("escudo y casco")
	var m := await spawn()
	clear_world(m)
	await physics_frame
	var e: Enemy = put(m, "shield", 4.0)
	await physics_frame
	await fire_at(m, Vector2(-1.0, 0.9), e.global_position + Vector3(0, 0.8, 0))
	check(e.alive, "escudo: el tiro al torso rebota")
	check("clank" in m.sfx.played, "suena clank")
	await fire_at(m, Vector2(-1.0, 1.7), e.global_position + Vector3(0, Enemy.HEAD_Y, 0))
	check(not e.alive and m.headshots == 1, "escudo: a la cabeza lo mata (headshot)")
	await despawn(m)

	m = await spawn()
	clear_world(m)
	await physics_frame
	e = put(m, "helmet", 4.0)
	await physics_frame
	await fire_at(m, Vector2(-1.0, 1.7), e.global_position + Vector3(0, Enemy.HEAD_Y, 0))
	check(e.alive, "casco: el tiro a la cabeza rebota")
	await fire_at(m, Vector2(-1.0, 0.9), e.global_position + Vector3(0, 0.8, 0))
	check(not e.alive and m.headshots == 0, "casco: al torso lo mata")
	await despawn(m)


func test_sword() -> void:
	print("espadachín")
	var m := await spawn()
	clear_world(m)
	await physics_frame
	var e: Enemy = put(m, "sword", 4.0)
	m.ammo = 5
	await place_gun(m, Vector2(3.0, 0.6), 0.0) # al lado del espadachín
	var t0 := Time.get_ticks_msec()
	while m.ammo == 5 and Time.get_ticks_msec() - t0 < 1500:
		await physics_frame
	check(m.ammo == 4, "te pega: -1 bala (%d)" % m.ammo)
	await physics_frame
	await physics_frame
	check(m.gun.linear_velocity.x < -1.0, "te empuja lejos (vx=%.1f)" % m.gun.linear_velocity.x)
	check("hurt" in m.sfx.played, "suena el golpe")
	await despawn(m)


func test_spring() -> void:
	print("resorte vertical")
	var res := []
	for speed in [3.0, 9.0]:
		var m := await spawn()
		clear_world(m)
		await physics_frame
		put(m, "spring", 4.0)
		await place_gun(m, Vector2(1.0, 1.3), 0.0)
		m.gun.linear_velocity = Vector3(speed, 0.0, 0.0)
		var min_vx := 0.0
		var max_spin := -1.0
		for i in 90:
			await physics_frame
			min_vx = minf(min_vx, m.gun.linear_velocity.x)
			if max_spin < 0.0 and m.gun.linear_velocity.x < -1.0: # justo después del choque
				max_spin = absf(m.gun.angular_velocity.z)
		check(min_vx < -Config.SPRING_BASE_PUSH, "choque a %.0f m/s: te devuelve (vx=%.1f)" % [speed, min_vx])
		check(m.gun.global_position.x < 3.0, "no lo atravesás (x=%.1f)" % m.gun.global_position.x)
		res.append([min_vx, max_spin])
		await despawn(m)
	check(res[1][0] < res[0][0] - 3.0, "choque fuerte empuja más (%.1f vs %.1f)" % [res[1][0], res[0][0]])
	check(res[1][1] > res[0][1] + 3.0, "choque fuerte te hace girar más (%.1f vs %.1f rad/s)" % [res[1][1], res[0][1]])


func test_air_spring() -> void:
	print("resorte flotando")
	var m := await spawn()
	clear_world(m)
	await physics_frame
	put(m, "spring_air", 4.0, 10.0)
	await place_gun(m, Vector2(1.0, 10.0), 0.0)
	m.gun.linear_velocity = Vector3(8.0, 0.0, 0.0)
	var min_vx := 0.0
	for i in 60:
		await physics_frame
		min_vx = minf(min_vx, m.gun.linear_velocity.x)
	check(min_vx < -Config.SPRING_BASE_PUSH, "en el aire también te devuelve (vx=%.1f)" % min_vx)
	await despawn(m)


func test_sky_spawner() -> void:
	print("bichos a cualquier altura")
	var m := await spawn()
	clear_world(m)
	await place_gun(m, Vector2(0.0, 30.0), 0.0)
	var ys := []
	for i in 400: # vuela hacia adelante a 30 m de altura
		m.gun.global_position = Vector3(i * 0.25, 30.0, 0.0)
		m.gun.linear_velocity = Vector3.ZERO
		await process_frame
	for n in m.entities:
		if is_instance_valid(n) and (n is Flyer or n is Airplane or n is Rocket):
			ys.append(n.global_position.y)
	check(m.sky_spawned >= 5, "aparecen bichos mientras avanzás (%d en 100 m)" % m.sky_spawned)
	check(ys.all(func(y): return y > 25.0), "a tu altura, no en el piso (%s)" % str(ys.map(func(y): return snappedf(y, 0.1))))
	await despawn(m)


func test_bat() -> void:
	print("murciélago")
	var m := await spawn()
	clear_world(m)
	await physics_frame
	var b: Flyer = put(m, "bat", 0.0, 4.0)
	m.ammo = 5
	await place_gun(m, Vector2(b.global_position.x, b.global_position.y), 0.0)
	for i in 30: # lo seguimos hasta chocarlo (revolotea)
		if not b.alive:
			break
		m.gun.global_position = b.global_position
		m.gun.linear_velocity = Vector3.ZERO
		await physics_frame
	check(m.ammo == 4, "si te choca: -1 bala (%d)" % m.ammo)
	check(not b.alive, "y se muere")
	await despawn(m)
	m = await spawn()
	clear_world(m)
	await physics_frame
	b = put(m, "bat", 5.0, 3.0)
	await physics_frame
	await fire_at(m, Vector2(0.0, 3.0), b.global_position)
	check(not b.alive, "se lo puede matar de un tiro")
	check(m.ammo == Config.START_AMMO - 1 + Config.FLYER_REWARD, "da +%d" % Config.FLYER_REWARD)
	await despawn(m)


func test_hawk() -> void:
	print("halcón")
	var m := await spawn()
	clear_world(m)
	await physics_frame
	var h: Flyer = put(m, "hawk", 8.0, 6.0)
	await place_gun(m, Vector2(0.0, 2.0), 0.0)
	await physics_frame
	var seen: Vector3 = m.gun.global_position
	await wait_s(0.5)
	check(h._dir != Vector3.ZERO, "te ve y arranca")
	var dir: Vector3 = h._dir
	var expected := Vector3(seen.x - 8.0, seen.y - 6.0, 0).normalized()
	check(dir.dot(expected) > 0.97, "va hacia donde te vio (dot %.2f)" % dir.dot(expected))
	var p0 := h.global_position
	await wait_s(1.0)
	var v := (h.global_position - p0).length()
	check(v < Config.HAWK_SPEED * 1.3 and v > Config.HAWK_SPEED * 0.6, "lento (%.1f m/s)" % v)
	await despawn(m)
	# golpe: -1 bala y te hace girar
	m = await spawn()
	clear_world(m)
	await physics_frame
	h = put(m, "hawk", 2.0, 3.0)
	m.ammo = 5
	await place_gun(m, Vector2(0.0, 3.0), 0.0)
	var spun := 0.0
	var t0 := Time.get_ticks_msec()
	while m.ammo == 5 and Time.get_ticks_msec() - t0 < 2500:
		m.gun.global_position = Vector3(0.0, 3.0, 0.0) # lo esperamos quietos
		m.gun.linear_velocity = Vector3.ZERO
		await physics_frame
	await physics_frame
	await physics_frame
	spun = absf(m.gun.angular_velocity.z)
	check(m.ammo == 4, "si te toca: -1 bala (%d)" % m.ammo)
	check(spun > Config.HAWK_SPIN * 0.5, "te hace girar (%.1f rad/s)" % spun)
	await despawn(m)


func chest_lock(c: Chest) -> Vector3:
	return c.global_position + Chest.LOCK_POS


func test_chest() -> void:
	print("cofre con candado")
	var outcomes := {"balas": 0, "poder": 0}
	for k in 8:
		var m := await spawn()
		clear_world(m)
		await physics_frame
		var c: Chest = put(m, "chest", 6.0)
		await physics_frame
		if k == 0:
			await fire_at(m, Vector2(-1.0, 3.4), c.global_position + Vector3(0, 3.4, 0)) # a la madera
			check(not c.opened and is_instance_valid(c), "un tiro al cofre no le hace nada")
			check(Chest.world_size().x >= 4.9, "es grande (%.1f m de ancho)" % Chest.world_size().x)
		var before: int = m.ammo - 1
		m.last_power = ""
		var lock := chest_lock(c)
		await fire_at(m, Vector2(-1.0, lock.y - 0.1), lock)
		if k == 0:
			check(c.opened, "un tiro al candado lo abre")
			check(not m.entities.any(func(n): return is_instance_valid(n) and n is Mimic), "no es trampa")
		if m.last_power != "":
			outcomes.poder += 1
		elif m.ammo == before + Config.CHEST_REWARD:
			outcomes.balas += 1
		Engine.time_scale = 1.0
		await despawn(m)
	check(outcomes.balas + outcomes.poder == 8, "siempre da algo: %s" % str(outcomes))
	check(outcomes.balas > 0 and outcomes.poder > 0, "a veces balas, a veces poder")


func test_chest_lost() -> void:
	print("cofre perdido (te chocaste el candado)")
	var m := await spawn()
	clear_world(m)
	await physics_frame
	var c: Chest = put(m, "chest", 6.0)
	await physics_frame
	var lock := chest_lock(c)
	await place_gun(m, Vector2(lock.x - 0.1, lock.y), 0.0)
	for i in 30:
		if c.lost:
			break
		m.gun.global_position = Vector3(lock.x - 0.1, lock.y, 0.0)
		m.gun.linear_velocity = Vector3.ZERO
		await physics_frame
	check(c.lost, "el cofre se pierde")
	check(m.power_on("locked") and m.gun.get_node_or_null("Lock") != null, "el candado se te pega (pesás más)")
	await wait_s(1.5)
	check(not is_instance_valid(c), "el cofre se enterró")
	await despawn(m)


func test_safe_chests() -> void:
	print("los primeros %d cofres nunca son trampa" % Config.SAFE_CHESTS)
	Records.reset()
	var mimics := 0
	for k in Config.SAFE_CHESTS + 1:
		var m := await spawn()
		clear_world(m)
		await physics_frame
		var c: Chest = put(m, "trap", 6.0) # todos trampa...
		await physics_frame
		var lock := chest_lock(c)
		await fire_at(m, Vector2(-1.0, lock.y - 0.1), lock)
		await physics_frame
		var opened: bool = m.entities.any(func(n): return is_instance_valid(n) and n is Mimic)
		if k < Config.SAFE_CHESTS:
			mimics += 1 if opened else 0
		else:
			check(opened, "el cofre nº %d ya puede ser trampa" % (k + 1))
		Engine.time_scale = 1.0
		await despawn(m)
	check(mimics == 0, "...pero los primeros %d no muerden (%d mordieron)" % [Config.SAFE_CHESTS, mimics])
	check(Records.stat("chests_killed") == Config.SAFE_CHESTS + 1, "cuenta guardada en el teléfono (%d)" % Records.stat("chests_killed"))
	Records.load_saved(true)
	check(Records.stat("chests_killed") == Config.SAFE_CHESTS + 1, "y sobrevive a reiniciar el juego")
	Records.reset()


func test_trap_chest() -> void:
	print("cofre trampa")
	Records.stats["chests_killed"] = Config.SAFE_CHESTS # ya mató los primeros
	var m := await spawn()
	clear_world(m)
	await physics_frame
	var c: Chest = put(m, "trap", 8.0)
	await physics_frame
	var lock := chest_lock(c)
	await fire_at(m, Vector2(-1.0, lock.y - 0.1), lock)
	await physics_frame
	var mimics: Array = m.entities.filter(func(n): return is_instance_valid(n) and n is Mimic)
	check(mimics.size() == 1, "al abrirlo abre la boca (mimic)")
	if mimics.is_empty():
		await despawn(m)
		return
	var mm: Mimic = mimics[0]
	mm.set_meta("seen", true)
	var d0: float = mm.global_position.distance_to(m.gun.global_position)
	m.ammo = 6
	var hold: Vector3 = m.gun.global_position
	for i in 120: # 1 s con el arma quieta
		m.gun.global_position = hold
		m.gun.linear_velocity = Vector3.ZERO
		await physics_frame
	var d1: float = mm.global_position.distance_to(m.gun.global_position)
	check(d1 < d0 - Config.MIMIC_SPEED * 0.7 or m.eaten, "te persigue (%.1f -> %.1f m)" % [d0, d1])
	Records.set_stat("insurance", 1) # ni el seguro te salva
	var t0 := Time.get_ticks_msec()
	while m.state == m.State.PLAYING and Time.get_ticks_msec() - t0 < 6000:
		if not m.eaten:
			m.gun.global_position = hold
			m.gun.linear_velocity = Vector3.ZERO
		await physics_frame
	check(m.eaten and mm._chomped, "si te quedás quieto, te mete en la boca y la cierra")
	check(m.state == m.State.OVER and m.hud._over_title.text == "¡TE COMIÓ!", "y perdés la partida, aunque tengas seguro (%s)" % m.hud._over_title.text)
	check(Records.stat("insurance") == 1, "(el seguro no se gasta)")
	Records.set_stat("insurance", 0)
	await despawn(m)
	# rozarlo de costado (la madera): -2 y te empuja
	m = await spawn()
	clear_world(m)
	await place_gun(m, Vector2(0.0, 1.0), 0.0)
	m.spawn_mimic(Vector3(4.0, 0.0, 0.0))
	mm = m.entities[-1]
	mm.set_meta("seen", true)
	await physics_frame
	mm.set_physics_process(false)
	m.ammo = 6
	m.gun.freeze = true
	m.gun.global_position = mm.global_position + Vector3(0, 1.0, 0) # a la altura de la mandíbula
	mm._bite_cd = 0.0
	mm.set_physics_process(true)
	for i in 20:
		if m.ammo != 6 or m.eaten:
			break
		m.gun.global_position = mm.global_position + Vector3(0, 1.0, 0)
		await physics_frame
	check(m.ammo == 6 - Config.MIMIC_DAMAGE and not m.eaten, "si te roza la madera: -%d balas (%d)" % [Config.MIMIC_DAMAGE, m.ammo])
	await despawn(m)
	# te come aunque tengas balas: no tiene que ver con la vida
	m = await spawn()
	clear_world(m)
	await place_gun(m, Vector2(0.0, 1.0), 0.0)
	m.spawn_mimic(Vector3(4.0, 0.0, 0.0))
	mm = m.entities[-1]
	await physics_frame
	m.ammo = 50
	m.gun.freeze = true
	m.gun.global_position = mm.mouth_position()
	await physics_frame
	await physics_frame
	check(m.eaten, "con 50 balas también te come")
	await despawn(m)
	m = await spawn()
	clear_world(m)
	m.spawn_mimic(Vector3(8.0, 0.0, 0.0))
	mm = m.entities[-1]
	mm.set_meta("seen", true)
	await physics_frame
	# matarlo: un tiro a la boca, te da 5; en la madera rebota
	m.ammo = 10
	m._hurt_cd = 99.0
	m.gun.global_position = mm.global_position + Vector3(-9.0, 0, 0)
	mm.global_position.y = 0.0
	await physics_frame
	mm.set_physics_process(false) # quieto para apuntar justo
	mm._set_facing(-1.0)
	await physics_frame
	var gp := Vector2(mm.global_position.x - 9.0, 1.0)
	await fire_at(m, gp, mm.global_position + Vector3(-1.0, 0.8, 0))
	check(mm.alive and m.ammo == 9, "tiro a la madera (abajo): no le hace nada")
	await fire_at(m, Vector2(gp.x, 3.0), mm.mouth_position())
	check(not mm.alive, "tiro a la boca: muere")
	check(m.ammo == 8 + Config.MIMIC_REWARD, "te da %d balas (%d)" % [Config.MIMIC_REWARD, m.ammo])
	await despawn(m)


## Dispara una secuencia: "h" = headshot, "b" = kill al cuerpo, "m" = tiro errado.
## Devuelve en qué tiro (1-based) se aplicó un poder, o 0.
func shoot_sequence(seq: String) -> int:
	var m := await spawn()
	clear_world(m)
	await physics_frame
	var got := 0
	for i in seq.length():
		var k := seq[i]
		m.last_power = ""
		if k == "m":
			await fire_at(m, Vector2(0.0, 3.0), Vector3(10.0, 12.0, 0.0)) # al cielo
		else:
			var e: Enemy = put(m, "plain", 4.0 + i * 1.2)
			await physics_frame
			var target := e.global_position + (Vector3(0, Enemy.HEAD_Y, 0) if k == "h" else Vector3(0, 0.7, 0))
			await fire_at(m, Vector2(0.0, target.y), target)
		Engine.time_scale = 1.0
		m._slowmo_left = 0.0
		if m.last_power != "" and got == 0:
			got = i + 1
	await despawn(m)
	return got


func test_power_streak() -> void:
	print("rachas => poder automático")
	check(await shoot_sequence("hhh") == 3, "3 headshots seguidos: poder al 3º")
	check(await shoot_sequence("hmhmh") == 5, "la racha de headshots perdona los tiros errados")
	check(await shoot_sequence("hbmhh") == 0, "un kill al cuerpo corta la racha de headshots")
	check(await shoot_sequence("bbb") == 3, "3 kills en 3 tiros: poder al 3º")
	check(await shoot_sequence("bbmb") == 0, "la racha de kills no perdona los errados")
	check(await shoot_sequence("hhhhh") == 3, "al dar un poder se reinician las rachas (no da otro al 4º/5º)")
	var m := await spawn()
	check(m.entities.all(func(n): return not (is_instance_valid(n) and n is Pickup)), "no hay que recogerlo: se aplica solo")
	await despawn(m)


func test_powers() -> void:
	print("poderes")
	var m := await spawn()
	await place_gun(m, Vector2(-3.0, 3.0), 0.0)
	m.ammo = 2
	m._activate_power("infinite", Vector3.ZERO)
	for i in 4:
		m._queued_shots = 1
		await physics_frame
	check(m.ammo == 2, "balas infinitas: no gasta (%d)" % m.ammo)
	m._activate_power("laser", Vector3.ZERO)
	await process_frame
	await process_frame
	check(m._laser.visible, "láser visible")
	var a: int = m.ammo
	m._activate_power("ammo15", Vector3.ZERO)
	check(m.ammo == a + 15, "+15 balas")
	m._activate_power("untouchable", Vector3.ZERO)
	var b: int = m.ammo
	m._hurt_cd = 0.0
	m.hurt(2, Vector3.ZERO)
	check(m.ammo == b, "intocable: no te sacan balas")
	m.powers.infinite = 0.01
	await wait_s(0.1)
	check(not m.power_on("infinite"), "los poderes se terminan")
	await despawn(m)


## Combo: la racha de kills en pantalla ("COMBO x2", "COMBO x3") con su sonido.
func test_combo() -> void:
	print("combo")
	var m := await spawn()
	clear_world(m)
	await physics_frame
	var hud: Hud = m.hud
	for i in 3:
		var e: Enemy = put(m, "plain", 4.0 + i * 1.2)
		await physics_frame
		m.sfx.played.clear()
		await fire_at(m, Vector2(0.0, 0.7), e.global_position + Vector3(0, 0.7, 0))
		match i:
			0:
				check(not hud._combo.visible, "1 kill: no se muestra (x1)")
			1:
				check(hud._combo.visible and hud._combo.text == "COMBO x2" and "combo2" in m.sfx.played, "2 kills seguidos: COMBO x2 con sonido (%s)" % hud._combo.text)
			2:
				check(hud._combo.visible and hud._combo.text == "COMBO x3" and "combo3" in m.sfx.played, "3 kills seguidos: COMBO x3 con otro sonido (%s)" % hud._combo.text)
				check(m.last_power != "" and m.kill_streak == 0, "y da el poder (la racha vuelve a 0)")
	await wait_s(Config.COMBO_PRIZE_SHOW + 0.3)
	check(not hud._combo.visible, "el COMBO x3 queda un ratito y se va")
	# x2 y un tiro errado: se pierde
	m.powers.clear()
	for i in 2:
		var e: Enemy = put(m, "plain", 4.0 + i * 1.2)
		await physics_frame
		await fire_at(m, Vector2(0.0, 0.7), e.global_position + Vector3(0, 0.7, 0))
	check(hud._combo.visible and hud._combo.text == "COMBO x2", "queda en pantalla mientras dura")
	await wait_s(0.5)
	check(hud._combo.visible, "(no se borra solo)")
	await fire_at(m, Vector2(0.0, 3.0), Vector3(10.0, 12.0, 0.0)) # al cielo
	check(not hud._combo.visible, "un tiro errado: se pierde el combo y se va el cartel")
	await despawn(m)


## Game over: solo el botón OTRA VEZ reinicia (tocar afuera no hace nada).
func test_retry_only_button() -> void:
	print("reiniciar solo con el botón")
	var m := await spawn()
	await place_gun(m, Vector2(-3.0, 3.0), 0.0)
	m._game_over("SIN BALAS")
	m._over_at_ms -= 2000
	await process_frame
	var btn: Button = m.hud._over.find_children("*", "Button", true, false)[0]
	# un toque fuera del botón llega al juego como input sin manejar
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = Vector2(30.0, 30.0)
		m._unhandled_input(ev)
	await process_frame
	check(m.state == m.State.OVER and not m.restarting, "tocar fuera del botón no reinicia")
	var blockers: Array = m.hud._over.find_children("*", "Control", true, false).filter(func(c): return c != btn and c.mouse_filter == Control.MOUSE_FILTER_STOP)
	check(btn.mouse_filter == Control.MOUSE_FILTER_STOP and blockers.is_empty(), "el botón es lo único que agarra el toque en esa pantalla (%d)" % blockers.size())
	btn.pressed.emit()
	await process_frame
	check(m.restarting, "tocar OTRA VEZ reinicia")
	await despawn(m)


func test_hurt_without_ammo() -> void:
	print("golpe sin balas = muerte")
	var m := await spawn()
	await place_gun(m, Vector2(-3.0, 3.0), 0.0)
	m.ammo = 1
	m.hurt(1, Vector3.ZERO)
	check(m.ammo == 0 and m.state == m.State.PLAYING, "con 1 bala: quedás en 0 pero vivo")
	m._hurt_cd = 0.0
	m.hurt(1, Vector3.ZERO)
	check(m.state == m.State.OVER, "sin balas: el golpe te mata")
	await despawn(m)


func test_altitude_zones() -> void:
	print("zonas por altura")
	var m := await spawn()
	var counts := {}
	for alt in [5.0, 30.0, 60.0, 100.0]:
		var c := {}
		for i in 2000: # (muchas: que el azar no dé vuelta las proporciones)
			var t: String = m.sky_type(alt)
			c[t] = c.get(t, 0) + 1
		counts[alt] = c
	for alt in counts:
		check(counts[alt].has("spring_air"), "a %.0fm también hay resortes flotando (%d de 2000)" % [alt, counts[alt].get("spring_air", 0)])
		counts[alt].erase("spring_air")
		check(counts[alt].has("padlock"), "a %.0fm también hay candados" % alt)
		counts[alt].erase("padlock")
	check(counts[5.0].keys().all(func(k): return k in ["hawk", "bat"]), "abajo: halcones y murciélagos %s" % str(counts[5.0]))
	check(counts[30.0].has("plane") and counts[30.0].has("hawk") and not counts[30.0].has("rocket"), "alto: aviones con halcones %s" % str(counts[30.0]))
	check(counts[60.0].has("rocket") and counts[60.0].has("plane") and not counts[60.0].has("hawk") and not counts[60.0].has("bat"), "más alto: cohetes con aviones, sin pájaros %s" % str(counts[60.0]))
	check(counts[60.0].get("astronaut", 0) > counts[60.0].get("rocket", 0), "donde hay cohetes hay astronautas, y muchos %s" % str(counts[60.0]))
	check(counts[100.0].has("ufo") and counts[100.0].has("astronaut") and counts[100.0].has("rocket") and not counts[100.0].has("plane"), "más alto todavía: ovnis, astronautas y cohetes, sin aviones %s" % str(counts[100.0]))
	# cielo de noche
	await place_gun(m, Vector2(0.0, 2.0), 0.0)
	await wait_s(0.3)
	check(m.space_t < 0.05, "abajo el cielo es violeta (%.2f)" % m.space_t)
	check(is_equal_approx(m.gun.gravity_scale, 1.0), "abajo, gravedad normal")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		m.gun.global_position = Vector3(0.0, Config.ROCKET_ALT + 10.0, 0.0)
		m.gun.linear_velocity = Vector3.ZERO
		await process_frame
	check(m.space_t > 0.9, "arriba de todo: negro con estrellas (%.2f)" % m.space_t)
	check(m.camera.get_node("Stars").visible, "se ven las estrellas")
	check(absf(m.gun.gravity_scale - Config.SPACE_GRAVITY) < 0.05, "en el espacio hay menos gravedad (x%.2f)" % m.gun.gravity_scale)
	await despawn(m)


func test_plane() -> void:
	print("avión")
	var m := await spawn()
	clear_world(m)
	await physics_frame
	var pl: Airplane = put(m, "plane", 12.0, 3.0)
	m.ammo = 10
	m._hurt_cd = 99.0
	await fire_at(m, Vector2(8.0, 0.5), pl.global_position + Vector3(0.5, 0, 0)) # de abajo, a la panza
	check(pl.alive, "a la panza: rebota")
	check("clank" in m.sfx.played, "suena clank")
	m.ammo = 10
	await fire_at(m, Vector2(0.0, pl.global_position.y - 0.1), pl.global_position + Vector3(Airplane.PROP_X, 0, 0))
	check(not pl.alive, "un tiro a la hélice lo derriba")
	check(m.ammo == 10 - 1 + Config.PLANE_REWARD, "te da %d balas (%d)" % [Config.PLANE_REWARD, m.ammo])
	check("explosion" in m.sfx.played, "explota")
	check(Config.PLANE_SPEED <= 4.0, "vuela despacio (%.1f m/s)" % Config.PLANE_SPEED)
	await despawn(m)
	m = await spawn()
	clear_world(m)
	await physics_frame
	pl = put(m, "plane", 4.0, 3.0)
	m.ammo = 10
	await place_gun(m, Vector2(0.0, 3.0), 0.0)
	var t0 := Time.get_ticks_msec()
	while m.ammo == 10 and Time.get_ticks_msec() - t0 < 3000:
		m.gun.global_position = Vector3(0.0, 3.0, 0.0)
		m.gun.linear_velocity = Vector3.ZERO
		await physics_frame
	check(m.ammo == 10 - Config.PLANE_DAMAGE, "si te choca: -%d balas (%d)" % [Config.PLANE_DAMAGE, m.ammo])
	await despawn(m)


func test_rocket() -> void:
	print("cohete")
	var m := await spawn()
	clear_world(m)
	await physics_frame
	var r: Rocket = put(m, "rocket", 14.0, 8.0)
	m.ammo = 10
	await place_gun(m, Vector2(0.0, 3.0), 0.0)
	var seen: Vector3 = m.gun.global_position
	var t0 := Time.get_ticks_msec()
	while m.ammo == 10 and Time.get_ticks_msec() - t0 < 3000:
		m.gun.global_position = seen
		m.gun.linear_velocity = Vector3.ZERO
		await physics_frame
	check(m.ammo == 10 - Config.ROCKET_DAMAGE, "va hacia vos y explota: -%d balas (%d)" % [Config.ROCKET_DAMAGE, m.ammo])
	check(not is_instance_valid(r) or not r.alive, "el cohete explotó")
	check("explosion" in m.sfx.played, "suena la explosión")
	await despawn(m)
	m = await spawn()
	clear_world(m)
	await physics_frame
	r = put(m, "rocket", 30.0, 3.0) # lejos: todavía no te vio
	await fire_at(m, Vector2(0.0, 3.0), r.global_position)
	check(not is_instance_valid(r) or not r.alive, "un tiro lo explota")
	check(m.ammo == Config.START_AMMO - 1 + Config.ROCKET_REWARD, "+%d" % Config.ROCKET_REWARD)
	await despawn(m)


func test_fan() -> void:
	print("ventilador")
	var m := await spawn()
	clear_world(m)
	await physics_frame
	put(m, "fan", 3.0)
	await place_gun(m, Vector2(3.0, 1.0), 0.0)
	var peak := 0.0
	var spawned := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		peak = maxf(peak, m.gun.global_position.y)
		if peak < Config.ROCKET_ALT - 3.0: # durante la subida
			spawned = m.entities.filter(func(n): return is_instance_valid(n) and (n is Flyer or n is Airplane or n is Rocket)).size()
		if absf(m.gun.linear_velocity.y) < 0.5 and peak > 10.0:
			break # llegó arriba
		await physics_frame
	check(absf(peak - Config.ROCKET_ALT) < 2.5, "te sube justo hasta donde empiezan los cohetes (%.1f m)" % peak)
	check(spawned == 0, "la subida es limpia: no aparecen bichos en el camino (%d)" % spawned)
	check(absf(m.gun.global_position.x - 3.0) < Config.FAN_WIDTH, "te mantiene en la columna (x=%.1f)" % m.gun.global_position.x)
	await despawn(m)


## Dónde se ve el arma en pantalla, en fracción (0..1) del ancho y alto.
func gun_on_screen(m: Node) -> Vector2:
	var vp: Vector2 = m.get_viewport().get_visible_rect().size
	var sp: Vector2 = m.camera.unproject_position(m.gun.global_position)
	return Vector2(sp.x / vp.x, sp.y / vp.y)


func in_view(f: Vector2) -> bool:
	return f.x > 0.03 and f.x < 0.97 and f.y > 0.05 and f.y < 0.95 # adentro, sin tocar los bordes


func test_camera_follows_high_flight() -> void:
	print("cámara: vuelo a distintas alturas cruzando huecos")
	for alt in [2.0, 8.0, 15.0, 30.0, 60.0]:
		var m := await spawn(31)
		await place_gun(m, Vector2(0.0, 2.0 + alt), 0.0)
		m.gun.freeze = true
		var worst := Vector2(0.5, 0.5)
		var worst_d := 0.0
		var bad := 0
		var x := 0.0
		var gaps := 0
		var was_gap := false
		while x < 220.0:
			x += 7.0 / 60.0
			var ground := Level.top_at(m.blocks, x)
			m.gun.global_position = Vector3(x, ground + alt, 0.0)
			await process_frame
			var is_gap := Level.block_at(m.blocks, x).is_empty()
			if is_gap and not was_gap:
				gaps += 1
			was_gap = is_gap
			if x < 10.0:
				continue # que la cámara se acomode
			var f := gun_on_screen(m)
			if not in_view(f):
				bad += 1
			var d := (f - Vector2(0.5, 0.5)).length()
			if d > worst_d:
				worst_d = d
				worst = f
		check(bad == 0, "a %.0fm sobre el piso: el arma siempre en pantalla (%d cuadros afuera, peor %.2f,%.2f, %d huecos)" % [alt, bad, worst.x, worst.y, gaps])
		await despawn(m)


## Un bot que juega de verdad (física real): toca cuando el cañón apunta hacia
## atrás-abajo, para volar hacia adelante y para arriba. Balas infinitas.
func test_camera_gap_zoom_only_if_floor_visible() -> void:
	print("cámara: zoom de hueco solo si el piso se ve")
	var res := {}
	for alt in [2.0, 40.0]:
		var m := await spawn(31)
		await place_gun(m, Vector2(0.0, 2.0 + alt), 0.0)
		m.gun.freeze = true
		var max_w := 0.0
		var x := 0.0
		while x < 220.0:
			x += 7.0 / 60.0
			m.gun.global_position = Vector3(x, Level.top_at(m.blocks, x) + alt, 0.0)
			await process_frame
			max_w = maxf(max_w, m._cam_width)
		res[alt] = max_w
		await despawn(m)
	check(res[2.0] > m_visible_width() + 3.0, "volando bajo, los huecos sacan zoom (ancho máx %.1fm)" % res[2.0])
	check(res[40.0] < m_visible_width() + 0.5, "volando alto, no (ancho máx %.1fm)" % res[40.0])


func m_visible_width() -> float:
	return 8.5


func test_camera_bot_gameplay() -> void:
	print("cámara: bot jugando en altura")
	var m := await spawn(31)
	clear_world(m)
	m.ammo = 9999
	m._hurt_cd = 9999.0
	await place_gun(m, Vector2(0.0, 3.0), 0.0)
	var bad := 0
	var top_edge := 0
	var climbing := 0
	var frames := 0
	var max_alt := 0.0
	var t0 := Time.get_ticks_msec()
	var last_shot := 0
	while Time.get_ticks_msec() - t0 < 20000 and m.state == m.State.PLAYING:
		await physics_frame
		var g: Gun = m.gun
		var a := g.angle()
		var alt: float = g.global_position.y - Level.top_at(m.blocks, g.global_position.x)
		max_alt = maxf(max_alt, alt)
		var want_up := alt < 35.0
		# cañón hacia atrás y abajo => adelante y arriba (más vertical si quiere subir)
		var target := deg_to_rad(-95.0 if want_up else -140.0)
		if absf(wrapf(a - target, -PI, PI)) < 0.4 and (g.linear_velocity.y < 1.0 or want_up) and Time.get_ticks_msec() - last_shot > 120:
			m._queued_shots = 1
			last_shot = Time.get_ticks_msec()
		m.ammo = 9999
		frames += 1
		var f := gun_on_screen(m)
		if not in_view(f):
			bad += 1
		if g.linear_velocity.y > 3.0 and alt > 5.0:
			climbing += 1
			if f.y < 0.3:
				top_edge += 1
	check(frames > 600, "jugó %d cuadros (llegó a %.0fm de altura, %dm de distancia)" % [frames, max_alt, m.distance])
	check(max_alt > 25.0, "voló alto (%.0fm)" % max_alt)
	check(bad < frames * 0.01, "el arma en pantalla todo el tiempo (%d de %d cuadros afuera)" % [bad, frames])
	check(top_edge < climbing * 0.2, "subiendo, el arma no queda pegada arriba: se ve lo que viene (%d de %d cuadros en el 30%% de arriba)" % [top_edge, climbing])
	await despawn(m)


func test_padlock() -> void:
	print("candado")
	var m := await spawn()
	clear_world(m)
	await physics_frame
	var pl: Padlock = put(m, "padlock", 8.0, 3.0)
	m.ammo = 10
	await fire_at(m, Vector2(0.0, 3.0), pl.global_position)
	check(not pl.alive, "muere de un tiro")
	check(m.ammo == 10 - 1 + Config.PADLOCK_REWARD, "te da %d balas (%d)" % [Config.PADLOCK_REWARD, m.ammo])
	await despawn(m)
	# si te toca: se pega y pesás más
	m = await spawn()
	clear_world(m)
	await physics_frame
	pl = put(m, "padlock", 0.0, 4.0)
	await place_gun(m, Vector2(0.0, 4.0), 0.0)
	for i in 30:
		if m.power_on("locked"):
			break
		m.gun.global_position = pl.global_position if is_instance_valid(pl) else m.gun.global_position
		m.gun.linear_velocity = Vector3.ZERO
		await physics_frame
	check(m.power_on("locked"), "si te toca, se te pega")
	check(m.gun.get_node_or_null("Lock") != null, "se ve el candado en el arma")
	await process_frame
	await process_frame
	check(m.gun.gravity_scale > 1.9, "el arma pesa el doble (gravedad x%.1f)" % m.gun.gravity_scale)
	m.powers.locked = 0.01
	await wait_s(0.2)
	check(not m.power_on("locked") and m.gun.gravity_scale < 1.01, "a los %ds se suelta" % Config.LOCK_TIME)
	await despawn(m)


func test_ufo() -> void:
	print("ovni")
	var m := await spawn()
	clear_world(m)
	await physics_frame
	var u: Ufo = put(m, "ufo", 8.0, 6.0)
	m.ammo = 20
	await place_gun(m, Vector2(0.0, 3.0), 0.0)
	var hold := Vector3(0.0, 3.0, 0.0)
	var t0 := Time.get_ticks_msec()
	while u.fired == 0 and Time.get_ticks_msec() - t0 < 4000: # quieto: te da
		m.gun.global_position = hold
		m.gun.linear_velocity = Vector3.ZERO
		await physics_frame
	check(u.fired == 1, "te apunta y dispara")
	check(m.ammo == 20 - Config.UFO_DAMAGE, "si te da el láser: -%d balas (%d)" % [Config.UFO_DAMAGE, m.ammo])
	check("laser" in m.sfx.played, "suena el láser")
	# esquivarlo: moverse durante el aviso
	m.ammo = 20
	m._hurt_cd = 0.0
	t0 = Time.get_ticks_msec()
	while u._aim_left < 0.0 and Time.get_ticks_msec() - t0 < 4000:
		m.gun.global_position = hold
		m.gun.linear_velocity = Vector3.ZERO
		await physics_frame
	check(u._aim_left >= 0.0, "antes de disparar, avisa (línea finita)")
	while u._aim_left >= 0.0:
		m.gun.global_position = hold + Vector3(0, 3.0, 0) # me corrí
		m.gun.linear_velocity = Vector3.ZERO
		await physics_frame
	check(m.ammo == 20, "si te movés durante el aviso, lo esquivás (%d)" % m.ammo)
	u.set_physics_process(false) # quieto para apuntar justo
	m.ammo = 20
	var gp := Vector2(u.global_position.x - 7.0, u.global_position.y - 0.4)
	await fire_at(m, gp, u.global_position + Vector3(0, -0.05, 0))
	check(u.alive, "tiro al plato: rebota")
	await fire_at(m, Vector2(gp.x, gp.y + 0.6), u.dome_position())
	check(not u.alive, "tiro a la cúpula: muere de un tiro")
	check(m.ammo == 18 + Config.UFO_REWARD, "te da %d balas (%d)" % [Config.UFO_REWARD, m.ammo])
	await despawn(m)
	# te persigue: si vas más despacio que él, te sigue
	m = await spawn()
	clear_world(m)
	await physics_frame
	u = put(m, "ufo", 8.0, 6.0)
	await place_gun(m, Vector2(0.0, 3.0), 0.0)
	m.powers.untouchable = 99.0
	var gx := 0.0
	var top_speed := 0.0
	var prev: Vector3 = u._anchor
	for i in 480: # 4 s avanzando a 3.5 m/s
		gx += 3.5 / 120.0
		m.gun.global_position = Vector3(gx, 3.0, 0.0)
		m.gun.linear_velocity = Vector3.ZERO
		await physics_frame
		top_speed = maxf(top_speed, u._anchor.distance_to(prev) * 120.0)
		prev = u._anchor
	var d: float = u.global_position.distance_to(m.gun.global_position)
	check(not u.leaving and d < 9.0, "avanzaste despacio y te siguió (a %.1f m)" % d)
	check(top_speed <= Config.UFO_MAX_SPEED + 0.05 and top_speed < Tuning.values.recoil_speed, "nunca va más rápido que %.1f m/s (menos que un disparo: %.1f) (%.2f)" % [Config.UFO_MAX_SPEED, Tuning.values.recoil_speed, top_speed])
	# no reacciona al instante: si arrancás de golpe, tarda en acelerar
	u._anchor = m.gun.global_position + Vector3(Config.UFO_HOVER.x, Config.UFO_HOVER.y, 0.0)
	u.vel = Vector3.ZERO
	u._seen_gun = m.gun.global_position
	var a0: Vector3 = u._anchor
	for i in 30: # 0.25 s: vos a 8 m/s
		gx += 8.0 / 120.0
		m.gun.global_position = Vector3(gx, 3.0, 0.0)
		await physics_frame
	check(u._anchor.x - a0.x < 0.5, "arrancás de golpe y tarda en reaccionar (se movió %.2f m, vos 2 m)" % (u._anchor.x - a0.x))
	# se pasa de largo: si te frenás de golpe, sigue un poco (inercia)
	u._anchor = m.gun.global_position + Vector3(Config.UFO_HOVER.x - 3.0, Config.UFO_HOVER.y, 0.0)
	u.vel = Vector3(Config.UFO_MAX_SPEED, 0, 0)
	u._seen_gun = m.gun.global_position + Vector3(4.0, 0, 0)
	u._cd = 99.0
	var max_x: float = u._anchor.x
	for i in 480:
		m.gun.global_position = Vector3(gx, 3.0, 0.0) # quieta
		await physics_frame
		max_x = maxf(max_x, u._anchor.x)
	var hover_x: float = gx + Config.UFO_HOVER.x
	check(max_x > hover_x + 0.8 and absf(u._anchor.x - hover_x) < 1.0, "con inercia: se pasa de largo y vuelve (llegó a +%.1f m de su lugar)" % (max_x - hover_x))
	m.gun.global_position = Vector3(gx, 300.0, 0.0)
	await physics_frame
	await physics_frame
	check(u.leaving, "si lo dejás muy lejos, se va")
	# esquivarlo avanzando: si vas impulsada (más rápido que él), lo dejás atrás y te pierde
	clear_world(m)
	await physics_frame
	await place_gun(m, Vector2(0.0, 3.0), 0.0)
	u = put(m, "ufo", 5.0, 6.0)
	gx = 0.0
	var lost_at := -1.0
	for i in 1200: # hasta 10 s a 7 m/s (lo que te empuja un disparo)
		gx += 7.0 / 120.0
		m.gun.global_position = Vector3(gx, 3.0, 0.0)
		m.gun.linear_velocity = Vector3.ZERO
		await physics_frame
		if u.leaving:
			lost_at = gx
			break
	var ran: float = (u._anchor - u._spawn).length()
	check(lost_at > 0.0 and ran < Config.UFO_CHASE_DIST, "avanzando impulsada lo dejás atrás y te pierde (a los %.0f m; él recorrió %.0f)" % [lost_at, ran])
	# no te persigue para siempre: después de UFO_CHASE_DIST se rinde
	clear_world(m)
	await physics_frame
	await place_gun(m, Vector2(0.0, 3.0), 0.0)
	u = put(m, "ufo", 5.0, 6.0)
	u._spawn.x -= Config.UFO_CHASE_DIST - 12.0 # (como si ya te viniera persiguiendo)
	gx = 0.0
	var gave_up_at := -1.0
	for i in 1200: # 3.5 m/s: te sigue
		gx += 3.5 / 120.0
		m.gun.global_position = Vector3(gx, 3.0, 0.0)
		m.gun.linear_velocity = Vector3.ZERO
		await physics_frame
		if u.leaving:
			gave_up_at = (u._anchor - u._spawn).length()
			break
	check(gave_up_at > Config.UFO_CHASE_DIST - 1.0 and gave_up_at < Config.UFO_CHASE_DIST + 2.0, "se rinde después de recorrer %d m (%.0f)" % [Config.UFO_CHASE_DIST, gave_up_at])
	# no más de UFO_MAX a la vez
	clear_world(m)
	for i in Config.UFO_MAX:
		put(m, "ufo", gx + 10.0 + i * 3.0, 90.0)
	m.state = m.State.PLAYING
	var types := {}
	for i in 40:
		m._sky_progress = 999.0
		m._sky_last = m.gun.global_position
		m.gun.global_position = Vector3(gx, 95.0, 0.0)
		var n0: int = m.entities.size()
		m._sky_spawner(m.gun.global_position)
		for e in m.entities.slice(n0):
			types[e.get_class() if e.get_script() == null else e.get_script().get_global_name()] = true
	check(not types.has("Ufo"), "con %d ovnis persiguiéndote no aparecen más %s" % [Config.UFO_MAX, str(types.keys())])
	await despawn(m)


func test_astronaut() -> void:
	print("astronauta")
	var m := await spawn()
	clear_world(m)
	await physics_frame
	var a: Astronaut = put(m, "astronaut", 8.0, 3.0)
	a._spin = 0.0
	m.ammo = 10
	await fire_at(m, Vector2(0.0, 2.8), a.global_position + Vector3(0, -0.3, 0))
	check(not a.alive, "muere de un tiro (al cuerpo)")
	check(m.ammo == 10 - 1 + Config.KILL_REWARD and m.headshots == 0, "al cuerpo: +%d, como los del piso (%d)" % [Config.KILL_REWARD, m.ammo])
	a = put(m, "astronaut", 8.0, 6.0)
	a._spin = 0.0
	m.ammo = 10
	var head := a.head_position()
	await fire_at(m, Vector2(0.0, head.y - 0.1), head)
	check(not a.alive and m.headshots == 1, "al casco: headshot")
	check(m.ammo == 10 - 1 + Config.HEADSHOT_REWARD, "headshot: +%d (%d)" % [Config.HEADSHOT_REWARD, m.ammo])
	Engine.time_scale = 1.0
	m._slowmo_left = 0.0
	await despawn(m)
	# vienen en grupito
	m = await spawn()
	clear_world(m)
	await place_gun(m, Vector2(0.0, 3.0), 0.0)
	var before: int = m.entities.size()
	seed(3)
	for i in 30:
		m._sky_progress = 999.0
		m._sky_last = Vector3.ZERO
		var n0: int = m.entities.size()
		m._sky_spawner(Vector3(0.0, Config.ROCKET_ALT + 5.0, 0.0))
		if m.entities.size() - n0 > 1:
			break
	check(m.entities.size() - before > 1, "a la altura de los cohetes ya hay astronautas, en grupito")
	await despawn(m)
	m = await spawn()
	clear_world(m)
	await physics_frame
	a = put(m, "astronaut", 0.0, 4.0)
	m.ammo = 10
	await place_gun(m, Vector2(0.0, 4.0), 0.0)
	for i in 20:
		m.gun.global_position = a.global_position
		await physics_frame
	check(m.ammo == 10 - Config.ASTRONAUT_DAMAGE, "si te choca: -%d (%d)" % [Config.ASTRONAUT_DAMAGE, m.ammo])
	await despawn(m)


func test_booster() -> void:
	print("cohete propulsor")
	var lv := Level.new(7)
	var boosters := []
	var bs := [lv.next_block()]
	while bs[-1].x1 < 8000.0:
		bs.append(lv.next_block())
	for b in bs:
		for it in b.items:
			if it.type == "booster":
				boosters.append(it.x)
	check(boosters.size() >= 2, "aparece, poco (%d en 8km)" % boosters.size())
	check(boosters.all(func(x): return x > Config.BOOSTER_FROM), "solo pasados los %dm" % Config.BOOSTER_FROM)

	Level.debug_special = "booster"
	var m := await spawn()
	var bx := 0.0
	var by := 0.0
	for b in m.blocks:
		for it in b.items:
			if it.type == "booster":
				bx = it.x
				by = it.y
	check(bx > 0.0, "PROBAR COHETE lo pone apenas termina el arranque (x=%.0f)" % bx)
	clear_world(m)
	await physics_frame
	put(m, "booster", bx, by)
	await place_gun(m, Vector2(bx, by + 2.0), 0.0)
	var peak := 0.0
	var spawned := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000:
		await physics_frame
		peak = maxf(peak, m.gun.global_position.y - by)
		if peak < Config.BOOSTER_DROP_ALT - 5.0:
			spawned = m.sky_spawned
		if m.gun.linear_velocity.y < 0.0 and peak > 20.0:
			break
	check(peak > Config.BOOSTER_DROP_ALT - 2.0, "te lleva directo al espacio (%.0fm sobre el piso)" % peak)
	check(peak < Config.BOOSTER_DROP_ALT + 8.0, "y te suelta ahí arriba (no sigue)")
	check(spawned == 0, "viaje limpio (%d bichos en el camino)" % spawned)
	check(m.state == m.State.PLAYING, "sigue la partida")
	await despawn(m)


# --- balas que vuelan, regla de pantalla, penetrantes, mercado ---

func test_bullets_fly() -> void:
	print("las balas vuelan (no son instantáneas)")
	var m := await spawn()
	clear_world(m)
	await physics_frame
	var e: Enemy = put(m, "plain", 7.0)
	await physics_frame
	await place_gun(m, Vector2(-1.0, 0.9), 0.0)
	var g: Gun = m.gun
	var target := e.global_position + Vector3(0, 0.8, 0)
	g.global_transform = Transform3D(Basis(Vector3.BACK, atan2(target.y - (0.9 + Gun.MUZZLE.y), target.x + 1.0)), Vector3(-1.0, 0.9, 0))
	m._queued_shots = 1
	await physics_frame
	check(m.bullets.size() == 1, "sale una bala")
	check(e.alive, "todavía no llegó")
	var frames := 0
	while not m.bullets.is_empty() and frames < 200:
		await physics_frame
		frames += 1
	check(not e.alive, "llega y lo mata")
	check(frames >= 8, "tarda en llegar (%d cuadros para ~8 m)" % frames)
	await despawn(m)


func test_unseen_rule() -> void:
	print("no se puede matar lo que todavía no apareció en pantalla")
	var m := await spawn()
	clear_world(m)
	await physics_frame
	await place_gun(m, Vector2(0.0, 3.0), 0.0)
	var far: Padlock = put(m, "padlock", 30.0, 3.0, false) # fuera de pantalla
	await process_frame
	check(not m.camera.is_position_in_frustum(far.global_position), "está fuera de pantalla")
	await fire_at(m, Vector2(0.0, 3.0), far.global_position)
	check(far.alive, "la bala le pasa de largo")
	var near: Padlock = put(m, "padlock", 5.0, 3.0, false) # en pantalla
	await process_frame
	await fire_at(m, Vector2(0.0, 3.0), near.global_position)
	check(not near.alive, "lo que está en pantalla, sí")
	await despawn(m)


func test_pierce() -> void:
	print("balas penetrantes")
	for pierce in [false, true]:
		var m := await spawn()
		clear_world(m)
		await physics_frame
		m.pierce = pierce
		var row := []
		for i in 5:
			row.append(put(m, "plain", 3.0 + i * 1.2))
		await physics_frame
		await fire_at(m, Vector2(0.0, 0.9), Vector3(8.0, 0.9, 0.0))
		var dead: int = row.filter(func(e): return not e.alive).size()
		if pierce:
			check(dead == Config.PIERCE_KILLS, "penetrante: mata %d en fila de un tiro (%d)" % [Config.PIERCE_KILLS, dead])
		else:
			check(dead == 1, "normal: mata uno (%d)" % dead)
		await despawn(m)


## Ajustes de desarrollo: bloqueados por defecto, 7 toques al título en < 3 s los
## desbloquean (y queda guardado), el mismo gesto los vuelve a esconder.
func test_dev_lock() -> void:
	print("ajustes bloqueados / gesto secreto")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Tuning.save_path))
	Tuning.load_saved(true)
	check(not Tuning.dev_unlocked, "sin guardado: bloqueados por defecto")
	var m := await spawn()
	var hud = m.hud
	check(not hud._tune_open.visible, "bloqueado: no se ve el botón AJUSTES")
	hud._tune_open.pressed.emit()
	check(not hud._tune_panel.visible, "bloqueado: el panel no abre")
	Tuning.set_value("gravity", 20.0)
	check(is_equal_approx(Tuning.values.gravity, Tuning.DEFAULTS.gravity), "bloqueado: no se puede cambiar la física")
	var lvl := Level.debug_special
	hud.test_level.emit("chest")
	check(Level.debug_special == lvl and not m.restarting, "bloqueado: PROBAR NIVEL no hace nada")
	# gesto lento o incompleto: no desbloquea
	for i in 6:
		hud.title_tap(100000 + i * 100)
	check(not Tuning.dev_unlocked, "6 toques no alcanzan")
	for i in 7:
		hud.title_tap(200000 + i * 600) # 3.6 s en total
	check(not Tuning.dev_unlocked, "7 toques en más de 3 s no alcanzan")
	hud._title_taps.clear()
	# toques de verdad (como llegan del dedo o el mouse) sobre el título
	var title: Label = hud._start.get_child(0)
	check(title.text == "RECOIL RUN" and title.mouse_filter == Control.MOUSE_FILTER_STOP, "el título recibe los toques")
	await process_frame
	# (push_input va en coordenadas de la ventana: en headless es chiquita y estirada)
	var at := root.get_final_transform() * title.get_global_rect().get_center()
	for i in 7: # por el viewport, como un click o un toque (emulate_mouse_from_touch)
		for pressed in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = pressed
			ev.position = at
			ev.global_position = at
			root.push_input(ev)
	check(Tuning.dev_unlocked, "7 toques seguidos al título: desbloqueados")
	check(hud._tune_open.visible, "desbloqueado: aparece el botón AJUSTES")
	check(m._queued_shots == 0 and m.state == m.State.READY, "los toques al título no disparan")
	hud._tune_open.pressed.emit()
	check(hud._tune_panel.visible, "desbloqueado: el panel abre")
	Tuning.set_value("gravity", 20.0)
	check(is_equal_approx(Tuning.values.gravity, 20.0), "desbloqueado: la física se puede tocar")
	await despawn(m)
	# persistencia: se relee del archivo (como al abrir el juego de nuevo)
	Tuning.load_saved(true)
	check(Tuning.dev_unlocked, "el desbloqueo quedó guardado")
	check(is_equal_approx(Tuning.values.gravity, 20.0), "desbloqueado: la física tocada se conserva")
	m = await spawn()
	hud = m.hud
	check(hud._tune_open.visible, "al volver a abrir sigue el botón AJUSTES")
	# el mismo gesto los vuelve a esconder y la física vuelve a la de siempre
	for i in 7:
		hud.title_tap(300000 + i * 300)
	check(not Tuning.dev_unlocked, "el mismo gesto vuelve a bloquear")
	check(not hud._tune_open.visible and not hud._tune_panel.visible, "re-bloqueado: sin botón ni panel")
	check(Tuning.is_default(), "re-bloqueado: física por defecto")
	var g: float = PhysicsServer3D.area_get_param(m.get_world_3d().space, PhysicsServer3D.AREA_PARAM_GRAVITY)
	check(is_equal_approx(g, Tuning.DEFAULTS.gravity), "re-bloqueado: la gravedad del mundo vuelve (%.1f)" % g)
	await despawn(m)
	Tuning.load_saved(true)
	check(not Tuning.dev_unlocked and Tuning.is_default(), "el re-bloqueo quedó guardado")
	# física tocada guardada de antes + bloqueado: se usan los valores por defecto
	var cf := ConfigFile.new()
	cf.set_value("tuning", "gravity", 25.0)
	cf.set_value("tuning", "recoil_speed", 18.0)
	cf.set_value("meta", "version", Tuning.VERSION)
	cf.save(Tuning.save_path)
	Tuning.load_saved(true)
	check(not Tuning.dev_unlocked and Tuning.is_default(), "física hackeada guardada + bloqueado: valores por defecto")
	cf = ConfigFile.new()
	cf.load(Tuning.save_path)
	check(is_equal_approx(float(cf.get_value("tuning", "gravity", 0.0)), Tuning.DEFAULTS.gravity), "y el guardado queda limpio")
	Tuning.reset(false)


## AJUSTES: los sliders van escondidos; PROBAR COFRE / TRAMPA pone uno apenas arrancás.
func test_settings_panel() -> void:
	print("ajustes")
	var m := await spawn()
	check(not m.hud._tune_physics.visible, "los sliders arrancan escondidos")
	var labels: Array = m.hud._tune_panel.find_children("*", "Button", true, false).map(func(b): return b.text)
	check("COFRE" in labels and "TRAMPA" in labels, "botones para probar el cofre y la trampa")
	await despawn(m)
	for kind in ["chest", "trap"]:
		Level.debug_special = kind
		m = await spawn()
		var first := ""
		var fx := 0.0
		for b in m.blocks:
			for it in b.items:
				if first == "" and it.x > Level.START_X + Level.START_LEN: # (después del arranque)
					first = it.type
					fx = it.x
		check(first == kind, "PROBAR %s: es lo primero que aparece (%s en x=%.0f)" % [kind, first, fx])
		await despawn(m)
	Level.debug_special = ""


func test_market() -> void:
	print("mercado (bañadera con billetes)")
	Records.reset()
	var m := await spawn()
	clear_world(m)
	await physics_frame
	var tub: Tub = put(m, "market", 6.0, 0.0)
	await physics_frame
	await place_gun(m, Vector2(6.0, 1.0), 0.0) # adentro
	var t0 := Time.get_ticks_msec()
	var early := -1
	while m.state == m.State.PLAYING and Time.get_ticks_msec() - t0 < 3000:
		if early < 0 and Time.get_ticks_msec() - t0 > 600:
			early = 1 if m.state == m.State.MARKET else 0
		await physics_frame
	check(early == 0, "no entra de una: hay que quedarse")
	check(m.state == m.State.MARKET and tub.used, "quedándose >1 s adentro, entrás al mercado")
	check(m.hud._market.visible, "se ve el mercado")
	check(m.market_offers.size() == Config.MARKET_OFFERS, "ofrece %d mejoras al azar %s" % [Config.MARKET_OFFERS, str(m.market_offers)])
	await process_frame
	var cards: int = m.hud._market_box.find_children("*", "MarketIcon", true, false).size()
	check(cards == Config.MARKET_OFFERS, "se ven %d tarjetas con dibujo (%d)" % [Config.MARKET_OFFERS, cards])
	var other: String = m.market_offers[1]
	var btn: Button = m.hud._market_box.find_children("*", "Button", true, false)[1]
	btn.pressed.emit()
	await process_frame
	check(m.hud._market_sel == other, "tocar una tarjeta la elige (%s)" % m.hud._market_sel)
	var seen_offers := {}
	for i in 30:
		m._roll_offers()
		for o in m.market_offers:
			seen_offers[o] = true
	check(seen_offers.size() == m.MARKET_ITEMS.size(), "con varias visitas aparecen todas %s" % str(seen_offers.keys()))
	m.ammo = 50
	check(not m.can_buy("pierce"), "con 50 balas no alcanza para penetrantes (siempre te queda 1)")
	m.ammo = 51
	m._market_buy("pierce")
	check(m.ammo == 1 and m.pierce and Records.stat("pierce_runs") == Config.PERK_RUNS, "penetrantes: -50, por %d partidas" % Config.PERK_RUNS)
	check(m.price("extra_start") == roundi(Config.EXTRA_START_COST * (1.0 + Config.MARKET_PRICE_STEP)), "después de comprar, todo sale más caro (%d)" % m.price("extra_start"))
	m._market_buy("extra_start")
	check(m.ammo == 1, "no se puede gastar la última")
	var p2: int = m.price("extra_start")
	m.ammo = p2 + 1
	m._market_buy("extra_start")
	check(m.ammo == 1 and Records.stat("extra_start") == 1, "+1 bala al inicio: -%d" % p2)
	m.hud.market_close.emit()
	check(m.state == m.State.READY and not m.hud._market.visible, "al salir flotás esperando el primer tiro")
	await wait_s(0.3)
	var y: float = m.gun.global_position.y
	check(y > tub.global_position.y + 2.0 and m.gun.freeze, "flotando arriba de la bañadera")
	m._hurt_cd = 0.0
	m.hurt(1, Vector3.ZERO)
	check(m.ammo == 1, "inmune mientras flotás")
	m._queued_shots = 1
	await physics_frame
	await physics_frame
	check(m.state == m.State.PLAYING and not m.gun.freeze, "el primer tiro te suelta")
	m._game_over("TEST")
	check(Records.stat("pierce_runs") == Config.PERK_RUNS - 1, "la partida cuenta para las penetrantes")
	await despawn(m)
	m = await spawn()
	check(m.ammo == Config.START_AMMO + 1, "la próxima partida arrancás con %d" % m.ammo)
	check(m.pierce, "y con balas penetrantes")
	check(m.bought_this_run == 0 and m.price("pierce") == Config.PIERCE_COST, "en otra partida los precios vuelven a la base")
	await despawn(m)
	Records.set_stat("extra_start", 99)
	m = await spawn()
	m.ammo = 500
	check(not m.can_buy("extra_start"), "balas al inicio: hasta %d" % (Config.START_AMMO + Config.MAX_EXTRA_START))
	await despawn(m)
	Records.reset()


func test_market_in_level() -> void:
	print("mercado en el piso")
	var xs := []
	for sd in [7, 8, 9]:
		var lv := Level.new(sd)
		var bs := [lv.next_block()]
		while bs[-1].x1 < 3000.0:
			bs.append(lv.next_block())
		for b in bs:
			for it in b.items:
				if it.type == "market":
					xs.append(it.x)
					check(b.items.size() == 1, "la bañadera va sola en su bloque")
	check(xs.size() >= 3, "aparecen bañaderas (%d en 3 x 3km)" % xs.size())
	check(xs.all(func(x): return x > Config.MARKET_FROM), "solo pasados los %dm" % Config.MARKET_FROM)


func test_perks() -> void:
	print("mejoras del mercado")
	Records.reset()
	# rebote: la bala tirada al piso rebota y mata
	for ric in [false, true]:
		var m := await spawn()
		clear_world(m)
		await physics_frame
		if ric:
			m.perks["ricochet"] = true
		var e: Enemy = put(m, "plain", 6.0)
		await physics_frame
		# tiro hacia el piso a mitad de camino: rebota hacia el enemigo
		await fire_at(m, Vector2(0.0, 1.6), Vector3(3.0, 0.0, 0.0))
		if ric:
			check(not e.alive, "balas que rebotan: rebota en el piso y mata")
		else:
			check(e.alive, "sin la mejora, la bala se queda en el piso")
		await despawn(m)
	# mirilla: línea corta siempre
	var m := await spawn()
	check(not m._laser.visible, "sin mirilla no hay línea")
	m.perks["sight"] = true
	await process_frame
	await process_frame
	check(m._laser.visible and m._laser.global_transform.basis.x.length() <= Config.SIGHT_RANGE + 0.01, "mirilla: línea corta (%.1f m)" % m._laser.global_transform.basis.x.length())
	# cámara lenta larga
	m.perks["slowmo"] = true
	await place_gun(m, Vector2(0.0, 1.0), 0.0)
	m._on_hit({"result": "headshot", "reward": 0}, Vector3.ZERO)
	check(is_equal_approx(m._slowmo_left, Config.SLOWMO_DURATION * Config.LONG_SLOWMO), "cámara lenta larga: headshot x%.0f" % Config.LONG_SLOWMO)
	await despawn(m)
	# seguro de vida
	m = await spawn()
	Records.set_stat("insurance", 1)
	m._refresh_perks()
	await place_gun(m, Vector2(0.0, 1.0), 0.0)
	m.ammo = 0
	m._hurt_cd = 0.0
	m.hurt(1, Vector3.ZERO)
	check(m.state == m.State.READY and m.ammo == Config.INSURANCE_AMMO, "seguro de vida: en vez de perder, flotás con %d balas" % m.ammo)
	check(Records.stat("insurance") == 0, "se usa una vez")
	m._queued_shots = 1
	await physics_frame
	await physics_frame
	check(m.state == m.State.PLAYING, "y el primer tiro te suelta")
	m._game_over("TEST")
	check(m.state == m.State.OVER, "la segunda vez perdés")
	await despawn(m)
	# te caíste en un hueco: revivís del otro lado, arriba del piso
	Records.set_stat("insurance", 1)
	m = await spawn()
	await place_gun(m, Vector2(0.0, 1.0), 0.0)
	m.gun.global_position = Vector3(5.0, -30.0, 0.0)
	await process_frame
	await physics_frame
	var fy: float = m._float_pos.y
	check(m.state == m.State.READY and fy > Level.top_at(m.blocks, m._float_pos.x), "caído en un hueco: revivís arriba del piso (y=%.1f)" % fy)
	await despawn(m)
	# las mejoras con duración cuentan las partidas
	Records.reset()
	Records.set_stat("ricochet_runs", 2)
	m = await spawn()
	check(m.perks.has("ricochet") and not m.perks.has("pierce"), "arrancás con las mejoras que te quedan %s" % str(m.perks.keys()))
	m._game_over("TEST")
	check(Records.stat("ricochet_runs") == 1, "y la partida cuenta")
	await despawn(m)
	Records.reset()


func test_pierce_slowmo() -> void:
	print("penetrante x3: cámara lenta")
	var m := await spawn()
	clear_world(m)
	await physics_frame
	m.pierce = true
	for i in 3:
		put(m, "plain", 3.0 + i * 1.2)
	await physics_frame
	var slow := false
	m.state = m.State.PLAYING
	m.hud.hide_start()
	m.gun.global_transform = Transform3D(Basis(Vector3.BACK, atan2(0.9 - (0.9 + Gun.MUZZLE.y), 8.0)), Vector3(0.0, 0.9, 0))
	m._queued_shots = 1
	await physics_frame
	await physics_frame
	var t0 := Time.get_ticks_msec()
	while not m.bullets.is_empty() and Time.get_ticks_msec() - t0 < 4000:
		slow = slow or Engine.time_scale < 0.5
		await physics_frame
	check(slow and m.kills == 3, "matar 3 de un tiro activa la cámara lenta (kills %d)" % m.kills)
	await despawn(m)


func test_arrows() -> void:
	print("flechas en el borde")
	var m := await spawn()
	clear_world(m)
	await place_gun(m, Vector2(0.0, 2.0), 0.0)
	m.gun.freeze = true
	var r: Node3D = put(m, "rocket", 18.0, 3.0, false)
	await process_frame
	await process_frame
	check(not m.camera.is_position_in_frustum(r.global_position) and m.hud.visible_arrows() == 1, "un cohete afuera de la pantalla: flecha (%d)" % m.hud.visible_arrows())
	r.global_position = Vector3(3.0, 2.5, 0.0)
	await process_frame
	await process_frame
	check(m.hud.visible_arrows() == 0, "cuando entra en pantalla, la flecha se va")
	r.global_position = Vector3(80.0, 2.5, 0.0)
	await process_frame
	check(m.hud.visible_arrows() == 0, "muy lejos, sin flecha")
	await despawn(m)


func test_market_air() -> void:
	print("mercado en el aire (bañadera con globos)")
	var m := await spawn()
	await place_gun(m, Vector2(400.0, 60.0), 0.0)
	m.gun.freeze = true
	await process_frame
	await process_frame
	clear_world(m) # (sin bañaderas del piso cerca)
	var tubs := 0
	for i in 400:
		m._sky_progress = 999.0
		m._sky_last = m.gun.global_position
		var n0: int = m.entities.size()
		m._sky_spawner(m.gun.global_position)
		for e in m.entities.slice(n0):
			if e is Tub:
				tubs += 1
				check(e.floating, "la del aire cuelga de globos")
				check(e.global_position.y > Level.top_at(m.blocks, e.global_position.x) + 20.0, "aparece en el aire, cerca de tu altura (y=%.0f)" % e.global_position.y)
	check(tubs == 1, "aparece y no se repite cerca (%d)" % tubs)
	await despawn(m)
	m = await spawn()
	clear_world(m)
	m.state = m.State.PLAYING
	var tub: Tub = put(m, "market_air", 6.0, 30.0)
	await physics_frame
	await place_gun(m, Vector2(6.0, 32.5), 0.0) # cae adentro
	var t0 := Time.get_ticks_msec()
	while m.state == m.State.PLAYING and Time.get_ticks_msec() - t0 < 4000:
		await physics_frame
	check(m.state == m.State.MARKET, "cayendo adentro de la bañadera voladora entrás al mercado")
	await despawn(m)
	m = await spawn()
	clear_world(m)
	await place_gun(m, Vector2(100.0, 60.0), 0.0)
	m.gun.freeze = true
	check(not m._air_market_ok(Vector3(110.0, 60.0, 0.0), 50.0), "antes de los %dm no aparece" % Config.MARKET_FROM)
	check(not m._air_market_ok(Vector3(410.0, 3.0, 0.0), 2.0), "cerca del piso no (ahí están las del piso)")
	await despawn(m)


func test_special_levels() -> void:
	print("niveles especiales")
	for sp in Level.SPECIALS:
		var lv := Level.new(5, sp)
		var bs := [lv.next_block()]
		while bs[-1].x1 < 400.0:
			bs.append(lv.next_block())
		var sb := bs.filter(func(b): return b.special == sp)
		check(sb.size() > 0, "%s arranca apenas termina el arranque" % sp)
		if sb.is_empty():
			continue
		var length: float = sb[-1].x1 - sb[0].x0
		check(absf(length - Level.SPECIAL_LEN[sp]) < 12.0, "%s: %.0fm de largo" % [sp, length])
		var gaps := 0
		for i in range(1, sb.size()):
			if sb[i].x0 - sb[i - 1].x1 > 0.5:
				gaps += 1
		var items := []
		for b in sb:
			items += b.items
		var kinds := {}
		for it in items:
			kinds[it.type] = kinds.get(it.type, 0) + 1
		match sp:
			"chase":
				check(gaps == 0, "persecución: sin huecos")
				check(items.size() - kinds.get("ammo", 0) >= 4, "persecución: algunos personajes (%s)" % str(kinds))
				var ammo_xs: Array = items.filter(func(it): return it.type == "ammo").map(func(it): return it.x)
				ammo_xs.sort()
				var worst := 0.0
				for i in range(1, ammo_xs.size()):
					worst = maxf(worst, ammo_xs[i] - ammo_xs[i - 1])
				check(ammo_xs.size() >= 20 and worst <= Config.CHASE_AMMO_EVERY.y + Level.ITEM_EDGE * 2.0 + 0.5, "persecución: balas en el camino (%d, la mayor distancia entre balas %.1f m)" % [ammo_xs.size(), worst])
			"gallery":
				check(gaps == 0, "galería: sin huecos")
				check(kinds.get("target", 0) >= 10 and kinds.size() == 1, "galería: solo dianas (%s)" % str(kinds))
			"blackout":
				check(items.size() >= 10 and not kinds.has("helmet"), "apagón: muchos personajes, ninguno con casco (%s)" % str(kinds))
			"boss":
				check(kinds.get("boss", 0) == 1 and items.size() == 1, "jefe: un robot y nada más (%s)" % str(kinds))
	# cuándo aparecen: el primero a los 250 m, después cada 500 m, sin repetir
	var lv0 := Level.new(11)
	var all := [lv0.next_block()]
	while all[-1].x1 < 2500.0:
		all.append(lv0.next_block())
	var zones := []
	for i in range(1, all.size()):
		if all[i].special != "" and all[i - 1].special != all[i].special:
			zones.append({"kind": all[i].special, "x0": all[i].x0})
		if all[i].special == "" and all[i - 1].special != "":
			zones[-1].x1 = all[i - 1].x1
	check(zones.size() >= 4, "hay niveles especiales (%s)" % str(zones.map(func(z): return "%s@%d" % [z.kind, roundi(z.x0)])))
	if zones.size() >= 4:
		check(absf(zones[0].x0 - Level.SPECIAL_FIRST) < 15.0, "el primero a los %dm (%d)" % [Level.SPECIAL_FIRST, zones[0].x0])
		check(absf(zones[1].x0 - zones[0].x1 - Level.SPECIAL_EVERY) < 15.0, "después, %dm después del anterior (%d)" % [Level.SPECIAL_EVERY, zones[1].x0 - zones[0].x1])
		var k4 := {}
		for z in zones.slice(0, 4):
			k4[z.kind] = true
		check(k4.size() == 4, "los cuatro antes de repetir (%s)" % str(k4.keys()))
	# probar nivel desde AJUSTES
	Level.debug_special = "gallery"
	var m := await spawn()
	check(m.blocks.size() >= 2 and m.blocks[1].special == "gallery", "PROBAR NIVEL arranca con ese nivel")
	check(Level.debug_special == "", "y vale para una sola partida")
	await despawn(m)


## Arranca una partida con ese nivel especial y pone el arma recién entrada.
func enter_special(kind: String) -> Node:
	Level.debug_special = kind
	var m := await spawn()
	if kind == "chase": # sin personajes en el camino
		clear_world(m)
	var z: Dictionary = m.special_zones[0]
	for i in 30:
		if z.x1 != INF:
			break
		m._stream_world(m.blocks[-1].x1)
	await place_gun(m, Vector2(z.x0 + 1.0, Level.top_at(m.blocks, z.x0 + 1.0) + 1.2), 0.0)
	m.fan_ride = 999.0 # sin bichos del cielo que molesten la cuenta
	await process_frame
	await process_frame
	return m


## Llegás a un nivel especial volando muy alto: una nave te lleva al piso.
func test_abduction() -> void:
	print("especial: abducción si llegás desde muy alto")
	Level.debug_special = "gallery"
	var m := await spawn()
	clear_world(m)
	var z: Dictionary = m.special_zones[0]
	var ground: float = Level.top_at(m.blocks, z.x0 + 1.0)
	var x: float = z.x0 - 15.0
	await place_gun(m, Vector2(x, ground + 40.0), 0.0)
	var t0 := Time.get_ticks_msec()
	while not m.abducting and Time.get_ticks_msec() - t0 < 4000:
		x += 0.2
		m.gun.global_position = Vector3(x, ground + 40.0, 0)
		m.gun.linear_velocity = Vector3.ZERO
		await physics_frame
	check(m.abducting and m.special_zone.is_empty(), "antes de empezar, te abduce (x=%.1f, empieza en %.1f)" % [x, z.x0])
	var ammo0: int = m.ammo
	m.shoot()
	m._hurt_cd = 0.0
	m.hurt(3, m.gun.global_position)
	check(m.ammo == ammo0, "mientras te lleva no disparás ni te lastiman")
	t0 = Time.get_ticks_msec()
	while m.abducting and Time.get_ticks_msec() - t0 < 8000:
		await physics_frame
	var gp: Vector3 = m.gun.global_position
	check(not m.abducting and absf(gp.x - (z.x0 + 1.0)) < 0.5 and gp.y - ground < 2.5, "te deja en el piso, al principio del nivel (%.1f, %.1f sobre el piso)" % [gp.x, gp.y - ground])
	for i in 4:
		await physics_frame
	check(m.special_zone.get("kind", "") == "gallery", "y arranca el nivel especial")
	check(m.state == m.State.PLAYING and not m.gun.freeze and m.gun.visible, "seguís jugando")
	await despawn(m)
	Level.debug_special = ""


## Entrás antes de que se genere el final (el mundo se genera de a poco): igual termina.
func test_special_ends_while_inside() -> void:
	print("especial: termina aunque entres antes de que se genere el final")
	for kind in ["blackout", "gallery"]:
		Level.debug_special = kind
		var m := await spawn()
		clear_world(m)
		var z: Dictionary = m.special_zones[0]
		check(z.x1 == INF, "%s: al entrar todavía no tiene final" % kind)
		await place_gun(m, Vector2(z.x0 - 2.0, Level.top_at(m.blocks, z.x0 - 2.0) + 2.0), 0.0)
		m.gun.freeze = true
		m.fan_ride = 999.0
		m.powers.untouchable = 99.0
		var x: float = z.x0 + 1.0
		var t0 := Time.get_ticks_msec()
		while m.special_zone.get("kind", "") == kind or m.special_zone.is_empty() and x < z.x0 + 30.0:
			x += 1.5
			m.gun.global_position = Vector3(x, Level.top_at(m.blocks, x) + 2.0, 0)
			await physics_frame
			if m.special_zone.get("kind", "") == kind:
				z["started"] = true
			if Time.get_ticks_msec() - t0 > 20000 or x > z.x0 + 400.0:
				break
		check(z.get("started", false), "%s: arrancó" % kind)
		check(m.special_zone.is_empty() and z.x1 != INF and x < z.x1 + 10.0, "%s: termina al pasar su final (x=%.0f, fin=%.0f)" % [kind, x, z.x1])
		await despawn(m)
	Level.debug_special = ""


func test_special_chase() -> void:
	print("especial: persecución")
	var m := await enter_special("chase")
	check(m.special_zone.get("kind", "") == "chase" and m._chaser != null, "al entrar arranca (y aparece la boca gigante)")
	check(m.hud._special_info.visible, "contador en pantalla: %s" % m.hud._special_info.text)
	Records.set_stat("insurance", 1)
	var hold: Vector3 = m.gun.global_position
	var t0 := Time.get_ticks_msec()
	while m.state == m.State.PLAYING and Time.get_ticks_msec() - t0 < 8000:
		if not m.eaten:
			m.gun.global_position = hold
			m.gun.linear_velocity = Vector3.ZERO
		await physics_frame
	check(m.eaten and m.state == m.State.OVER and m.hud._over_title.text == "¡TE COMIÓ!", "si te quedás, te alcanza y te come (sin seguro que valga)")
	Records.set_stat("insurance", 0)
	await despawn(m)
	# escapar: avanzar más rápido que la boca hasta el final
	m = await enter_special("chase")
	var z: Dictionary = m.special_zone
	var x: float = m.gun.global_position.x
	var before: int = m.ammo
	m.gun.freeze = true
	while x < z.x1 + 1.0 and m.state == m.State.PLAYING:
		m._hurt_cd = 99.0 # (los personajes del camino no cuentan acá)
		x += 9.0 / 120.0
		m.gun.global_position = Vector3(x, Level.top_at(m.blocks, x) + 2.0, 0.0)
		await physics_frame
	await process_frame
	check(not m.eaten and m.special_zone.is_empty(), "si llegás al final, escapaste")
	check(m.ammo >= before + Config.CHASE_REWARD + 10, "+%d balas al final, más las que juntaste en el camino (%d -> %d)" % [Config.CHASE_REWARD, before, m.ammo])
	await despawn(m)


func test_special_gallery() -> void:
	print("especial: galería de tiro")
	var m := await enter_special("gallery")
	var z: Dictionary = m.special_zone
	check(z.get("kind", "") == "gallery" and z.total >= 10, "%d dianas" % z.total)
	var targets: Array = m.entities.filter(func(n): return n is Target)
	targets.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	var tg: Target = targets[0]
	check(tg.state == "hidden" or tg.global_position.x - m.gun.global_position.x < Config.TARGET_TRIGGER, "escondidas hasta que te acercás")
	# al centro: 2 puntos y te devuelve la bala
	var c: Vector3 = tg.global_position
	var gp := Vector2(c.x - 5.0, c.y - 0.2)
	m.gun.global_position = Vector3(gp.x, gp.y, 0)
	await physics_frame
	await physics_frame
	check(tg.state == "up", "asoma cuando estás cerca")
	var before: int = m.ammo
	await fire_at(m, gp, c)
	check(tg.points == 2 and z.points == 2, "al centro: 2 puntos (%d)" % tg.points)
	check(m.ammo == before, "cada acierto te devuelve la bala (%d -> %d)" % [before, m.ammo])
	# al borde: 1 punto
	var tg2: Target = targets[1]
	c = tg2.global_position
	gp = Vector2(c.x - 5.0, c.y + 0.3)
	m.gun.global_position = Vector3(gp.x, gp.y, 0)
	await physics_frame
	await physics_frame
	if tg2.mode == "fly":
		tg2.set_physics_process(false)
		c = tg2.global_position
	await fire_at(m, gp, c + Vector3(0, 0.55, 0))
	check(tg2.points == 1 and z.points == 3, "al borde: 1 punto (%d)" % tg2.points)
	# si no le pegás, se esconde sola
	var tg3: Target = targets[2]
	m.gun.global_position = tg3.global_position - Vector3(5.0, 0.0, 0.0)
	await wait_s(Config.TARGET_UP_TIME + 0.6)
	check(tg3.state == "done" and tg3.points == 0, "si no le pegás, se va")
	# terminar: con 3 de %d no hay medalla
	m._hurt_cd = 99.0
	before = m.ammo
	m.gun.freeze = true
	m.gun.global_position = Vector3(z.x1 + 1.0, Level.top_at(m.blocks, z.x1 + 1.0) + 2.0, 0)
	for i in 4:
		await process_frame
	check(m.special_zone.is_empty() and m.ammo == before, "pocos puntos: sin medalla")
	# con muchos puntos: oro
	await despawn(m)
	m = await enter_special("gallery")
	z = m.special_zone
	z.points = z.total * 2
	before = m.ammo
	m.gun.freeze = true
	m.gun.global_position = Vector3(z.x1 + 1.0, Level.top_at(m.blocks, z.x1 + 1.0) + 2.0, 0)
	for i in 4:
		await process_frame
	check(m.ammo == before + Config.GALLERY_MEDALS[0][2], "todo al centro: ¡ORO! +%d" % Config.GALLERY_MEDALS[0][2])
	await despawn(m)


func test_special_blackout() -> void:
	print("especial: apagón")
	var m := await enter_special("blackout")
	check(m.special_zone.get("kind", "") == "blackout", "entraste al apagón")
	await wait_s(2.0)
	check(m._sun.light_energy < 0.2 and m._env.ambient_light_energy < 0.08, "se apaga la luz (sol %.2f)" % m._sun.light_energy)
	check(m._gun_lamp.light_energy > 1.0 and m._gun_torch.light_energy > 1.5, "el arma se ve: luz tenue y linterna")
	var es: Array = m.enemies.filter(func(e): return is_instance_valid(e) and e.alive and e.global_position.x > m.gun.global_position.x + 3.0)
	var e: Enemy = es[0]
	e.set_meta("seen", true)
	var ep: Vector3 = e.global_position
	var gp := Vector2(ep.x - 4.0, ep.y + 1.0)
	await fire_at(m, gp, ep + Vector3(0, 0.8, 0))
	check(not e.alive, "al cuerpo también mata (no solo headshots)")
	var ffs: Array = m.entities.filter(func(n): return is_instance_valid(n) and n is Firefly)
	check(ffs.size() >= 3, "hay lucecitas (%d)" % ffs.size())
	var f: Firefly = ffs[0]
	f.set_process(false) # quieta para apuntarle
	f.set_meta("seen", true)
	m.kill_streak = 0
	var ammo0: int = m.ammo
	var fp: Vector3 = f.global_position
	await fire_at(m, Vector2(fp.x - 4.0, fp.y), fp)
	check(not f.alive and m.special_zone.lights == 1, "le pegaste a una lucecita")
	check(m.ammo == ammo0 - 1 + Config.FIREFLY_REWARD, "te da %d balas (%d)" % [Config.FIREFLY_REWARD, m.ammo])
	var before: int = m.ammo
	m.gun.freeze = true
	var z: Dictionary = m.special_zone
	m.gun.global_position = Vector3(z.x1 + 1.0, Level.top_at(m.blocks, z.x1 + 1.0) + 2.0, 0)
	for i in 4:
		await process_frame
	check(m.ammo == before + Config.BLACKOUT_REWARD, "sin que te toquen: +%d" % Config.BLACKOUT_REWARD)
	await wait_s(2.0)
	check(m._sun.light_energy > 0.9, "al salir vuelve la luz")
	await despawn(m)
	m = await enter_special("blackout")
	m._hurt_cd = 0.0
	m.hurt(1, Vector3.ZERO)
	before = m.ammo
	z = m.special_zone
	m.gun.freeze = true
	m.gun.global_position = Vector3(z.x1 + 1.0, Level.top_at(m.blocks, z.x1 + 1.0) + 2.0, 0)
	for i in 4:
		await process_frame
	check(m.ammo == before, "si te tocaron: sin premio")
	await despawn(m)


func test_special_boss() -> void:
	print("especial: jefe")
	var m := await enter_special("boss:robot")
	var bosses: Array = m.entities.filter(func(n): return n is Boss)
	check(bosses.size() == 1, "hay un robot")
	var boss: Boss = bosses[0]
	boss.set_meta("seen", true)
	var bp: Vector3 = boss.global_position
	# no se pasa: ni caminando ni por arriba
	var hit: Dictionary = m._raycast(Vector3(bp.x + 1.0, bp.y + 30.0, 0), Vector3(bp.x + 5.0, bp.y + 30.0, 0))
	check(not hit.is_empty(), "campo de fuerza hasta el cielo")
	m.gun.global_position = Vector3(bp.x - 12.0, bp.y + 2.0, 0)
	await wait_s(Config.BOSS_FIRE_EVERY + 0.3)
	check(m.entities.any(func(n): return is_instance_valid(n) and n is Rocket), "te tira cohetes")
	m.powers.untouchable = 99.0
	m.ammo = 30
	boss.set_physics_process(false) # (que no tire más cohetes)
	for n in m.entities: # (sin cohetes en el medio que sumen balas)
		if is_instance_valid(n) and n is Rocket:
			n.queue_free()
	await physics_frame
	var gp := Vector2(bp.x - 9.0, bp.y + 6.3)
	await fire_at(m, gp, bp + Vector3(0, 3.0, 0))
	check(boss.broken.is_empty() and boss.alive, "blindaje: rebota")
	var before: int = m.ammo
	for k in ["antenna", "core", "eye"]: # cualquiera, en cualquier orden
		var sp := boss.spot_position(k)
		await fire_at(m, Vector2(bp.x - 9.0, sp.y - 0.4), sp)
		m.kill_streak = 0 # (que una racha no dé un poder de +15 en el medio)
		check(boss.broken.has(k), "%s roto" % k)
	check(not boss.alive and m.special_zone.broken == 3, "los 3 rotos: lo mataste")
	check(m.ammo == before - 3 + Config.BOSS_REWARD, "+%d balas (%d)" % [Config.BOSS_REWARD, m.ammo])
	check(m.trophy_laser and m.hud._perks.text.contains("LÁSER"), "y mirilla láser hasta el final de la partida")
	await physics_frame
	await physics_frame
	hit = m._raycast(Vector3(bp.x + 1.0, bp.y + 30.0, 0), Vector3(bp.x + 5.0, bp.y + 30.0, 0))
	check(hit.is_empty(), "y se abre el paso")
	await despawn(m)


## Busca el jefe del nivel y lo deja listo para los tiros.
func find_boss(m: Node, cls) -> Node:
	var bs: Array = m.entities.filter(func(n): return is_instance_valid(n) and is_instance_of(n, cls))
	if bs.is_empty():
		return null
	var b: Node = bs[0]
	b.set_meta("seen", true)
	return b


func test_boss_rotation() -> void:
	print("jefes: rotan sin repetirse")
	var lv := Level.new(7)
	var seen := []
	var bs: Array = []
	while seen.size() < Level.BOSSES.size() and (bs.is_empty() or bs[-1].x1 < 20000.0):
		var b: Dictionary = lv.next_block()
		bs.append(b)
		if b.has("boss"):
			seen.append(b.boss)
	var uniq := {}
	for k in seen:
		uniq[k] = true
	check(uniq.size() == Level.BOSSES.size() and seen.size() == Level.BOSSES.size(), "salen los %d jefes antes de repetir uno (%s)" % [Level.BOSSES.size(), seen])


func test_boss_mole() -> void:
	print("jefe: topo gigante")
	var m := await enter_special("boss:mole")
	var mole: Mole = find_boss(m, Mole)
	check(mole != null and m.hud._special_info.visible, "hay un topo (%s)" % m.hud._special_info.text)
	m.ammo = 30
	m.powers.untouchable = 99.0
	var t0 := Time.get_ticks_msec()
	var threw := false
	while Time.get_ticks_msec() - t0 < 6000 and not threw:
		m.gun.global_position = Vector3(mole.global_position.x - 13.0, mole.global_position.y + 1.5, 0)
		m.gun.linear_velocity = Vector3.ZERO
		await physics_frame
		threw = m.entities.any(func(n): return is_instance_valid(n) and n is BossShot and n.kind == "rock")
	check(threw, "sale de un pozo y te tira una piedra")
	mole.set_physics_process(false) # yo decido cuándo sale
	for n in m.entities:
		if is_instance_valid(n) and n is BossShot:
			n.queue_free()
	await wait_s(0.5)
	var before: int = m.ammo
	for i in mole.total:
		mole._rise()
		await wait_s(0.4)
		var np := mole.nose_position()
		if i == 0:
			var bp: Vector3 = mole._body.global_position + Vector3(0, 0.6, 0)
			await fire_at(m, Vector2(bp.x - 6.0, bp.y), bp)
			check(mole.hits == 0 and mole.alive, "al cuerpo: rebota")
			before = m.ammo
		await fire_at(m, Vector2(np.x - 6.0, np.y), np)
		m.kill_streak = 0
		check(mole.hits == i + 1, "a la nariz: golpe %d" % (i + 1))
		await wait_s(0.4)
	check(not mole.alive, "%d golpes: lo mataste" % mole.total)
	check(m.ammo == before - mole.total + Config.BOSS_REWARD, "+%d balas (%d)" % [Config.BOSS_REWARD, m.ammo])
	await despawn(m)


func test_boss_zeppelin() -> void:
	print("jefe: zepelín")
	var m := await enter_special("boss:zeppelin")
	var z: Zeppelin = find_boss(m, Zeppelin)
	check(z != null, "hay un zepelín")
	m.ammo = 30
	m.powers.untouchable = 99.0
	var t0 := Time.get_ticks_msec()
	var bombed := false
	while Time.get_ticks_msec() - t0 < 4000 and not bombed:
		m.gun.global_position = Vector3(z.global_position.x - 6.0, z.global_position.y + 1.5, 0)
		m.gun.linear_velocity = Vector3.ZERO
		await physics_frame
		bombed = m.entities.any(func(n): return is_instance_valid(n) and n is BossShot and n.kind == "bomb")
	check(bombed, "te tira bombas")
	z.set_physics_process(false)
	z._ship.position.x = 0.0
	for n in m.entities:
		if is_instance_valid(n) and n is BossShot:
			n.queue_free()
	await physics_frame
	var hp := z.ship_position() + Vector3(0, 0.3, 0)
	await fire_at(m, Vector2(hp.x - 1.0, hp.y - 6.0), hp + Vector3(-1.0, -1.0, 0)) # de abajo, al casco
	check(z.popped.is_empty() and z.alive, "al casco: rebota")
	var before: int = m.ammo
	var from := {"front": Vector2(-7.0, 0.0), "top": Vector2(-5.0, 2.5), "bottom": Vector2(-3.0, -3.0), "back": Vector2(6.0, 0.0)}
	for k in ["front", "top", "bottom", "back"]:
		var bp := z.bag_position(k)
		await fire_at(m, Vector2(bp.x + from[k].x, bp.y + from[k].y), bp)
		m.kill_streak = 0
		check(z.popped.has(k), "bolsa %s pinchada" % k)
	check(not z.alive, "las 4 pinchadas: se cae")
	check(m.ammo == before - 4 + Config.BOSS_REWARD, "+%d balas (%d)" % [Config.BOSS_REWARD, m.ammo])
	# una bomba que te explota cerca: -3
	m.powers.untouchable = 0.0
	m._hurt_cd = 0.0
	var g: float = Level.top_at(m.blocks, m.gun.global_position.x)
	await place_gun(m, Vector2(m.gun.global_position.x, g + 0.6), 0.0)
	before = m.ammo
	m.boss_shoot("bomb", m.gun.global_position + Vector3(0.8, 2.0, 0), Vector3.ZERO)
	await wait_s(1.0)
	check(m.ammo == before - BossShot.BOMB_DAMAGE, "bomba cerca: -%d balas (%d -> %d)" % [BossShot.BOMB_DAMAGE, before, m.ammo])
	await despawn(m)


func test_boss_wall() -> void:
	print("jefe: la muralla")
	var m := await enter_special("boss:wall")
	var w: BrickWall = find_boss(m, BrickWall)
	check(w != null and m.hud._special_info.text.contains("POZO"), "hay una muralla (%s)" % m.hud._special_info.text)
	m.powers.untouchable = 99.0
	m.ammo = 30
	var x0: float = w.global_position.x
	var g: float = Level.top_at(m.blocks, x0)
	await place_gun(m, Vector2(x0 - 8.0, g + 0.6), 0.0)
	await wait_s(1.0)
	check(w.global_position.x < x0 - 0.5, "avanza hacia vos (%.1f -> %.1f)" % [x0, w.global_position.x])
	w.set_physics_process(false)
	var wx: float = w.global_position.x
	await fire_at(m, Vector2(wx - 5.0, g + 7.0), Vector3(wx, g + 7.0, 0))
	check(w.broken == 0, "arriba es de acero: rebota")
	for row in [0, 1]:
		var bp := w.brick_position(row)
		await fire_at(m, Vector2(wx - 4.0, bp.y), bp)
		check(not w.has_brick(row), "ladrillo %d roto" % row)
	var before: int = m.ammo
	w.set_physics_process(true)
	m.gun.freeze = true
	m.gun.global_position = Vector3(wx + 1.5, g + 0.6, 0) # pasaste por el agujero
	for i in 4:
		await physics_frame
	check(not w.alive, "la pasaste: ganaste")
	check(m.ammo == before + Config.BOSS_REWARD and m.trophy_laser, "+%d balas y mirilla (%d)" % [Config.BOSS_REWARD, m.ammo])
	await despawn(m)
	# si no la pasás, te empuja al pozo
	m = await enter_special("boss:wall")
	w = find_boss(m, BrickWall)
	g = Level.top_at(m.blocks, w.stop_x + 1.0)
	w.global_position.x = w.stop_x + 2.2
	await place_gun(m, Vector2(w.stop_x + 0.9, g + 0.5), 0.0)
	var t0 := Time.get_ticks_msec()
	while m.state == m.State.PLAYING and Time.get_ticks_msec() - t0 < 6000:
		await physics_frame
	check(m.state == m.State.OVER, "te empuja al pozo y perdés (y=%.1f)" % m.gun.global_position.y)
	await despawn(m)


func test_boss_duel() -> void:
	print("jefe: duelo")
	var m := await enter_special("boss:duel")
	var d: Duel = find_boss(m, Duel)
	check(d != null, "hay un arma rival")
	m.powers.untouchable = 99.0
	m.ammo = 30
	var t0 := Time.get_ticks_msec()
	var fired := false
	while Time.get_ticks_msec() - t0 < 5000 and not fired:
		var rp := d.rival_position()
		m.gun.global_position = Vector3(rp.x - 8.0, rp.y + 1.0, 0)
		m.gun.linear_velocity = Vector3.ZERO
		await physics_frame
		fired = m.entities.any(func(n): return is_instance_valid(n) and n is BossShot and n.kind == "bullet")
	check(fired, "te apunta y te dispara")
	d.set_physics_process(false)
	for n in m.entities:
		if is_instance_valid(n) and n is BossShot:
			n.queue_free()
	d.rival.position = Vector3(2.0, 3.0, 0)
	await physics_frame
	var before: int = m.ammo
	for i in d.total:
		d._blink = 0.0
		var rp := d.rival_position()
		await fire_at(m, Vector2(rp.x - 6.0, rp.y), rp)
		m.kill_streak = 0
		check(d.hits == i + 1, "golpe %d" % (i + 1))
		if i == 0: # recién golpeada: invulnerable un ratito
			await fire_at(m, Vector2(rp.x - 6.0, rp.y), rp)
			check(d.hits == 1, "justo después del golpe: no cuenta")
			before -= 1
	check(not d.alive, "3 golpes: ganaste el duelo")
	check(m.ammo == before - d.total + Config.BOSS_REWARD, "+%d balas (%d)" % [Config.BOSS_REWARD, m.ammo])
	# su bala te saca 3
	m.powers.untouchable = 0.0
	m._hurt_cd = 0.0
	var gx: float = m.gun.global_position.x
	await place_gun(m, Vector2(gx, Level.top_at(m.blocks, gx) + 2.0), 0.0)
	m.gun.freeze = true
	await physics_frame
	before = m.ammo
	m.boss_shoot("bullet", m.gun.global_position + Vector3(3.0, 0, 0), Vector3(-Config.DUEL_BULLET_SPEED, 0, 0))
	await wait_s(0.5)
	check(m.ammo == before - BossShot.BULLET_DAMAGE, "su bala: -%d balas (%d)" % [BossShot.BULLET_DAMAGE, m.ammo])
	await despawn(m)


## Espacio: cometa dorado y poderes que solo salen ahí (dron, escopeta, imán).
func test_space_rewards() -> void:
	print("espacio: cometa y poderes del espacio")
	var m := await spawn()
	clear_world(m)
	await physics_frame
	var g: float = Level.top_at(m.blocks, 5.0)
	await place_gun(m, Vector2(5.0, g + Config.UFO_ALT + 20.0), 0.0)
	m.gun.freeze = true
	m.fan_ride = 999.0 # sin bichos del cielo
	check(m.in_space(), "arriba de %d m: estás en el espacio" % Config.UFO_ALT)
	await wait_s(1.5) # (que la cámara llegue hasta acá)
	# los cometas pasan solos
	m._comet_cd = 0.0
	for i in 4:
		await process_frame
	var comets: Array = m.entities.filter(func(n): return is_instance_valid(n) and n is Comet)
	check(comets.size() == 1, "en el espacio pasa un cometa")
	var c: Comet = comets[0]
	await process_frame
	check(not m.on_screen(c.global_position) and m.hud.visible_arrows() == 1, "antes de pasar, una flecha avisa por dónde viene (%d)" % m.hud.visible_arrows())
	var seen_go := false
	var seen_back := false
	var arrow_back := false
	var tc := Time.get_ticks_msec()
	while is_instance_valid(c) and Time.get_ticks_msec() - tc < 9000:
		await process_frame
		if not is_instance_valid(c):
			break
		var on: bool = m.on_screen(c.global_position)
		if c.phase == Comet.Phase.GO and on:
			seen_go = true
		if c.phase == Comet.Phase.TURN and not on and m.hud.visible_arrows() == 1:
			arrow_back = true
		if c.phase == Comet.Phase.BACK and on:
			seen_back = true
	check(seen_go, "cruza la pantalla (se ve)")
	check(arrow_back, "pasa de largo, espera afuera y la flecha avisa que vuelve")
	check(seen_back, "y vuelve: pasa una segunda vez, para el otro lado")
	check(not is_instance_valid(c) and m.hud.visible_arrows() == 0, "después de la vuelta se va (sin flecha)")
	c = m.spawn_comet()
	c.global_position = m.gun.global_position + Vector3(2.0, 1.0, 0.0)
	c.set_physics_process(false)
	c.set_meta("seen", true)
	m.gun.freeze = false
	m.ammo = 10
	m.powers.clear()
	var cp: Vector3 = c.global_position
	await fire_at(m, Vector2(cp.x - 5.0, cp.y), cp)
	check(not c.alive and m.ammo == 10 - 1 + Config.COMET_REWARD, "cometa: +%d balas (%d)" % [Config.COMET_REWARD, m.ammo])
	check(m.powers.keys().any(func(k): return k in m.SPACE_POWERS), "y un poder del espacio (%s)" % [m.powers.keys()])
	# los poderes del espacio solo salen arriba
	var got := {}
	for i in 60:
		m.grant_power(m.gun.global_position)
		got[m.last_power] = true
	check(m.SPACE_POWERS.all(func(k): return got.has(k)), "en el espacio salen dron, escopeta e imán (%s)" % [got.keys()])
	m.powers.clear()
	if is_instance_valid(m._drone):
		m._drone.queue_free()
	await despawn(m)

	m = await spawn()
	clear_world(m)
	await physics_frame
	got = {}
	for i in 60:
		m.grant_power(m.gun.global_position)
		got[m.last_power] = true
	check(not m.SPACE_POWERS.any(func(k): return got.has(k)), "en el piso no salen (%s)" % [got.keys()])
	m.powers.clear()
	m._comet_cd = 0.0
	await physics_frame
	check(not m.entities.any(func(n): return is_instance_valid(n) and n is Comet), "y no pasan cometas")
	# escopeta: 3 balas por tiro, gasta 1
	m.ammo = 10
	m._activate_power("shotgun", m.gun.global_position)
	await place_gun(m, Vector2(3.0, g + 3.0), 0.0)
	m._queued_shots = 1
	await physics_frame
	check(m.bullets.size() == 3 and m.ammo == 9, "escopeta: 3 balas por tiro (%d), gasta 1" % m.bullets.size())
	await bullets_done(m)
	m.powers.clear()
	# imán: lo que matás suelta balas que vienen a vos
	clear_world(m)
	await physics_frame
	m._activate_power("magnet", m.gun.global_position)
	var e: Enemy = put(m, "plain", 9.0, g)
	m.ammo = 10
	m.kill_streak = 0
	await fire_at(m, Vector2(4.0, g + 1.2), e.global_position + Vector3(0, 0.8, 0))
	check(not e.alive, "imán: lo mataste")
	await wait_s(1.5)
	check(m.ammo == 10 - 1 + Config.KILL_REWARD + Config.MAGNET_DROPS, "y suelta %d balas que vienen a vos (%d)" % [Config.MAGNET_DROPS, m.ammo])
	m.powers.clear()
	# dron: le tira solo al que esté cerca, sin gastar tus balas
	clear_world(m)
	await physics_frame
	await place_gun(m, Vector2(3.0, g + 1.0), 0.0)
	m.gun.freeze = true
	m._activate_power("drone", m.gun.global_position)
	var e2: Enemy = put(m, "plain", 7.0, g)
	m.ammo = 10
	var t0 := Time.get_ticks_msec()
	while e2.alive and Time.get_ticks_msec() - t0 < 4000:
		await physics_frame
	check(not e2.alive, "dron: lo mató solo")
	check(m.ammo >= 10, "sin gastar tus balas (%d)" % m.ammo)
	m.powers.drone = 0.01
	await wait_s(0.2)
	check(not is_instance_valid(m._drone), "cuando se termina, el dron se va")
	await despawn(m)
